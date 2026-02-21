import 'package:flutter/material.dart';

/// 全局吐司（Toast）工具类
/// 使用 Overlay 实现在屏幕顶部滑出的轻量级通知。
class AppToast {
  static OverlayEntry? _currentEntry;

  /// 显示成功提示
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    IconData? icon,
    Color? iconColor,
  }) {
    show(
      context,
      message,
      duration: duration,
      icon: icon ?? Icons.check_circle_outline,
      iconColor: iconColor ?? Colors.green.shade600,
      backgroundColor: backgroundColor,
    );
  }

  /// 显示错误提示
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    Color? backgroundColor,
    IconData? icon,
    Color? iconColor,
  }) {
    show(
      context,
      message,
      duration: duration,
      icon: icon ?? Icons.error_outline,
      iconColor: iconColor ?? Colors.red.shade600,
      backgroundColor: backgroundColor,
    );
  }

  /// 通放显示方法
  /// 管理 OverlayEntry 的生命周期，确保同一时间只有一个 Toast。
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    // 移除之前的 Toast
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon ?? Icons.info_outline,
        backgroundColor: backgroundColor,
        iconColor: iconColor,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Slide from right
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  /// 触发消失动画并移除组件
  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C2936)
            : Colors.white);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _dismiss,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 100) {
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color:
                          widget.iconColor ??
                          Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
