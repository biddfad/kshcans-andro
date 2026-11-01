import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/features/reader/widgets/zoomable_page.dart';

void main() {
  Future<List<bool>> pumpPage(WidgetTester tester) async {
    final events = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 600,
          child: ZoomablePage(
            onZoomChanged: events.add,
            child: Container(color: Colors.blue),
          ),
        ),
      ),
    ));
    return events;
  }

  Future<void> doubleTap(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(ZoomablePage));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
  }

  double currentScale(WidgetTester tester) {
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    return viewer.transformationController!.value.getMaxScaleOnAxis();
  }

  testWidgets('ketuk dua kali memperbesar, ketuk dua kali lagi mengembalikan', (tester) async {
    final events = await pumpPage(tester);
    expect(currentScale(tester), closeTo(1.0, 0.01));

    await doubleTap(tester);
    expect(currentScale(tester), closeTo(2.5, 0.01));
    expect(events, [true]);

    await doubleTap(tester);
    expect(currentScale(tester), closeTo(1.0, 0.01));
    expect(events, [true, false]);
  });

  testWidgets('geser hanya aktif saat di-zoom, gambar tidak meluber', (tester) async {
    await pumpPage(tester);
    InteractiveViewer viewer() => tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer().panEnabled, isFalse);
    expect(viewer().clipBehavior, Clip.hardEdge);

    await doubleTap(tester);
    expect(viewer().panEnabled, isTrue);
  });
}
