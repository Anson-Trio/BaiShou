import 'dart:math';
import 'dart:ui';

import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/domain/services/lan_transfer_service.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LanTransferPage extends ConsumerStatefulWidget {
  const LanTransferPage({super.key});

  @override
  ConsumerState<LanTransferPage> createState() => _LanTransferPageState();
}

class _LanTransferPageState extends ConsumerState<LanTransferPage>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();

    // 进入页面自动开启双向模式 (广播 + 发现)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lanTransferServiceProvider.notifier).startDualMode();
    });

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听状态，处理文件接收通知
    ref.listen(lanTransferServiceProvider, (previous, next) {
      // 检测是否收到了新文件
      if (previous?.lastReceivedFile != next.lastReceivedFile &&
          next.lastReceivedFile != null) {
        if (mounted) {
          AppToast.show(
            context,
            '已接收文件: ${next.lastReceivedFile!.path.split('/').last}',
            icon: Icons.download_done,
            duration: const Duration(seconds: 4),
          );
        }
      }

      if (previous?.error != next.error && next.error != null) {
        if (mounted) {
          AppToast.show(
            context,
            next.error!,
            icon: Icons.error_outline,
            // backgroundColor: Colors.red, // AppToast 会自动处理颜色，或者是默认样式
          );
        }
      }
    });

    final state = ref.watch(lanTransferServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 背景色，参考用户设计
    final bgLight = const Color(0xFFF6F7F8);
    final bgDark = const Color(0xFF101922);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '局域网传输',
          style: TextStyle(
            color: isDark ? Colors.grey[100] : Colors.grey[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.qr_code,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
            onPressed: () {
              _showQrCodeDialog(context, state);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. 雷达背景
          Positioned.fill(
            child: CustomPaint(
              painter: _RadarPainter(
                animation: _radarController,
                color: primary,
              ),
            ),
          ),

          // 2. 中心节点 (自己)
          Center(child: _PulseCore(color: primary)),

          // 3. 浮动气泡 (发现的设备)
          if (state.discoveredServices.isEmpty && state.isDiscovering)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '正在搜索附近设备...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请确保接收设备已打开「白守」并连接至同一Wi-Fi',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

          ...state.discoveredServices.asMap().entries.map((entry) {
            final index = entry.key;
            final service = entry.value;
            // 为气泡分配固定位置，避免重叠
            // 5个固定偏移位置
            final offsets = [
              const Offset(-0.6, -0.6), // 左上
              const Offset(0.6, -0.4), // 右上
              const Offset(0.0, 0.6), // 下中
              const Offset(-0.5, 0.5), // 左下
              const Offset(0.5, 0.5), // 右下
            ];

            final offset = offsets[index % offsets.length];

            return Align(
              alignment: Alignment(offset.dx, offset.dy),
              child: _FloatingBubble(
                animation: _floatController,
                delay: index * 0.5, // 错开浮动动画
                service: service,
                onTap: () async {
                  _handleDeviceTap(context, ref, service);
                },
              ),
            );
          }).toList(),

          // 4. 扫码按钮 (底部)
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const _QRScanPage(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫一扫连接'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrCodeDialog(BuildContext context, LanTransferState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.serverIp != null && state.serverPort != null)
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: 'http://${state.serverIp}:${state.serverPort}/download',
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            const SizedBox(height: 16),
            Text('扫描二维码以连接', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeviceTap(
    BuildContext context,
    WidgetRef ref,
    BonsoirService service,
  ) async {
    final notifier = ref.read(lanTransferServiceProvider.notifier);
    final ip = service.attributes['ip'];
    final port = service.port;
    final nickname = service.attributes['nickname'] ?? service.name;

    if (ip != null && ip != 'Unknown') {
      // 显示确认对话框
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('发送数据给 $nickname?'),
          content: const Text('将生成数据备份并发送给该设备。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('发送'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (context.mounted) {
          AppToast.show(context, '正在生成并发送数据...');
        }

        // 执行 Push 发送
        final success = await notifier.sendFileTo(ip, port);

        if (context.mounted) {
          if (success) {
            AppToast.show(context, '已发送给 $nickname');
          }
          // 错误信息已由 state 监听处理
        }
      }
    } else {
      if (context.mounted) {
        AppToast.show(context, '无法获取设备IP', icon: Icons.error_outline);
      }
    }
  }
}

class _RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _RadarPainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = color.withOpacity(0.1)
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

class _PulseCore extends StatefulWidget {
  final Color color;
  const _PulseCore({required this.color});

  @override
  State<_PulseCore> createState() => _PulseCoreState();
}

class _PulseCoreState extends State<_PulseCore>
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
            color: widget.color.withOpacity(0.1),
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
                    color: widget.color.withOpacity(0.4),
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

class _FloatingBubble extends StatelessWidget {
  final AnimationController animation;
  final double delay;
  final BonsoirService service;
  final VoidCallback onTap;

  const _FloatingBubble({
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
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.08),
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
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getIconForName(service.name),
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

  IconData _getIconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('macbook') ||
        lower.contains('desktop') ||
        lower.contains('pc'))
      return Icons.laptop_mac;
    if (lower.contains('iphone') ||
        lower.contains('phone') ||
        lower.contains('android'))
      return Icons.smartphone;
    if (lower.contains('ipad') || lower.contains('tablet'))
      return Icons.tablet_mac;
    return Icons.devices;
  }
}

class _QRScanPage extends ConsumerWidget {
  const _QRScanPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描二维码')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              final url = barcode.rawValue!;
              if (url.startsWith('http')) {
                if (!context.mounted) return;

                // 关闭扫码页
                Navigator.pop(context);

                ref
                    .read(lanTransferServiceProvider.notifier)
                    .downloadFromUrl(url)
                    .then((file) {
                      if (file != null) {
                        debugPrint('File downloaded: ${file.path}');
                      }
                    });
                return;
              }
            }
          }
        },
      ),
    );
  }
}
