/// Agent 会话管理器
/// 负责会话、消息、Part 的 CRUD 操作（三表架构）

import 'dart:convert';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/message_part.dart';
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
          title: Value(title ?? t.agent.sessions.default_title),
        ));
    return id;
  }

  /// 伴侣模式专用 session ID
  static const companionSessionId = '__companion__';

  /// 创建伴侣模式专用会话（固定 ID，全局唯一）
  Future<void> createCompanionSession({
    required String vaultName,
    required String providerId,
    required String modelId,
  }) async {
    await _db.into(_db.agentSessions).insert(AgentSessionsCompanion.insert(
          id: companionSessionId,
          vaultName: vaultName,
          providerId: providerId,
          modelId: modelId,
          title: Value(t.agent.sessions.companion_session_title),
        ));
  }

  /// 获取所有会话（按 isPinned 降序，再按最后活跃时间降序）
  Future<List<AgentSession>> getSessions() async {
    return (_db.select(_db.agentSessions)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
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
    await (_db.update(_db.agentSessions)..where((t) => t.id.equals(id)))
        .write(AgentSessionsCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 重命名会话（与 updateSessionTitle 别名）
  Future<void> renameSession(String id, String newName) async {
    await updateSessionTitle(id, newName);
  }

  /// 切换会话置顶状态
  Future<void> togglePinSession(String id, bool isPinned) async {
    await (_db.update(_db.agentSessions)..where((t) => t.id.equals(id)))
        .write(AgentSessionsCompanion(
      isPinned: Value(isPinned),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 更新会话专属 System Prompt
  Future<void> updateSystemPrompt(String id, String? prompt) async {
    await (_db.update(_db.agentSessions)..where((t) => t.id.equals(id)))
        .write(AgentSessionsCompanion(
      systemPrompt: Value(prompt),
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

  /// 删除会话（级联删除 Parts → Messages）
  Future<void> deleteSession(String id) async {
    await (_db.delete(_db.agentParts)
          ..where((t) => t.sessionId.equals(id)))
        .go();
    await (_db.delete(_db.agentMessages)
          ..where((t) => t.sessionId.equals(id)))
        .go();
    await (_db.delete(_db.agentSessions)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// 累加会话的 token 用量和费用
  Future<void> addUsage({
    required String sessionId,
    required int inputTokens,
    required int outputTokens,
    required int costMicros,
  }) async {
    final session = await getSession(sessionId);
    if (session == null) return;

    await (_db.update(_db.agentSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(AgentSessionsCompanion(
      totalInputTokens:
          Value(session.totalInputTokens + inputTokens),
      totalOutputTokens:
          Value(session.totalOutputTokens + outputTokens),
      totalCostMicros:
          Value(session.totalCostMicros + costMicros),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // ─── 消息 + Part CRUD ─────────────────────────────────────

  /// 添加消息及其 Parts（三表写入）
  ///
  /// [parts] 是消息的细粒度内容。如果为空，会根据 msg 自动创建 Parts。
  Future<void> addMessage(
    String sessionId,
    ChatMessage msg, {
    List<MessagePart>? parts,
    String? providerId,
    String? modelId,
    bool isSummary = false,
  }) async {
    final maxOrder = await _getMaxOrderIndex(sessionId);

    // 1. 写 Message
    await _db.into(_db.agentMessages).insert(
          AgentMessagesCompanion.insert(
            id: msg.id,
            sessionId: sessionId,
            role: msg.role.name,
            isSummary: Value(isSummary),
            providerId: Value(providerId),
            modelId: Value(modelId),
            orderIndex: maxOrder + 1,
          ),
        );

    // 2. 写 Parts
    if (parts != null && parts.isNotEmpty) {
      await _writeParts(parts);
    } else {
      // 自动从 ChatMessage 推断 Parts
      await _autoCreateParts(sessionId, msg);
    }

    await touchSession(sessionId);

    // 同步到 FTS5 索引
    await _syncToFts(sessionId, msg);
  }

  /// 批量添加消息（每条自动创建 Parts）
  Future<void> addMessages(
    String sessionId,
    List<ChatMessage> msgs, {
    String? providerId,
    String? modelId,
  }) async {
    var order = await _getMaxOrderIndex(sessionId);

    for (final msg in msgs) {
      order++;

      // 写 Message
      await _db.into(_db.agentMessages).insert(
            AgentMessagesCompanion.insert(
              id: msg.id,
              sessionId: sessionId,
              role: msg.role.name,
              providerId: Value(
                msg.role == MessageRole.assistant ? providerId : null,
              ),
              modelId: Value(
                msg.role == MessageRole.assistant ? modelId : null,
              ),
              orderIndex: order,
            ),
          );

      // 自动创建 Parts
      await _autoCreateParts(sessionId, msg);
    }

    await touchSession(sessionId);

    // 批量同步到 FTS5 索引
    for (final msg in msgs) {
      await _syncToFts(sessionId, msg);
    }
  }

  /// 获取会话的所有消息 + Parts（重建为 ChatMessage）
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    // 按顺序取消息
    final msgRows = await (_db.select(_db.agentMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
        .get();

    if (msgRows.isEmpty) return [];

    // 一次性取所有 Parts
    final partRows = await (_db.select(_db.agentParts)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();

    // 按 messageId 分组
    final partsByMsg = <String, List<AgentPart>>{};
    for (final part in partRows) {
      partsByMsg.putIfAbsent(part.messageId, () => []).add(part);
    }

    // 重建 ChatMessage
    return msgRows.map((row) {
      final parts = partsByMsg[row.id] ?? [];
      return _rebuildMessage(row, parts);
    }).toList();
  }

  /// 获取消息的 Parts
  Future<List<MessagePart>> getPartsForMessage(String messageId) async {
    final rows = await (_db.select(_db.agentParts)
          ..where((t) => t.messageId.equals(messageId)))
        .get();

    return rows.map(_rowToPart).toList();
  }

  /// 更新单个 Part（用于 prune/compaction）
  Future<void> updatePart(MessagePart part) async {
    await (_db.update(_db.agentParts)
          ..where((t) => t.id.equals(part.id)))
        .write(AgentPartsCompanion(
      data: Value(jsonEncode(part.toDataMap())),
    ));
  }

  /// 清空会话消息和 Parts
  Future<void> clearMessages(String sessionId) async {
    // 同时清理 FTS 索引中该会话的记录
    await _db.customStatement(
      'DELETE FROM agent_messages_fts WHERE session_id = ?',
      [sessionId],
    );
    await (_db.delete(_db.agentParts)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
    await (_db.delete(_db.agentMessages)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }

  // ─── FTS5 全文搜索 ──────────────────────────────────────────

  /// 同步消息文本到 FTS5 索引
  Future<void> _syncToFts(String sessionId, ChatMessage msg) async {
    // 仅索引 user 和 assistant 的文本消息
    if (msg.role != MessageRole.user && msg.role != MessageRole.assistant) {
      return;
    }
    final text = msg.content;
    if (text == null || text.trim().isEmpty) return;

    try {
      await _db.insertFtsRecord(
        messageId: msg.id,
        sessionId: sessionId,
        role: msg.role.name,
        content: text,
      );
    } catch (e) {
      // FTS5 可能不可用（例如某些平台不支持），静默失败
    }
  }

  /// 跨会话全文搜索消息
  Future<List<Map<String, dynamic>>> searchMessages(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      return await _db.searchFts(query, limit: limit);
    } catch (e) {
      // FTS5 不可用时返回空
      return [];
    }
  }

  // ─── 内部工具方法 ─────────────────────────────────────────

  Future<int> _getMaxOrderIndex(String sessionId) async {
    final result = await (_db.selectOnly(_db.agentMessages)
          ..where(_db.agentMessages.sessionId.equals(sessionId))
          ..addColumns([_db.agentMessages.orderIndex.max()]))
        .getSingleOrNull();

    return result?.read(_db.agentMessages.orderIndex.max()) ?? 0;
  }

  /// 从 ChatMessage 自动推断并创建 Parts
  Future<void> _autoCreateParts(
    String sessionId,
    ChatMessage msg,
  ) async {
    final parts = <MessagePart>[];
    int partIndex = 0;

    // 文本内容 → TextPart
    if (msg.content != null && msg.content!.isNotEmpty) {
      parts.add(TextPart(
        id: '${msg.id}_p${partIndex++}',
        messageId: msg.id,
        sessionId: sessionId,
        text: msg.content!,
      ));
    }

    // 工具调用 → ToolPart
    if (msg.toolCalls != null) {
      for (final tc in msg.toolCalls!) {
        parts.add(ToolPart(
          id: '${msg.id}_p${partIndex++}',
          messageId: msg.id,
          sessionId: sessionId,
          callId: tc.id,
          toolName: tc.name,
          status: ToolPartStatus.completed,
          input: tc.arguments,
        ));
      }
    }

    if (parts.isNotEmpty) {
      await _writeParts(parts);
    }
  }

  /// 批量写入 Parts
  Future<void> _writeParts(List<MessagePart> parts) async {
    await _db.batch((batch) {
      for (final part in parts) {
        batch.insert(
          _db.agentParts,
          AgentPartsCompanion.insert(
            id: part.id,
            messageId: part.messageId,
            sessionId: part.sessionId,
            type: part.type.name,
            data: jsonEncode(part.toDataMap()),
          ),
        );
      }
    });
  }

  /// 从 DB 行反序列化 Part
  MessagePart _rowToPart(AgentPart row) {
    return MessagePart.fromRow(
      id: row.id,
      messageId: row.messageId,
      sessionId: row.sessionId,
      type: row.type,
      dataJson: row.data,
    );
  }

  /// 从 Message + Parts 重建 ChatMessage
  ChatMessage _rebuildMessage(AgentMessage row, List<AgentPart> partRows) {
    String? content;
    List<ToolCall>? toolCalls;
    String? toolCallId;

    for (final partRow in partRows) {
      final part = _rowToPart(partRow);
      switch (part) {
        case TextPart(:final text):
          content = (content ?? '') + text;
        case ToolPart(:final callId, :final toolName, :final input):
          toolCalls ??= [];
          toolCalls.add(ToolCall(
            id: callId,
            name: toolName,
            arguments: input,
          ));
          // tool result 消息的 toolCallId 来自 ToolPart
          if (row.role == 'tool') {
            toolCallId = callId;
          }
        case StepFinishPart():
        case CompactionPart():
          break; // 元数据 Part 不影响 ChatMessage 重建
      }
    }

    return ChatMessage(
      id: row.id,
      role: MessageRole.values.byName(row.role),
      content: content,
      toolCalls: toolCalls,
      toolCallId: toolCallId,
      timestamp: row.createdAt,
    );
  }
}

@Riverpod(keepAlive: true)
SessionManager sessionManager(Ref ref) {
  final db = ref.watch(agentDatabaseProvider);
  return SessionManager(db);
}
