import 'package:flutter/material.dart';
import 'package:rd_app/core/app_theme.dart';
import 'package:rd_app/shared/retinazo_logo.dart';

/// One entrance per mounted page; never keeps a background ticker running.
class AuthEntrance extends StatefulWidget {
  const AuthEntrance({super.key, required this.builder});

  final Widget Function(BuildContext, Animation<double>) builder;

  @override
  State<AuthEntrance> createState() => _AuthEntranceState();
}

class _AuthEntranceState extends State<AuthEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

class AuthReveal extends StatelessWidget {
  const AuthReveal({
    super.key,
    required this.animation,
    required this.child,
    this.start = 0,
    this.end = 1,
    this.distance = 36,
    this.scale = false,
  }) : assert(start >= 0 && start < end && end <= 1);

  final Animation<double> animation;
  final Widget child;
  final double start;
  final double end;
  final double distance;
  final bool scale;

  @override
  Widget build(BuildContext context) {
    final progress = animation.drive(CurveTween(curve: Interval(start, end)));
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (_, child) => Opacity(
        opacity: Curves.easeOut.transform(progress.value),
        child: Transform.translate(
          offset: Offset(
            0,
            distance * (1 - Curves.easeOutCubic.transform(progress.value)),
          ),
          child: Transform.scale(
            scale: scale
                ? .76 + .24 * Curves.easeOutBack.transform(progress.value)
                : 1,
            child: child,
          ),
        ),
      ),
    );
  }
}

class AuthLogoBadge extends StatelessWidget {
  const AuthLogoBadge({super.key, this.size = 164});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFEDF8F3),
      border: Border.all(color: const Color(0xFFDCEFE9), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x16033131),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Center(child: RetinazoLogo(size: size * .94)),
  );
}

/// Decorative only: the curved green surface never intercepts page gestures.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _AuthHeaderPainter(), child: child);
}

class _AuthHeaderPainter extends CustomPainter {
  const _AuthHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final curve = Path()
      ..lineTo(0, size.height - 58)
      ..quadraticBezierTo(
        size.width * .42,
        size.height + 48,
        size.width,
        size.height - 35,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.save();
    canvas.clipPath(curve);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF085C60), AppTheme.primario, Color(0xFF19877D)],
        ).createShader(bounds),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuthHeaderPainter oldDelegate) => false;
}

ButtonStyle authPrimaryButton() => FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(56),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    fontWeight: FontWeight.w700,
  ),
);
