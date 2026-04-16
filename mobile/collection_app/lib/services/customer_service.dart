import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class CustomerService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> getCustomers({
    String? status,
    String? search,
    int limit = 20,
    int offset = 0,
    List<int>? pinnedIds,
  }) async {
    final response = await _api.get(
      '/api/customers',
      params: {
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
        'offset': offset,
        if (pinnedIds != null && pinnedIds.isNotEmpty) 'pinned_ids': pinnedIds,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getCustomerDetail(int customerId) async {
    final response = await _api.get('/api/customers/$customerId');
    return response.data;
  }
}
