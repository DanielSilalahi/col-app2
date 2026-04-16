import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/customer_service.dart';
import '../services/collection_service.dart';
import '../services/offline_queue_service.dart';
import '../services/notification_service.dart';
import '../core/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _customerService = CustomerService();
  final _collectionService = CollectionService();
  final _offlineQueue = OfflineQueueService();
  final _api = ApiClient();
  Timer? _notificationTimer;

  // Auth state
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Customer list
  List<CustomerModel> _customers = [];
  List<CustomerModel> get customers => _customers;

  // Pinned customers
  List<int> _pinnedIds = [];
  List<int> get pinnedIds => _pinnedIds;

  // Offline queue count
  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _totalFilteredCount = 0;
  int get totalFilteredCount => _totalFilteredCount;
  int get totalPages => (_totalFilteredCount / _pageSize).ceil();
  int get currentPageIndex => _currentPage;

  // Global Stats
  int _totalCount = 0;
  int _bayarCount = 0;
  int _janjiCount = 0;
  int _belumCount = 0;
  int _tidakKetemuCount = 0;

  int get totalCount => _totalCount;
  int get bayarCount => _bayarCount;
  int get janjiCount => _janjiCount;
  int get belumCount => _belumCount;
  int get tidakKetemuCount => _tidakKetemuCount;

  String? _error;
  String? get error => _error;

  String? _currentStatus;
  String? _currentSearch;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  // ─── Auth ─────────────────────────────────────

  Future<bool> tryAutoLogin() async {
    final user = await _authService.getStoredUser();
    if (user != null) {
      _currentUser = user;
      await _loadPinned();
      notifyListeners();
      await refreshPendingCount();
      _startNotificationPolling();
      return true;
    }
    return false;
  }

  Future<void> login(String username, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _authService.login(username, password);
      _currentUser = result['user'] as UserModel;
      await _loadPinned();
      await refreshPendingCount();
      _startNotificationPolling();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    await _authService.logout();
    _currentUser = null;
    _customers = [];
    _pendingCount = 0;
    notifyListeners();
  }

  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final response = await _api.get('/api/va/notifications/pending');
        if (response.data is List && (response.data as List).isNotEmpty) {
          for (var req in response.data) {
            final id = req['id'];
            final custName = req['customer_name'];
            
            // Show local notification
            NotificationService().showNotification(
              id,
              'VA Dibuat',
              'VA nasabah $custName sudah tercreate. Klik disini',
              payload: '{"va_request_id": $id}',
            );
            
            // Mark as notified so we don't spam
            await _api.post('/api/va/$id/mark-notified');
          }
        }
      } catch (e) {
        // ignore errors silently during polling
      }
    });
  }

  // ─── Pinned Data ────────────────────────────────

  Future<void> _loadPinned() async {
    final prefs = await SharedPreferences.getInstance();
    final strings = prefs.getStringList('pinned_customers') ?? [];
    _pinnedIds = strings.map((e) => int.tryParse(e)).whereType<int>().toList();
  }

  Future<void> togglePin(int customerId) async {
    if (_pinnedIds.contains(customerId)) {
      _pinnedIds.remove(customerId);
    } else {
      _pinnedIds.add(customerId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_customers', _pinnedIds.map((e) => e.toString()).toList());
    
    // Reload first page preserving search/filter to show pinned item at the top
    await loadCustomers(
      status: _currentStatus, 
      search: _currentSearch,
      page: 0, 
      showLoading: false
    );
  }

  // ─── Customers ────────────────────────────────

  Future<void> loadCustomers({
    String? status,
    String? search,
    int page = 0,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _setLoading(true);
    }
    _currentPage = page;
    _currentStatus = status;
    _currentSearch = search;

    _setError(null);
    try {
      final offset = _currentPage * _pageSize;
      if (kDebugMode) {
        print('DEBUG: Loading customers page=$_currentPage, status=$_currentStatus, search=$_currentSearch, pinned=$_pinnedIds');
      }
      final responseMap = await _customerService.getCustomers(
        status: status,
        search: search,
        limit: _pageSize,
        offset: offset,
        pinnedIds: _pinnedIds,
      );

      if (kDebugMode) {
        print('DEBUG: Received ${responseMap['customers']?.length} customers, total=${responseMap['total_count']}');
      }

      // Parse stats
      final stats = responseMap['stats'];
      if (stats != null) {
        _totalCount = stats['total'] ?? 0;
        _bayarCount = stats['bayar'] ?? 0;
        _janjiCount = stats['janji_bayar'] ?? 0;
        _belumCount = stats['belum'] ?? 0;
        _tidakKetemuCount = stats['tidak_ketemu'] ?? 0;
      }

      _totalFilteredCount = responseMap['total_count'] ?? 0;

      // Parse customers
      final List customersList = responseMap['customers'] ?? [];
      _customers = customersList.map((e) => CustomerModel.fromJson(e)).toList();

      _hasMore = (_currentPage + 1) * _pageSize < _totalFilteredCount;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (showLoading) {
        _setLoading(false);
      }
    }
  }

  // ─── Collection ───────────────────────────────

  Future<int?> submitCollection({
    required int customerId,
    required String status,
    String? notes,
    double? gpsLat,
    double? gpsLng,
    bool offlineFallback = true,
  }) async {
    _setLoading(true);
    try {
      final result = await _collectionService.submitCollection(
        customerId: customerId,
        status: status,
        notes: notes,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        timestamp: DateTime.now(),
      );
      await loadCustomers();
      return result.id;
    } catch (e) {
      if (offlineFallback) {
        await _offlineQueue.enqueue(
          customerId: customerId,
          status: status,
          notes: notes,
          gpsLat: gpsLat,
          gpsLng: gpsLng,
          timestamp: DateTime.now(),
        );
        await refreshPendingCount();
        return -1; // -1 indicates offline success
      }
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> syncOfflineQueue() async {
    _setLoading(true);
    try {
      final items = await _offlineQueue.getPendingItems();
      if (items.isEmpty) return {'synced_count': 0, 'error_count': 0};

      final payload = _offlineQueue.toApiPayload(items);
      final result = await _collectionService.syncOfflineQueue(payload);

      if ((result['synced_count'] as int) > 0) {
        await _offlineQueue.clearAll();
        await refreshPendingCount();
        await loadCustomers();
      }
      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshPendingCount() async {
    _pendingCount = await _offlineQueue.getPendingCount();
    notifyListeners();
  }

  CollectionService get collectionService => _collectionService;
}
