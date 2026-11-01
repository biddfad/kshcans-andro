import 'package:flutter/material.dart';

/// Halaman komik yang bisa di-zoom: cubit dua jari, atau ketuk dua kali untuk
/// zoom 2.5x di titik yang diketuk (ketuk dua kali lagi untuk kembali).
class ZoomablePage extends StatefulWidget {
  final Widget child;

  /// Dipanggil saat status zoom berubah (null = tidak perlu dilaporkan)
  final ValueChanged<bool>? onZoomChanged;

  const ZoomablePage({super.key, required this.child, this.onZoomChanged});

  @override
  State<ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<ZoomablePage> with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.5;

  final TransformationController _controller = TransformationController();
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _animation;
  Offset _doubleTapPosition = Offset.zero;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _animController.addListener(() {
      if (_animation != null) _controller.value = _animation!.value;
    });
    _controller.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _isZoomed) return;
    setState(() => _isZoomed = zoomed);
    widget.onZoomChanged?.call(zoomed);
  }

  void _handleDoubleTap() {
    final Matrix4 target;
    if (_isZoomed) {
      target = Matrix4.identity();
    } else {
      // Zoom dengan titik ketuk tetap berada di bawah jari
      final p = _doubleTapPosition;
      target = Matrix4.identity()
        ..translateByDouble(-p.dx * (_doubleTapScale - 1), -p.dy * (_doubleTapScale - 1), 0, 1)
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
    _animation = Matrix4Tween(begin: _controller.value, end: target)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward(from: 0);
  }

  @override
  void dispose() {
    if (_isZoomed && widget.onZoomChanged != null) {
      final callback = widget.onZoomChanged!;
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(false));
    }
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 4.0,
        // Tanpa zoom, geser jari dipakai untuk scroll/pindah halaman
        panEnabled: _isZoomed,
        clipBehavior: Clip.hardEdge,
        child: widget.child,
      ),
    );
  }
}
