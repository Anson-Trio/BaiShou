import 'dart:convert';
import 'dart:io';

import 'package:baishou/core/providers/shared_preferences_provider.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:sqlite_vector/sqlite_vector.dart';

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('baishou_test_');
    SharedPreferences.setMockInitialValues({
      'custom_storage_root': tempDir.path,
    });
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (e) {
        debugPrint('Ignored file lock during teardown: $e');
      }
    }
  });

  test(
    'VaultService initializes default Personal vault when registry is empty',
    () async {
      final vaultService = container.read(vaultServiceProvider.notifier);

      // First read triggers build() -> _initRegistry()
      final activeVault = await container.read(vaultServiceProvider.future);

      expect(activeVault, isNotNull);
      expect(activeVault!.name, 'Personal');

      final allVaults = vaultService.getAllVaults();
      expect(allVaults.length, 1);
      expect(allVaults.first.name, 'Personal');

      // Check if registry JSON is created
      final globalSysDir = await container
          .read(storagePathServiceProvider)
          .getGlobalRegistryDirectory();
      final registryFile = File(
        p.join(globalSysDir.path, 'vault_registry.json'),
      );
      expect(registryFile.existsSync(), isTrue);

      final content = jsonDecode(registryFile.readAsStringSync()) as List;
      expect(content.length, 1);
      expect(content[0]['name'], 'Personal');
    },
  );

  test(
    'VaultService migrates global databases to Personal vault on first launch',
    () async {
      final pathService = container.read(storagePathServiceProvider);
      final globalSysDir = await pathService.getGlobalRegistryDirectory();

      // Mock existing global databases
      final oldBaishouDb = File(p.join(globalSysDir.path, 'baishou.sqlite'));
      final oldAgentDb = File(p.join(globalSysDir.path, 'agent.sqlite'));
      final oldBaishouWal = File(
        p.join(globalSysDir.path, 'baishou.sqlite-wal'),
      );

      oldBaishouDb.writeAsStringSync('dummy baishou db');
      oldAgentDb.writeAsStringSync('dummy agent db');
      oldBaishouWal.writeAsStringSync('dummy wal');

      // Initialize service
      final activeVault = await container.read(vaultServiceProvider.future);

      expect(activeVault, isNotNull);
      expect(activeVault!.name, 'Personal');

      // Verify migration
      final personalSysDir = await pathService.getVaultSystemDirectory(
        'Personal',
      );

      final newBaishouDb = File(p.join(personalSysDir.path, 'baishou.sqlite'));
      final newAgentDb = File(p.join(personalSysDir.path, 'agent.sqlite'));
      final newBaishouWal = File(
        p.join(personalSysDir.path, 'baishou.sqlite-wal'),
      );

      expect(newBaishouDb.existsSync(), isTrue);
      expect(newAgentDb.existsSync(), isTrue);
      expect(newBaishouWal.existsSync(), isTrue);

      // Verify old ones are removed (renamed)
      expect(oldBaishouDb.existsSync(), isFalse);
      expect(oldAgentDb.existsSync(), isFalse);
      expect(oldBaishouWal.existsSync(), isFalse);
    },
  );

  test(
    'VaultService can switch to a new workspace and create directories',
    () async {
      final vaultService = container.read(vaultServiceProvider.notifier);
      await container.read(vaultServiceProvider.future); // Initialize first

      // Switch to new vault
      await vaultService.switchVault('Work');

      final activeVault = container.read(vaultServiceProvider).value;
      expect(activeVault, isNotNull);
      expect(activeVault!.name, 'Work');

      final allVaults = vaultService.getAllVaults();
      expect(allVaults.length, 2);

      // Verify folders were created
      final pathService = container.read(storagePathServiceProvider);
      final workDir = await pathService.getVaultDirectory('Work');
      final workSysDir = await pathService.getVaultSystemDirectory('Work');
      final workJournalsDir = await pathService.getJournalsBaseDirectory(
        'Work',
      );

      expect(workDir.existsSync(), isTrue);
      expect(workSysDir.existsSync(), isTrue);
      expect(workJournalsDir.existsSync(), isTrue);
    },
  );

  test(
    'VaultService updates lastAccessedAt when switching to existing workspace',
    () async {
      final vaultService = container.read(vaultServiceProvider.notifier);
      await container.read(vaultServiceProvider.future); // Init Personal

      await vaultService.switchVault('Work'); // Create Work

      final personalVaultBefore = vaultService.getAllVaults().firstWhere(
        (v) => v.name == 'Personal',
      );
      final workVaultBefore = vaultService.getAllVaults().firstWhere(
        (v) => v.name == 'Work',
      );

      // Wait a bit to ensure time difference
      await Future.delayed(const Duration(milliseconds: 50));

      // Switch back to Personal
      await vaultService.switchVault('Personal');

      final activeVault = container.read(vaultServiceProvider).value;
      expect(activeVault!.name, 'Personal');

      final personalVaultAfter = vaultService.getAllVaults().firstWhere(
        (v) => v.name == 'Personal',
      );
      final workVaultAfter = vaultService.getAllVaults().firstWhere(
        (v) => v.name == 'Work',
      );

      expect(
        personalVaultAfter.lastAccessedAt.isAfter(
          personalVaultBefore.lastAccessedAt,
        ),
        isTrue,
      );
      expect(
        workVaultAfter.lastAccessedAt,
        equals(workVaultBefore.lastAccessedAt),
      );
    },
  );

  test('VaultService recovers from corrupted vault_registry.json', () async {
    final pathService = container.read(storagePathServiceProvider);
    final globalSysDir = await pathService.getGlobalRegistryDirectory();
    final registryFile = File(p.join(globalSysDir.path, 'vault_registry.json'));

    // Write corrupted JSON
    registryFile.writeAsStringSync('{ invalid json ];');

    final activeVault = await container.read(vaultServiceProvider.future);

    // Should recover gracefully and create Personal vault
    expect(activeVault, isNotNull);
    expect(activeVault!.name, 'Personal');

    // The invalid file should be overwritten with valid JSON
    final content = jsonDecode(registryFile.readAsStringSync()) as List;
    expect(content.length, 1);
    expect(content[0]['name'], 'Personal');
  });

  test(
    'VaultService handles partial migration when only some legacy databases exist',
    () async {
      final pathService = container.read(storagePathServiceProvider);
      final globalSysDir = await pathService.getGlobalRegistryDirectory();

      // Mock ONLY baishou.sqlite, no agent.sqlite
      final oldBaishouDb = File(p.join(globalSysDir.path, 'baishou.sqlite'));
      oldBaishouDb.writeAsStringSync('dummy baishou db');

      // Initialize service
      await container.read(vaultServiceProvider.future);

      // Verify migration
      final personalSysDir = await pathService.getVaultSystemDirectory(
        'Personal',
      );
      final newBaishouDb = File(p.join(personalSysDir.path, 'baishou.sqlite'));

      // baishou.sqlite should be moved
      expect(newBaishouDb.existsSync(), isTrue);
      expect(oldBaishouDb.existsSync(), isFalse);

      // agent.sqlite shouldn't crash it
      final newAgentDb = File(p.join(personalSysDir.path, 'agent.sqlite'));
      expect(newAgentDb.existsSync(), isFalse);
    },
  );

  test('VaultService.getAllVaults returns an unmodifiable list', () async {
    final vaultService = container.read(vaultServiceProvider.notifier);
    await container.read(vaultServiceProvider.future);

    final allVaults = vaultService.getAllVaults();

    expect(
      () => allVaults.add(
        VaultInfo(
          name: 'Hacked',
          path: '/hacked',
          createdAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test(
    'VaultService vector migration edge case: intact sqlite-vec and fts5 data after physical move',
    () async {
      final pathService = container.read(storagePathServiceProvider);
      final globalSysDir = await pathService.getGlobalRegistryDirectory();

      // 1. Create a REAL global agent database before VaultService initializes
      final oldDbFile = File(p.join(globalSysDir.path, 'agent.sqlite'));

      // We must manually load the sqlite-vector extension BEFORE opening the DB
      // as auto-extensions do not apply to already open connections
      sql.sqlite3.loadSqliteVectorExtension();

      // Actually, we can just use the drift classes directly to build the global DB
      final globalDb = AgentDatabase(NativeDatabase(oldDbFile));

      // Insert some vector and FTS data
      await globalDb.initVectorIndex(3);
      await globalDb.insertEmbedding(
        id: 'vec_1',
        sourceType: 'message',
        sourceId: 'msg_1',
        groupId: 'sess_1',
        chunkIndex: 0,
        chunkText: 'Hello World Vector Migration',
        embedding: [0.1, 0.2, 0.3],
        modelId: 'test_model',
      );
      await globalDb.insertFtsRecord(
        messageId: 'msg_1',
        sessionId: 'sess_1',
        role: 'user',
        content: 'Hello World Vector Migration',
      );

      // Verify it works globally
      final globalStats = await globalDb.getEmbeddingStats();
      expect(globalStats['total_count'], 1);

      final ftsResults = await globalDb.searchFts('Migration');
      expect(ftsResults.length, 1);

      // CLOSE the database to release file locks on Windows so VaultService can rename it
      await globalDb.close();

      // 2. Trigger VaultService migration
      final activeVault = await container.read(vaultServiceProvider.future);
      expect(activeVault!.name, 'Personal');

      // 3. Open the newly migrated database using the standard provider
      // This will open the db inside the Personal vault
      final newAgentDb = container.read(agentDatabaseProvider);

      // 4. Verify the data and sqlite-vec functionality remains fully intact!
      final stats = await newAgentDb.getEmbeddingStats();
      expect(
        stats['total_count'],
        1,
        reason: 'Vector metadata should survive migration',
      );

      // Vector KNN search
      final vectorResults = await newAgentDb.searchSimilar(
        queryEmbedding: [0.1, 0.2, 0.3],
        topK: 1,
        dimension: 3,
      );
      expect(
        vectorResults.length,
        1,
        reason: 'sqlite-vec KNN search should work after physical file move',
      );
      expect(vectorResults.first['source_id'], 'msg_1');

      // FTS full text search
      final newFtsResults = await newAgentDb.searchFts('Migration');
      expect(
        newFtsResults.length,
        1,
        reason: 'FTS5 search index should survive physical file move',
      );

      // Clean up
      await newAgentDb.close();
    },
  );

  test('AgentDatabase provider handles LRU cache eviction and connection closure', () async {
    final vaultService = container.read(vaultServiceProvider.notifier);
    await container.read(vaultServiceProvider.future); // Initialize first
    
    final dbs = <String, AgentDatabase>{};
    
    // 1. 触发默认 Personal
    dbs['Personal'] = container.read(agentDatabaseProvider);
    
    // 2. 依次切换并触发 V1, V2, V3, V4, V5
    for (int i = 1; i <= 5; i++) {
      await vaultService.switchVault('V$i');
      dbs['V$i'] = container.read(agentDatabaseProvider);
    }
    
    // 现在 _dbCache 累计了 6 个不同空间 (Personal + V1~V5)。
    // 因为 maxCacheSize = 5，最初访问的 'Personal' 应该已经被移出并调用了 oldestDb.close()。
    // 尝试在已关闭的 Personal DB 上进行查询，应当由于连接关闭而抛出 StateError 错误。
    expect(
      () => dbs['Personal']!.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );

    // 确保 V5（最新访问过的）依然处于开启且工作状态
    final result = await dbs['V5']!.customSelect('SELECT 1').get();
    expect(result.isNotEmpty, isTrue);

    // 清理剩下的连接
    for (final db in dbs.values) {
      try {
        await db.close();
      } catch (_) {}
    }
  });
}
