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

import 'package:baishou/core/storage/data_archive_manager.dart';
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

  bool _isDisposed = false;

  // 新增防抖和资源管理变量
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  Timer? _teardownTimer;
  int _activeClients = 0;
  bool _isRestarting = false;

  @override
  LanTransferState build() {
    ref.onDispose(() {
      _isDisposed = true;
    });
    return const LanTransferState();
  }

  // --- 发送端逻辑 (广播 & 服务) ---

  /// 启动广播服务
  /// 仅启动 HTTP 服务器和 mDNS 广播，不自动导出文件
  Future<void> startBroadcasting() async {
    if (_broadcast != null) return;
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
      // 严格清洗：只保留字母、数字和中文字符，彻底移除空格和特殊符号，防止 Windows mDNS 线程解析异常
      String rawNickname = userProfile.nickname;
      String safeNickname = rawNickname.replaceAll(
        RegExp(r'[^\w\u4e00-\u9fa5]'),
        '',
      );

      if (safeNickname.isEmpty) safeNickname = 'User';
      if (safeNickname.length > 10) {
        safeNickname = safeNickname.substring(0, 10);
      }

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
          'nickname': safeNickname, // 统一使用清洗后的昵称，不再保留原始可能含空格的昵称
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

    // GET /avatar: 返回用户的头像流供雷达展示
    router.get('/avatar', (Request request) async {
      final avatarPath = userProfile.avatarPath;
      if (avatarPath != null) {
        final file = File(avatarPath);
        if (file.existsSync()) {
          final ext = path.extension(avatarPath).replaceAll('.', '');
          return Response.ok(
            file.openRead(),
            headers: {'Content-Type': 'image/$ext'},
          );
        }
      }
      return Response.notFound('Avatar not found');
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

  Future<void>? _pendingModeChange;

  /// 同步锁执行，防止连续进出页面引发的 Bonsoir 底层并发崩溃
  Future<void> _executeWithLock(Future<void> Function() action) async {
    while (_pendingModeChange != null) {
      await _pendingModeChange;
    }
    final completer = Completer<void>();
    _pendingModeChange = completer.future;

    try {
      await action();
    } finally {
      completer.complete();
      if (_pendingModeChange == completer.future) {
        _pendingModeChange = null;
      }
    }
  }

  /// 同时启动广播和发现服务
  /// 进入局域网传输页面时调用
  Future<void> startDualMode() async {
    _activeClients++;
    if (_teardownTimer != null && _teardownTimer!.isActive) {
      _teardownTimer!.cancel();
      _teardownTimer = null;
    }

    if (state.isBroadcasting && state.isDiscovering) {
      return;
    }

    await _executeWithLock(() async {
      if (_isDisposed) return;
      // 串行启动，避免 Windows mDNS 多线程并发抢注底层 UDP 端口导致的内核崩溃
      if (!state.isBroadcasting) await startBroadcasting();
      if (!state.isDiscovering) await startDiscovery();
    });
  }

  Future<void> stopDualMode() async {
    _activeClients--;
    if (_activeClients > 0) return;

    // 延迟 2 秒真正销毁服务，避免用户快速进出页面时的底层插件并发死锁
    _teardownTimer?.cancel();
    _teardownTimer = Timer(const Duration(seconds: 2), () async {
      if (_activeClients <= 0) {
        await _executeWithLock(() async {
          // 串行停止，保证资源完全释放顺序
          await stopBroadcasting();
          await stopDiscovery();
        });
      }
    });
  }

  /// 安全重启双向模式（带防崩延迟）
  /// 在用户点击刷新时调用。立即的 stop+start 极易引发 Windows 上的 bonsoir c++ 插件发生指针异常或 Socket 抢占崩溃。
  Future<void> restartDualMode() async {
    if (_isRestarting) return;
    _isRestarting = true;
    try {
      _teardownTimer?.cancel();

      await _executeWithLock(() async {
        await stopBroadcasting();
        await stopDiscovery();
      });
      
      // 强制休眠 2 秒，等待底层完全释放端口和句柄，彻底解决重入空指针
      await Future.delayed(const Duration(milliseconds: 2000));
      if (_isDisposed) return;

      await _executeWithLock(() async {
        if (_activeClients > 0) {
          if (!state.isBroadcasting) await startBroadcasting();
          if (!state.isDiscovering) await startDiscovery();
        }
      });
    } finally {
      _isRestarting = false;
    }
  }

  // --- 接收端逻辑 (发现) ---

  Future<void> startDiscovery() async {
    if (_discovery != null) return;
    try {
      state = state.copyWith(error: null, discoveredServices: []);

      _discovery = BonsoirDiscovery(type: _serviceType);
      await _discovery!.initialize();

      final Set<String> _resolvingServices = {};

      _discoverySubscription = _discovery!.eventStream!.listen((event) async {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          // 发现服务，尝试解析。
          final serviceName = event.service.name;
          final alreadyDiscovered = state.discoveredServices.any(
            (s) => s.name == serviceName,
          );
          
          // 加锁防止同一个未识别的服务被并发 resolve 多次（Windows Bonsoir 致命崩溃点）
          if (!alreadyDiscovered && !_resolvingServices.contains(serviceName)) {
            _resolvingServices.add(serviceName);
            try {
              await _discovery!.serviceResolver.resolveService(event.service);
            } catch (_) {
              _resolvingServices.remove(serviceName); // allow retry
            }
          }
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          _resolvingServices.remove(event.service.name);
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
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
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

      // 统一调用由 DataArchiveManager 提供的数据导出总入口，摒除各个服务直接访问底层导出机制
      final dataArchiveManager = ref.read(dataArchiveManagerProvider.notifier);
      // 1. 生成临时缓存的存档 Zip，专门为局域网双端快传优化
      final zipFile = await dataArchiveManager.exportToTempFile();
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
}

final lanTransferServiceProvider =
    NotifierProvider<LanTransferNotifier, LanTransferState>(() {
      return LanTransferNotifier();
    });
