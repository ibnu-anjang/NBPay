import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Mobile 320px AppBar and Logo layout test', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Test Mobile AppBar
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/nbpay-logo.svg',
                  height: 34,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF258797).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Kasir',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF258797),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {},
              ),
            ],
          ),
          body: const Center(child: Text('Content')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Kasir'), findsOneWidget);
  });

  testWidgets('Login Header renders at height 72 without overflow on 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      SvgPicture.asset(
                        'assets/images/nbpay-logo.svg',
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF258797).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF258797).withValues(alpha: 0.25)),
                        ),
                        child: const Text(
                          'SmartSchool Ecosystem',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Color(0xFF258797),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sistem Pembayaran Kantin Digital & Kartu Cerdas',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('SmartSchool Ecosystem'), findsOneWidget);
  });

  testWidgets('ElevatedButton in Row with AppTheme does NOT throw BoxConstraints forces an infinite width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF258797),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        home: Scaffold(
          body: Row(
            children: [
              const Text('Label'),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.payments),
                label: const Text('Cairkan Saldo'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Cairkan Saldo'), findsOneWidget);
  });
}
