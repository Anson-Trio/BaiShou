import 'dart:convert' as convert;

import 'package:baishou/agent/database/agent_tables.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_database.g.dart';

/// Agent 专属数据库
/// 独立于主数据库（app_database），存储 Agent 的会话、消息和 Part
@DriftDatabase(tables: [AgentSessions, AgentMessages, AgentParts])
class AgentDatabase extends _$AgentDatabase {
  AgentDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2: 三表重构
            // 1. 创建新的 AgentParts 表
            await m.createTable(agentParts);

            // 2. AgentMessages: 添加新列
            await m.addColumn(agentMessages, agentMessages.isSummary);
            await m.addColumn(agentMessages, agentMessages.providerId);
            await m.addColumn(
                agentMessages, agentMessages.modelId);

            // 3. 迁移旧消息的 content → TextPart
            final rows = await customSelect(
              'SELECT id, session_id, content, tool_calls FROM agent_messages',
            ).get();

            for (final row in rows) {
              final msgId = row.read<String>('id');
              final sessionId = row.read<String>('session_id');
              final content = row.readNullable<String>('content');
              final toolCallsJson =
                  row.readNullable<String>('tool_calls');

              // 文本内容 → TextPart
              if (content != null && content.isNotEmpty) {
                await into(agentParts).insert(AgentPartsCompanion.insert(
                  id: '${msgId}_text',
                  messageId: msgId,
                  sessionId: sessionId,
                  type: 'text',
                  data: convert.jsonEncode({'text': content}),
                ));
              }

              // 工具调用 → ToolPart
              if (toolCallsJson != null && toolCallsJson.isNotEmpty) {
                try {
                  final calls =
                      convert.jsonDecode(toolCallsJson) as List;
                  for (var i = 0; i < calls.length; i++) {
                    final tc = calls[i] as Map<String, dynamic>;
                    await into(agentParts)
                        .insert(AgentPartsCompanion.insert(
                      id: '${msgId}_tool_$i',
                      messageId: msgId,
                      sessionId: sessionId,
                      type: 'tool',
                      data: convert.jsonEncode({
                        'callId': tc['id'] ?? 'call_$i',
                        'toolName': tc['name'] ?? 'unknown',
                        'status': 'completed',
                        'input': tc['arguments'] ?? {},
                      }),
                    ));
                  }
                } catch (_) {}
              }
            }

            // 旧列（content, tool_calls, tool_call_id）保留不删
            // SQLite < 3.35 不支持 DROP COLUMN，新代码不再使用它们
          }
        },
      );
}

/// 打开 Agent 数据库连接
/// 数据库存放在：BaiShou_Root/.baishou/agent.sqlite
QueryExecutor _openAgentConnection(StoragePathService pathService) {
  return driftDatabase(
    name: 'agent',
    native: DriftNativeOptions(
      databasePath: () async {
        final sysDir = await pathService.getGlobalRegistryDirectory();
        return p.join(sysDir.path, 'agent.sqlite');
      },
    ),
  );
}

/// Riverpod Provider
@Riverpod(keepAlive: true)
AgentDatabase agentDatabase(Ref ref) {
  final pathService = ref.watch(storagePathServiceProvider);
  return AgentDatabase(_openAgentConnection(pathService));
}
