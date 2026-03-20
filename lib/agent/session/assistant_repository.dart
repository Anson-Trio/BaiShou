/// 助手数据仓库
/// 负责 AI 助手的 CRUD 操作，独立于 AgentDatabase

import 'package:baishou/agent/database/agent_database.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assistant_repository.g.dart';

class AssistantRepository {
  final AgentDatabase _db;

  AssistantRepository(this._db);

  // ─── 查询 ──────────────────────────────────────────

  /// 获取所有助手（按创建时间降序）
  Future<List<AgentAssistant>> getAll() {
    return (_db.select(_db.agentAssistants)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 获取单个助手
  Future<AgentAssistant?> get(String id) {
    return (_db.select(_db.agentAssistants)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 获取默认助手
  Future<AgentAssistant?> getDefault() {
    return (_db.select(_db.agentAssistants)
          ..where((t) => t.isDefault.equals(true)))
        .getSingleOrNull();
  }

  /// 监听助手列表变更
  Stream<List<AgentAssistant>> watchAll() {
    return (_db.select(_db.agentAssistants)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // ─── 写入 ──────────────────────────────────────────

  /// 插入助手
  Future<void> insert(AgentAssistantsCompanion entry) {
    return _db.into(_db.agentAssistants).insert(entry);
  }

  /// 更新助手
  Future<void> updateAssistant(AgentAssistantsCompanion entry) {
    return (_db.update(_db.agentAssistants)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  /// 删除助手
  Future<void> deleteById(String id) {
    return (_db.delete(_db.agentAssistants)..where((t) => t.id.equals(id)))
        .go();
  }

  // ─── 默认助手管理 ──────────────────────────────────

  /// 清除所有助手的默认标记
  Future<void> clearDefault() {
    return (_db.update(_db.agentAssistants)
          ..where((t) => t.isDefault.equals(true)))
        .write(const AgentAssistantsCompanion(isDefault: Value(false)));
  }

  /// 设置指定助手为默认
  Future<void> setDefault(String id) async {
    await clearDefault();
    await (_db.update(_db.agentAssistants)..where((t) => t.id.equals(id)))
        .write(const AgentAssistantsCompanion(isDefault: Value(true)));
  }
}

@Riverpod(keepAlive: true)
AssistantRepository assistantRepository(Ref ref) {
  final db = ref.watch(agentDatabaseProvider);
  return AssistantRepository(db);
}
