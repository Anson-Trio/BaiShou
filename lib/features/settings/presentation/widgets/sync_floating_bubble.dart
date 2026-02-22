import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';

/// 局域网传输使用的毛玻璃悬浮气泡，用于展示被发现的接收端设备
class SyncFloatingBubble extends StatelessWidget {
  final AnimationController animation;
  final double delay;
  final BonsoirService service;
  final VoidCallback onTap;

  const SyncFloatingBubble({
    super.key,
    required this.animation,
    required this.delay,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // 基于 delay 增加相位偏移
        final value = sin((animation.value * 2 * pi) + delay);
        final dy = value * 10; // 上下浮动 10px

        return Transform.translate(
          offset: Offset(0, dy),
          child: GestureDetector(
            onTap: onTap,
            // 毛玻璃气泡效果
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getIconForName(),
                          size: 24,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        service.attributes['nickname'] ?? service.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForName() {
    // 1. 优先使用广播中携带的设备类型
    final deviceType = service.attributes['device_type'];
    if (deviceType == 'mobile') return Icons.smartphone;
    if (deviceType == 'desktop') return Icons.computer;

    // 2. 降级使用名称匹配
    final name = service.name.toLowerCase();
    if (name.contains('macbook') ||
        name.contains('desktop') ||
        name.contains('pc')) {
      return Icons.computer;
    }
    if (name.contains('iphone') ||
        name.contains('phone') ||
        name.contains('android')) {
      return Icons.smartphone;
    }
    if (name.contains('ipad') || name.contains('tablet')) {
      return Icons.tablet_mac;
    }
    return Icons.devices;
  }
}
