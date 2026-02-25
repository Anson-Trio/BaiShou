import 'dart:io';
import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/domain/services/import_service.dart';
import 'package:baishou/features/settings/domain/services/lan_transfer_service.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/features/settings/presentation/widgets/radar_background.dart';
import 'package:baishou/features/settings/presentation/widgets/sync_floating_bubble.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 局域网传输页面
/// 负责处理同一 WiFi 环境下设备间的数据同步与配对逻辑。
class LanTransferPage extends ConsumerStatefulWidget {
  const LanTransferPage({super.key});

  @override
  ConsumerState<LanTransferPage> createState() => _LanTransferPageState();
}

class _LanTransferPageState extends ConsumerState<LanTransferPage>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _floatController;
  LanTransferNotifier? _notifier; // Cache for safe disposal

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
    // 退出页面时关闭服务，防止后台残留
    // 使用缓存的 notifier 进行清理，避免 dispose 时 ref 不可用导致的崩溃
    _notifier?.stopDualMode();
    _radarController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _notifier = ref.read(lanTransferServiceProvider.notifier);

    // 监听状态，处理文件接收通知
    ref.listen(lanTransferServiceProvider, (previous, next) {
      // 1. 处理文件接收成功提示
      if (previous?.lastReceivedFile != next.lastReceivedFile &&
          next.lastReceivedFile != null) {
        if (mounted) {
          AppToast.showSuccess(
            context,
            t.lan_transfer.file_received(
              name: next.lastReceivedFile!.path.split('/').last,
            ),
            duration: const Duration(seconds: 4),
          );
        }
      }

      // 2. 处理自动导入请求 (新增)
      if (previous?.receivedFileToImport != next.receivedFileToImport &&
          next.receivedFileToImport != null) {
        _showImportConfirmDialog(context, next.receivedFileToImport!);
      }

      if (previous?.error != next.error && next.error != null) {
        if (mounted) {
          AppToast.showError(
            context,
            next.error!,

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
          t.lan_transfer.title,
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
              painter: RadarPainter(
                animation: _radarController,
                color: primary,
              ),
            ),
          ),

          // 2. 中心节点 (自己)
          Center(child: PulseCore(color: primary)),

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
                    t.lan_transfer.scanning_nearby,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.lan_transfer.scan_hint,
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
              child: SyncFloatingBubble(
                animation: _floatController,
                delay: index * 0.5, // 错开浮动动画
                service: service,
                onTap: () async {
                  _handleDeviceTap(context, ref, service);
                },
              ),
            );
          }),

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
                label: Text(t.lan_transfer.scan_button),
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
            Text(
              t.lan_transfer.qr_dialog_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
          title: Text(t.lan_transfer.send_confirm_title(nickname: nickname)),
          content: Text(t.lan_transfer.send_confirm_content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.common.export),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (context.mounted) {
          AppToast.showSuccess(context, t.lan_transfer.sending_status);
        }

        // 执行 Push 发送
        final success = await notifier.sendFileTo(ip, port);

        if (context.mounted) {
          if (success) {
            AppToast.showSuccess(
              context,
              t.lan_transfer.sent_success(nickname: nickname),
            );
          }
          // 错误信息已由 state 监听处理
        }
      }
    } else {
      if (context.mounted) {
        AppToast.showError(context, t.lan_transfer.ip_not_found);
      }
    }
  }

  void _showImportConfirmDialog(BuildContext context, File file) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(t.lan_transfer.received_backup_title),
        content: Text(
          t.lan_transfer.received_backup_content(
            size: (file.lengthSync() / 1024 / 1024).toStringAsFixed(2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(lanTransferServiceProvider.notifier)
                  .consumeReceivedFile();
              Navigator.pop(context);
            },
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);

              // 消费信号
              ref
                  .read(lanTransferServiceProvider.notifier)
                  .consumeReceivedFile();

              _importFile(file);
            },
            child: Text(t.common.restore),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile(File file) async {
    // 用一个变量捕获弹窗自己的 BuildContext，确保关闭的是正确的弹窗
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    // 等待一帧，确保弹窗已经完全建立
    await Future.delayed(Duration.zero);

    void closeDialog() {
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
        debugPrint('UI: Loading dialog popped via dialogContext');
      }
    }

    try {
      debugPrint('UI: Stopping dual mode...');
      await ref.read(lanTransferServiceProvider.notifier).stopDualMode();

      debugPrint('UI: Calling importFromZip...');
      final importService = ref.read(importServiceProvider);
      final result = await importService.importFromZip(file);

      debugPrint('UI: Import returned with success=${result.success}');

      closeDialog();

      if (result.success) {
        if (mounted) {
          ref.read(dataRefreshProvider.notifier).refresh();
          AppToast.showSuccess(context, t.common.success);
        }

        if (result.configData != null) {
          debugPrint('UI: Scheduling restoreConfig after page close...');
          Future.delayed(const Duration(milliseconds: 300), () {
            importService.restoreConfig(result.configData!);
          });
        }
      } else {
        if (mounted) {
          AppToast.showError(
            context,
            t.settings.import_failed_with_error(error: result.error ?? ''),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('UI: Error in _importFile: $e\n$stack');
      closeDialog();
      if (mounted) {
        AppToast.showError(context, t.common.error);
      }
    }
  }
}

// --- UI 组件分离至 `radar_background.dart` 与 `sync_floating_bubble.dart` ---

class _QRScanPage extends ConsumerWidget {
  const _QRScanPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(t.lan_transfer.qr_scan_title)),
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
