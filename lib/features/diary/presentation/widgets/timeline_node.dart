import 'package:baishou/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TimelineNode extends StatelessWidget {
  final Widget child;
  final bool isLast;
  final bool isFirst;
  final Widget? indicator;
  final Color? lineColor;

  const TimelineNode({
    super.key,
    required this.child,
    this.isLast = false,
    this.isFirst = false,
    this.indicator,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // The Line
                if (!isLast)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 20, // Center of 40 width
                    child: Container(
                      width: 2,
                      color:
                          lineColor ?? AppTheme.backgroundDark.withOpacity(0.1),
                    ),
                  ),
                // The Dot
                Positioned(
                  top: 24, // Align with card top content
                  left: 15, // Center: 20 - (10/2) = 15
                  child:
                      indicator ??
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }
}
