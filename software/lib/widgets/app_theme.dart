import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A horizontally scrollable chip row that supports:
/// 1. Mouse vertical wheel translation to horizontal scroll (Web/Desktop)
/// 2. Click & drag with mouse/touchpad/finger
/// 3. Interactive chevron buttons (< and >) for 1-click desktop scrolling
class HorizontalScrollChips extends StatefulWidget {
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const HorizontalScrollChips({
    super.key,
    required this.children,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<HorizontalScrollChips> createState() => _HorizontalScrollChipsState();
}

class _HorizontalScrollChipsState extends State<HorizontalScrollChips> {
  final ScrollController _ctrl = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  void _checkScroll() {
    if (!_ctrl.hasClients) return;
    final max = _ctrl.position.maxScrollExtent;
    final offset = _ctrl.offset;
    final left = offset > 4;
    final right = offset < max - 4;
    if (left != _canScrollLeft || right != _canScrollRight) {
      if (mounted) setState(() { _canScrollLeft = left; _canScrollRight = right; });
    }
  }

  void _scrollDelta(double delta) {
    if (!_ctrl.hasClients) return;
    final target = (_ctrl.offset + delta).clamp(0.0, _ctrl.position.maxScrollExtent);
    _ctrl.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_checkScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _ctrl.hasClients) {
          final delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
          if (delta != 0) {
            final target = (_ctrl.offset + delta).clamp(0.0, _ctrl.position.maxScrollExtent);
            _ctrl.jumpTo(target);
          }
        }
      },
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            if (_canScrollLeft)
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                tooltip: 'Geser ke kiri',
                onPressed: () => _scrollDelta(-140),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _ctrl,
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Row(children: widget.children),
              ),
            ),
            if (_canScrollRight)
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                tooltip: 'Geser ke kanan',
                onPressed: () => _scrollDelta(140),
              ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

/// Global scroll behavior that allows dragging with touch, mouse, trackpad, and stylus.
/// Prevents horizontal scroll rows (e.g. quick amount chips) from feeling stuck on desktop/web.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

/// Returns true if machine hasn't sent heartbeat in the last 60 seconds, or heartbeat is missing.
bool isMachineOffline(dynamic lastHeartbeat) {
  if (lastHeartbeat == null || lastHeartbeat is! Timestamp) return true;
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
  static const secondaryColor = Color(0xFF0EA5E9); // Sky Blue (NBPay brand)
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
      secondaryContainer: Colors.white,
      onSecondaryContainer: bgColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: cardColor,
      indicatorColor: Colors.white,
      selectedIconTheme: IconThemeData(color: bgColor),
      unselectedIconTheme: IconThemeData(color: Colors.white60),
      selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: TextStyle(color: Colors.white54),
      labelType: NavigationRailLabelType.all,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardColor,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardColor,
      indicatorColor: Colors.white,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: bgColor);
        }
        return const IconThemeData(color: Colors.white60);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
        }
        return const TextStyle(color: Colors.white54, fontSize: 12);
      }),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: bgColor,
      unselectedLabelColor: Colors.white60,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      indicator: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: secondaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
