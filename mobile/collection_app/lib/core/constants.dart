import 'package:flutter/material.dart';

class AppConstants {
  // Change this to your server IP when testing on physical device
  // static const String baseUrl = 'http://10.0.2.2:8001'; // Android emulator
  // static const String baseUrl = 'http://127.0.0.1:8001'; // iOS simulator
  // PRODUCTION SERVER URL
  //static const String baseUrl = 'http://192.168.88.80:8001';
  static const String baseUrl = 'https://daniel766.my.id';

  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
}

class AppColors {
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color secondary = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color cardBg = Colors.white;

  // Status colors
  static Color statusColor(String status) {
    switch (status) {
      case 'bayar':
        return const Color(0xFF10B981);
      case 'janji_bayar':
        return const Color(0xFFF59E0B);
      case 'tidak_ketemu':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'bayar':
        return 'Bayar';
      case 'janji_bayar':
        return 'Janji Bayar';
      case 'tidak_ketemu':
        return 'Tidak Ketemu';
      case 'belum':
        return 'Belum';
      default:
        return status;
    }
  }
}
