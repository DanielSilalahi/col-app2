import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Stores unsynced collection entries for offline-first support.
class OfflineQueueService {
  static const _dbName = 'collection_offline.db';
  static const _tableName = 'offline_queue';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            status TEXT NOT NULL,
            notes TEXT,
            gps_lat REAL,
            gps_lng REAL,
            timestamp TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> enqueue({
    required int customerId,
    required String status,
    String? notes,
    double? gpsLat,
    double? gpsLng,
    required DateTime timestamp,
  }) async {
    final db = await database;
    return db.insert(_tableName, {
      'customer_id': customerId,
      'status': status,
      'notes': notes,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingItems() async {
    final db = await database;
    return db.query(_tableName, orderBy: 'created_at ASC');
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return result.first['count'] as int;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  List<Map<String, dynamic>> toApiPayload(List<Map<String, dynamic>> items) {
    return items.map((item) => {
      'customer_id': item['customer_id'],
      'status': item['status'],
      'notes': item['notes'],
      'gps_lat': item['gps_lat'],
      'gps_lng': item['gps_lng'],
      'timestamp': item['timestamp'],
    }).toList();
  }
}
