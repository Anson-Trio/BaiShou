import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:uuid/uuid.dart';

import 'export_service.dart';
import 'user_profile_service.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 局域网传输状态管理
/// 包含广播状态、发现状态、服务器信息以及最近接收的文件
class LanTransferState {
  final bool isBroadcasting;
  final bool isDiscovering;
  final List<BonsoirService> discoveredServices;
  final String? serverIp;
  final int? serverPort;
  final String? error;
  final File? lastReceivedFile; // 新增：最近接收到的文件
  final File? receivedFileToImport; // 新增：待导入的文件（用于 UI 触发弹窗）

  const LanTransferState({
    this.isBroadcasting = false,
    this.isDiscovering = false,
    this.discoveredServices = const [],
    this.serverIp,
    this.serverPort,
    this.error,
    this.lastReceivedFile,
    this.receivedFileToImport,
  });

  LanTransferState copyWith({
    bool? isBroadcasting,
    bool? isDiscovering,
    List<BonsoirService>? discoveredServices,
    String? serverIp,
    int? serverPort,
    String? error,
    File? lastReceivedFile,
    File? receivedFileToImport,
  }) {
    return LanTransferState(
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      discoveredServices: discoveredServices ?? this.discoveredServices,
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      error: error,
      lastReceivedFile: lastReceivedFile ?? this.lastReceivedFile,
      receivedFileToImport: receivedFileToImport ?? this.receivedFileToImport,
    );
  }
}

class LanTransferNotifier extends Notifier<LanTransferState> {
  static const String _serviceType = '_baishou._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  HttpServer? _server;

  @override
  LanTransferState build() {
    return const LanTransferState();
  }

  // --- 发送端逻辑 (广播 & 服务) ---

  /// 启动广播服务
  /// 仅启动 HTTP 服务器和 mDNS 广播，不自动导出文件
  Future<void> startBroadcasting() async {
    try {
      state = state.copyWith(error: null);

      final userProfile = ref.read(userProfileProvider);

      // 1. 启动 HTTP 服务器
      final handler = _createRouter();

      // 使用端口 0 让操作系统自动分配可用端口，彻底解决端口死锁和僵尸分配冲突问题
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        0,
        shared: true,
      );
      final port = _server!.port;

      // 2. 获取本机所有 IPv4 地址
      // 不再依赖可能获取到错误接口（例如蜂窝网络或 VPN）的 NetworkInfo
      // 我们直接读取底层网卡的所有 IPv4 地址
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      final validIps = interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .where((ip) => ip != '127.0.0.1')
          .toList();

      // 最多取前 4 个 IP，拼成逗号分隔符存进 mDNS（太长超限制）
      final ipString = validIps.isNotEmpty
          ? validIps.take(4).join(',')
          : 'Unknown';
      // 用第一个 IP 用于自身 UI 状态的展示和二维码生成
      final displayIp = validIps.isNotEmpty ? validIps.first : 'Unknown';

      state = state.copyWith(serverIp: displayIp, serverPort: port);

      // 2. 启动 mDNS 广播
      // 服务名称包含昵称和 UUID 前缀，防止冲突
      // 限制昵称长度，防止 mDNS 数据包过大导致解析错误 (EOFException)
      String safeNickname = userProfile.nickname;
      if (safeNickname.length > 10) {
        safeNickname = safeNickname.substring(0, 10);
      }

      // 替换掉可能破坏 mDNS 格式的特殊字符
      safeNickname = safeNickname.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '');
      if (safeNickname.isEmpty) safeNickname = 'User';

      final serviceName =
          'BaiShou-$safeNickname-${const Uuid().v4().substring(0, 4)}';
      final deviceType = Platform.isAndroid || Platform.isIOS
          ? 'mobile'
          : (Platform.isMacOS || Platform.isWindows || Platform.isLinux
                ? 'desktop'
                : 'other');

      debugPrint('Starting broadcast service: $serviceName');

      final service = BonsoirService(
        name: serviceName,
        type: _serviceType,
        port: port,
        attributes: {
          'nickname': userProfile.nickname,
          'ip': ipString,
          'device_type': deviceType,
        },
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();

      state = state.copyWith(isBroadcasting: true);
    } catch (e) {
      state = state.copyWith(
        error: t.lan_transfer.broadcast_failed(e: e.toString()),
      );
      await stopBroadcasting();
    }
  }

  Future<void> stopBroadcasting() async {
    await _broadcast?.stop();
    await _server?.close(force: true);
    _broadcast = null;
    _server = null;
    state = state.copyWith(
      isBroadcasting: false,
      serverIp: null,
      serverPort: null,
    );
  }

  /// 创建 HTTP 路由处理
  Handler _createRouter() {
    final router = shelf_router.Router();
    final userProfile = ref.read(userProfileProvider);

    // GET /download: 允许接收者主动拉取 (保留作为一种方式, 例如扫码)
    router.get('/download', (Request request) async {
      try {
        final exportService = ref.read(exportServiceProvider);

        // 1. Prepare Zip File (Optional pre-generation, usually not needed if serving on demand, but kept for cache)
        // 不调用系统分享
        final zipFile = await exportService.exportToZip(share: false);
        if (zipFile == null) {
          return Response.internalServerError(
            body: t.settings.backup_create_failed,
          );
        }

        return Response.ok(
          zipFile.openRead(),
          headers: {
            'Content-Type': 'application/zip',
            'Content-Disposition':
                'attachment; filename="${path.basename(zipFile.path)}"',
          },
        );
      } catch (e) {
        return Response.internalServerError(body: '${t.common.error}: $e');
      }
    });

    // POST /upload: 接收发送者推送的文件 (Push 模式)
    router.post('/upload', (Request request) async {
      try {
        // 读取请求体中的文件数据
        // 使用流式写入，避免大文件内存溢出
        final dir = await getApplicationDocumentsDirectory();
        final fileName =
            'received_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
        final file = File(path.join(dir.path, fileName));

        final sink = file.openWrite();
        try {
          await sink.addStream(request.read());
          await sink.flush();
        } finally {
          await sink.close();
        }

        // 确保文件句柄释放
        await Future.delayed(const Duration(milliseconds: 200));

        // 更新状态，通知 UI 收到新文件 (同时触发弹窗信号)
        state = state.copyWith(
          lastReceivedFile: file,
          receivedFileToImport: file,
        );

        return Response.ok(t.common.success);
      } catch (e) {
        return Response.internalServerError(
          body: t.lan_transfer.receive_failed(e: e.toString()),
        );
      }
    });

    // GET /info: 提供设备基本信息
    router.get('/info', (Request request) {
      return Response.ok(
        '{"nickname": "${userProfile.nickname}"}',
        headers: {'Content-Type': 'application/json'},
      );
    });

    return router.call;
  }

  /// 消费待导入文件信号 (UI 处理完弹窗后调用)
  void consumeReceivedFile() {
    // 显式置空 receivedFileToImport
    state = LanTransferState(
      isBroadcasting: state.isBroadcasting,
      isDiscovering: state.isDiscovering,
      discoveredServices: state.discoveredServices,
      serverIp: state.serverIp,
      serverPort: state.serverPort,
      error: state.error,
      lastReceivedFile: state.lastReceivedFile,
      receivedFileToImport: null,
    );
  }

  // --- 双向模式 (广播 + 发现) ---

  /// 同时启动广播和发现服务
  /// 进入局域网传输页面时调用
  Future<void> startDualMode() async {
    // 并发启动
    await Future.wait([startBroadcasting(), startDiscovery()]);
  }

  Future<void> stopDualMode() async {
    await Future.wait([stopBroadcasting(), stopDiscovery()]);
  }

  // --- 接收端逻辑 (发现) ---

  Future<void> startDiscovery() async {
    try {
      state = state.copyWith(error: null, discoveredServices: []);

      _discovery = BonsoirDiscovery(type: _serviceType);
      await _discovery!.initialize();

      _discovery!.eventStream!.listen((event) async {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          // 发现服务，尝试解析
          await _discovery!.serviceResolver.resolveService(event.service);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          // 解析成功，获取设备的 IP 地址
          final service = event.service;
          final currentIp = service.attributes['ip'];

          // 使用设备的 IP 地址进行去重，防止同一台设备因为重启改变了服务名称（UUID后缀）
          // 导致被识别为多个设备，从而在 UI 上堆叠并引发崩溃
          final existingIndex = state.discoveredServices.indexWhere(
            (s) => s.attributes['ip'] == currentIp,
          );

          if (existingIndex != -1) {
            // 如果已存在该 IP 的设备，可能是重启了服务，用新服务实例替换旧的
            final updatedServices = List<BonsoirService>.from(
              state.discoveredServices,
            );
            updatedServices[existingIndex] = service;
            state = state.copyWith(discoveredServices: updatedServices);
          } else {
            // 全新的设备 IP，添加到列表
            state = state.copyWith(
              discoveredServices: [...state.discoveredServices, service],
            );
          }
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          // 服务丢失，移除
          final service = event.service;
          state = state.copyWith(
            discoveredServices: state.discoveredServices
                .where((s) => s.name != service.name)
                .toList(),
          );
        }
      });

      await _discovery!.start();
      state = state.copyWith(isDiscovering: true);
    } catch (e) {
      state = state.copyWith(
        error: t.lan_transfer.search_failed(e: e.toString()),
      );
      await stopDiscovery();
    }
  }

  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
    state = state.copyWith(isDiscovering: false, discoveredServices: []);
  }

  // --- 辅助方法：快速寻找真正连通的局域网 IP ---

  /// 对传递过来的多个可能存在的局域网 IP (由逗号分隔的主机字符串) 进行测速探路
  /// 选出能够正常响应 GET /info 测速连接的一个 IP 地址
  Future<String?> _findReachableIp(String hostStr, int port) async {
    final hosts = hostStr.split(',');
    if (hosts.isEmpty || hosts.first == 'Unknown') return null;

    for (final host in hosts) {
      try {
        final response = await http
            .get(Uri.parse('http://$host:$port/info'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) return host;
      } catch (_) {
        // 如果测不通或者超时，安静地跳过去测试下一个节点
      }
    }
    return null;
  }

  // --- 发送文件 (Push 模式) ---

  /// 主动发送文件给指定设备 (Push)
  Future<bool> sendFileTo(String hostStr, int port) async {
    try {
      // 提早进行快速探路 PING，找出现阶段能通过路由器的那个 IP，防止阻塞死等
      final reachableHost = await _findReachableIp(hostStr, port);
      if (reachableHost == null) {
        throw TimeoutException(t.lan_transfer.no_reachable_ip);
      }

      final exportService = ref.read(exportServiceProvider);
      // 1. 生成 Zip，不调用系统分享 (share: true 表示生成临时文件不弹窗)
      final zipFile = await exportService.exportToZip(share: true);
      if (zipFile == null) throw Exception(t.settings.backup_create_failed);

      // 2. 读取文件字节
      final bytes = await zipFile.readAsBytes();

      final uri = Uri.parse('http://$reachableHost:$port/upload');
      final response = await http
          .post(
            uri,
            body: bytes,
            headers: {
              'Content-Type': 'application/octet-stream',
              'Content-Disposition':
                  'attachment; filename="${path.basename(zipFile.path)}"',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          t.lan_transfer.send_failed(e: 'Status: ${response.statusCode}'),
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        state = state.copyWith(error: t.lan_transfer.connect_timeout);
      } else {
        state = state.copyWith(
          error: t.lan_transfer.send_failed(e: e.toString()),
        );
      }
      return false;
    }
  }

  // --- 下载文件 (Pull 模式 - 用于扫码或备用) ---

  Future<File?> downloadFile(String hostStr, int port) async {
    try {
      final reachableHost = await _findReachableIp(hostStr, port);
      if (reachableHost == null) {
        throw TimeoutException(t.lan_transfer.no_reachable_ip);
      }

      final response = await http
          .get(Uri.parse('http://$reachableHost:$port/download'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final contentDisposition = response.headers['content-disposition'];
        String fileName =
            'received_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

        if (contentDisposition != null) {
          final match = RegExp(
            r'filename="?([^"]+)"?',
          ).firstMatch(contentDisposition);
          if (match != null) {
            fileName = match.group(1)!;
          }
        }

        final file = File(path.join(dir.path, fileName));
        await file.writeAsBytes(response.bodyBytes);

        // 同样更新接收状态
        state = state.copyWith(lastReceivedFile: file);

        return file;
      } else {
        throw Exception(
          t.lan_transfer.receive_failed(e: 'Status: ${response.statusCode}'),
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        state = state.copyWith(error: t.lan_transfer.connect_timeout);
      } else {
        state = state.copyWith(
          error: t.lan_transfer.receive_failed(e: e.toString()),
        );
      }
      return null;
    }
  }

  // 通过 URL 下载 (用于扫码)
  Future<File?> downloadFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return downloadFile(uri.host, uri.port);
    } catch (e) {
      state = state.copyWith(
        error: t.lan_transfer.invalid_link(e: e.toString()),
      );
      return null;
    }
  }
}

final lanTransferServiceProvider =
    NotifierProvider<LanTransferNotifier, LanTransferState>(() {
      return LanTransferNotifier();
    });
