import 'package:flutter/material.dart';

/// 局域网搜寻雷达中心节点
class PulseCore extends StatefulWidget {
  final Color color;
  const PulseCore({super.key, required this.color});

  @override
  State<PulseCore> createState() => _PulseCoreState();
}

class _PulseCoreState extends State<PulseCore>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 80 * _animation.value,
          height: 80 * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.cell_tower, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

/// 发射状雷达环背景特效绘制
class RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  RadarPainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 绘制固定圆环
    canvas.drawCircle(center, 100, paint);
    canvas.drawCircle(center, 200, paint);
    canvas.drawCircle(center, 300, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
