import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class CollectionService {
  final _api = ApiClient();

  Future<CollectionModel> submitCollection({
    required int customerId,
    required String status,
    String? notes,
    double? gpsLat,
    double? gpsLng,
    required DateTime timestamp,
  }) async {
    final response = await _api.post('/api/collections', data: {
      'customer_id': customerId,
      'status': status,
      'notes': notes,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'timestamp': timestamp.toUtc().toIso8601String(),
    });
    return CollectionModel.fromJson(response.data);
  }

  Future<CollectionModel> uploadPhoto({
    required int collectionId,
    required String filePath,
    double? gpsLat,
    double? gpsLng,
  }) async {
    final formData = FormData.fromMap({
      'collection_id': collectionId,
      if (gpsLat != null) 'gps_lat': gpsLat,
      if (gpsLng != null) 'gps_lng': gpsLng,
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _api.postMultipart(
        '/api/collections/upload-photo', formData);
    return CollectionModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> syncOfflineQueue(
      List<Map<String, dynamic>> items) async {
    final response = await _api.post('/api/collections/sync', data: {
      'items': items,
    });
    return response.data;
  }
}
