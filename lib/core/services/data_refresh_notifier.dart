import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/features/diary/data/vault_index_notifier.dart';

/// 全局数据刷新通知器
/// 当数据发生大规模变化（如导入/恢复）时，递增此值触发依赖组件刷新
class DataRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() {
    state++;
    ref.invalidate(vaultIndexProvider);
  }
}

final dataRefreshProvider = NotifierProvider<DataRefreshNotifier, int>(
  DataRefreshNotifier.new,
);
