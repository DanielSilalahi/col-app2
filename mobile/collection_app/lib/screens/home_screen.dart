import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/app_provider.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/customer_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedStatus = 'belum';
  String _currentSort = 'A-Z';
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  final _statusFilters = [
    null,
    'belum',
    'janji_bayar',
    'bayar',
    'tidak_ketemu',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadCustomers(status: _selectedStatus);
    });
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.read<AppProvider>().loadCustomers(
            status: _selectedStatus,
            search: _searchCtrl.text,
          );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncOffline() async {
    final provider = context.read<AppProvider>();
    try {
      final result = await provider.syncOfflineQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✓ Sync selesai: ${result['synced_count']} berhasil, ${result['error_count']} gagal'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Gagal sync. Pastikan koneksi aktif.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    // Pagination handles filtering and search server-side now.
    // We only keep the local sorting for the current view.
    final _filtered = List<CustomerModel>.from(provider.customers);

    _filtered.sort((a, b) {
      final aPinned = provider.pinnedIds.contains(a.id);
      final bPinned = provider.pinnedIds.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      
      // Sort logic
      switch (_currentSort) {
        case 'Z-A':
          return b.name.compareTo(a.name);
        case 'OVD Tertinggi':
          return (b.overdueDays ?? 0).compareTo(a.overdueDays ?? 0);
        case 'OVD Terendah':
          return (a.overdueDays ?? 0).compareTo(b.overdueDays ?? 0);
        case 'Outstanding Tertinggi':
          return (b.outstandingAmount ?? 0.0).compareTo(a.outstandingAmount ?? 0.0);
        case 'Outstanding Terendah':
          return (a.outstandingAmount ?? 0.0).compareTo(b.outstandingAmount ?? 0.0);
        case 'A-Z':
        default:
          return a.name.compareTo(b.name);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collection P2P',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              provider.currentUser?.name ?? '',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Offline sync badge
          if (provider.pendingCount > 0)
            IconButton(
              icon: Badge(
                label: Text('${provider.pendingCount}'),
                child: const Icon(Icons.cloud_upload_outlined),
              ),
              tooltip: 'Sync ${provider.pendingCount} data offline',
              onPressed: _syncOffline,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await provider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats summary bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: const _StatsRow(),
          ),

          // Search + filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Cari nama / telepon...',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.sort, color: AppColors.textPrimary),
                          tooltip: 'Urutkan data',
                          initialValue: _currentSort,
                          onSelected: (String value) {
                            setState(() {
                              _currentSort = value;
                            });
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(value: 'A-Z', child: Text('A-Z (Nama)')),
                            const PopupMenuItem<String>(value: 'Z-A', child: Text('Z-A (Nama)')),
                            const PopupMenuItem<String>(value: 'OVD Tertinggi', child: Text('OVD Tertinggi')),
                            const PopupMenuItem<String>(value: 'OVD Terendah', child: Text('OVD Terendah')),
                            const PopupMenuItem<String>(value: 'Outstanding Tertinggi', child: Text('OS Tertinggi')),
                            const PopupMenuItem<String>(value: 'Outstanding Terendah', child: Text('OS Terendah')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _statusFilters.map((s) {
                      final isSelected = _selectedStatus == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            s == null ? 'Semua' : AppColors.statusLabel(s),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor:
                              s == null ? AppColors.primary : AppColors.statusColor(s ?? ''),
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                           onSelected: (_) {
                             setState(() => _selectedStatus = s);
                             context.read<AppProvider>().loadCustomers(
                               status: s,
                               search: _searchCtrl.text,
                             );
                           },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: provider.isLoading && provider.customers.isEmpty
                ? const Center(
                    child: SpinKitFadingCircle(
                        color: AppColors.primary, size: 48))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              provider.customers.isEmpty
                                  ? 'Belum ada customer'
                                  : 'Tidak ada hasil',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                      : RefreshIndicator(
                          onRefresh: () => context.read<AppProvider>().loadCustomers(
                                status: _selectedStatus,
                                search: _searchCtrl.text,
                              ),
                          color: AppColors.primary,
                         child: ListView.builder(
                           padding: const EdgeInsets.all(12),
                           itemCount: _filtered.length,
                           itemBuilder: (ctx, i) {
                             return CustomerCard(
                               customer: _filtered[i],
                               onTap: () => Navigator.pushNamed(
                                 context,
                                 '/customer-detail',
                                 arguments: _filtered[i],
                               ).then((_) => context.read<AppProvider>().loadCustomers(
                                     status: _selectedStatus,
                                     search: _searchCtrl.text,
                                     page: provider.currentPageIndex,
                                     showLoading: false,
                                   )),
                             );
                           },
                         ),
                       ),
          ),
          
          // Pagination Bar
          if (provider.totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _PaginationWidget(
                currentPage: provider.currentPageIndex + 1,
                totalPages: provider.totalPages,
                onPageSelected: (page) {
                  context.read<AppProvider>().loadCustomers(
                        status: _selectedStatus,
                        search: _searchCtrl.text,
                        page: page - 1,
                      );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageSelected;

  const _PaginationWidget({
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    // Prev
    children.add(
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: currentPage > 1 ? () => onPageSelected(currentPage - 1) : null,
      ),
    );

    // Page Numbers logic: 1, ..., cur-1, cur, cur+1, ..., total
    List<int> pages = [];
    if (totalPages <= 5) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      pages.add(1);
      if (currentPage > 3) pages.add(-1); // -1 means ellipsis
      
      int start = currentPage - 1;
      int end = currentPage + 1;
      if (start <= 1) { start = 2; end = 4; }
      if (end >= totalPages) { end = totalPages - 1; start = totalPages - 3; }
      
      for (int i = start; i <= end; i++) {
        if (i > 1 && i < totalPages) pages.add(i);
      }

      if (currentPage < totalPages - 2) pages.add(-1);
      pages.add(totalPages);
    }

    for (var p in pages) {
      if (p == -1) {
        children.add(const Text('...'));
      } else {
        final isSelected = p == currentPage;
        children.add(
          InkWell(
            onTap: () => onPageSelected(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$p',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Next
    children.add(
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: currentPage < totalPages ? () => onPageSelected(currentPage + 1) : null,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 60,
              height: 36,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Go',
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onSubmitted: (value) {
                  final page = int.tryParse(value);
                  if (page != null && page >= 1 && page <= totalPages) {
                    onPageSelected(page);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Row(
      children: [
        _Stat(label: 'Total', value: '${provider.totalCount}', color: Colors.white),
        _Stat(label: 'Bayar', value: '${provider.bayarCount}', color: const Color(0xFF6EE7B7)),
        _Stat(label: 'Janji', value: '${provider.janjiCount}', color: const Color(0xFFFCD34D)),
        _Stat(label: 'Belum', value: '${provider.belumCount}', color: const Color(0xFFFCA5A5)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }
}
