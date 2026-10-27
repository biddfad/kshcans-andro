import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/main.dart';

class _HttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _HttpOverrides();
  });

  testWidgets('KomikReaderApp mounts and renders bottom navigation properly', (WidgetTester tester) async {
    await tester.pumpWidget(const KomikReaderApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Pastikan bottom navigation destinations dirender
    expect(find.widgetWithText(NavigationDestination, 'Beranda'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Pustaka'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Riwayat'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Jelajahi'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Lainnya'), findsOneWidget);

    // Bersihkan timer async di test environment
    await tester.pump(const Duration(seconds: 35));
  });
}
