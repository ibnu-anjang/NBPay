import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Returns true if machine hasn't sent heartbeat in the last 60 seconds.
bool isMachineOffline(dynamic lastHeartbeat) {
  if (lastHeartbeat is! Timestamp) return false;
  return DateTime.now().difference(lastHeartbeat.toDate()).inSeconds > 60;
}

/// Status color + label for a machine given its Firestore data map.
({Color color, String label}) machineStatusStyle(Map<String, dynamic> m) {
  if (isMachineOffline(m['last_heartbeat'])) {
    return (color: Colors.white38, label: 'Offline');
  }
  return switch (m['status'] as String? ?? 'idle') {
    'waiting_tap'   => (color: const Color(0xFFF59E0B), label: 'Menunggu Tap'),
    'waiting_check' => (color: const Color(0xFF0EA5E9), label: 'Memproses'),
    'showing_saldo' => (color: const Color(0xFF22C55E), label: 'Tampil Saldo'),
    'success'       => (color: const Color(0xFF22C55E), label: 'Berhasil'),
    'error'         => (color: const Color(0xFFEF4444), label: 'Error'),
    _               => (color: const Color(0xFF22C55E), label: 'Siap'),
  };
}

class AppTheme {
  static const primaryColor = Color(0xFF6366F1); // Indigo
  static const secondaryColor = Color(0xFFEC4899); // Pink
  static const bgColor = Color(0xFF0F172A); // Dark Slate
  static const cardColor = Color(0xFF1E293B);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: cardColor,
    ),
    // textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
