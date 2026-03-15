/// Agent 会话管理器
/// 负责会话和消息的 CRUD 操作

import 'dart:convert';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/database/agent_tables.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'session_manager.g.dart';

class SessionManager {
  final AgentDatabase _db;
  static const _uuid = Uuid();

  SessionManager(this._db);

  // ─── 会话 CRUD ──────────────────────────────────────────

  /// 创建新会话
  Future<String> createSession({
    required String vaultName,
    required String providerId,
    required String modelId,
    String? title,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.agentSessions).insert(AgentSessionsCompanion.insert(
          id: id,
          vaultName: vaultName,
          providerId: providerId,
          modelId: modelId,
          title: Value(title ?? '新对话'),
        ));
    return id;
  }

  /// 获取所有会话（按最后活跃时间降序）
  Future<List<AgentSession>> getSessions() async {
    return (_db.select(_db.agentSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 获取单个会话
  Future<AgentSession?> getSession(String id) async {
    return (_db.select(_db.agentSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 更新会话标题
  Future<void> updateSessionTitle(String id, String title) async {
    await (_db.update(_db.agentSessions)
          ..where((t) => t.id.equals(id)))
        .write(AgentSessionsCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 更新会话活跃时间
  Future<void> touchSession(String id) async {
    await (_db.update(_db.agentSessions)
          ..where((t) => t.id.equals(id)))
        .write(AgentSessionsCompanion(
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 删除会话（级联删除消息）
  Future<void> deleteSession(String id) async {
    await (_db.delete(_db.agentMessages)
          ..where((t) => t.sessionId.equals(id)))
        .go();
    await (_db.delete(_db.agentSessions)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // ─── 消息 CRUD ──────────────────────────────────────────

  /// 添加消息到会话
  Future<void> addMessage(String sessionId, ChatMessage msg) async {
    // 获取当前最大 orderIndex
    final maxOrder = await _getMaxOrderIndex(sessionId);

    await _db.into(_db.agentMessages).insert(AgentMessagesCompanion.insert(
          id: msg.id,
          sessionId: sessionId,
          role: msg.role.name,
          content: Value(msg.content),
          toolCalls: Value(msg.toolCalls != null
              ? jsonEncode(msg.toolCalls!.map((t) => t.toMap()).toList())
              : null),
          toolCallId: Value(msg.toolCallId),
          orderIndex: maxOrder + 1,
        ));

    await touchSession(sessionId);
  }

  /// 批量添加消息
  Future<void> addMessages(String sessionId, List<ChatMessage> msgs) async {
    var order = await _getMaxOrderIndex(sessionId);

    await _db.batch((batch) {
      for (final msg in msgs) {
        order++;
        batch.insert(
          _db.agentMessages,
          AgentMessagesCompanion.insert(
            id: msg.id,
            sessionId: sessionId,
            role: msg.role.name,
            content: Value(msg.content),
            toolCalls: Value(msg.toolCalls != null
                ? jsonEncode(msg.toolCalls!.map((t) => t.toMap()).toList())
                : null),
            toolCallId: Value(msg.toolCallId),
            orderIndex: order,
          ),
        );
      }
    });

    await touchSession(sessionId);
  }

  /// 获取会话的所有消息（按顺序）
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final rows = await (_db.select(_db.agentMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
        .get();

    return rows.map(_rowToMessage).toList();
  }

  /// 清空会话消息
  Future<void> clearMessages(String sessionId) async {
    await (_db.delete(_db.agentMessages)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }

  // ─── 内部工具方法 ─────────────────────────────────────────

  Future<int> _getMaxOrderIndex(String sessionId) async {
    final result = await (_db.selectOnly(_db.agentMessages)
          ..where(_db.agentMessages.sessionId.equals(sessionId))
          ..addColumns([_db.agentMessages.orderIndex.max()]))
        .getSingleOrNull();

    return result?.read(_db.agentMessages.orderIndex.max()) ?? 0;
  }

  ChatMessage _rowToMessage(AgentMessage row) {
    List<ToolCall>? toolCalls;
    if (row.toolCalls != null) {
      final list = jsonDecode(row.toolCalls!) as List;
      toolCalls = list
          .map((t) => ToolCall.fromMap(t as Map<String, dynamic>))
          .toList();
    }

    return ChatMessage(
      id: row.id,
      role: MessageRole.values.byName(row.role),
      content: row.content,
      toolCalls: toolCalls,
      toolCallId: row.toolCallId,
      timestamp: row.createdAt,
    );
  }
}

@Riverpod(keepAlive: true)
SessionManager sessionManager(Ref ref) {
  final db = ref.watch(agentDatabaseProvider);
  return SessionManager(db);
}
