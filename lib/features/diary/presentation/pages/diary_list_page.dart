import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/year_month_picker_sheet.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/data/vault_index_notifier.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/entities/diary_meta.dart';
import 'package:baishou/features/diary/presentation/widgets/diary_card.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:baishou/core/localization/locale_service.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/core/storage/permission_service.dart';
import 'package:baishou/features/index/data/shadow_index_sync_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// 日记列表页面
/// 架构：UI 直接绑定内存 VaultIndex（Obsidian 模式），无游标分页，无 StreamSubscription。
/// VaultIndex 全量持有元数据，CRUD 直接更新内存，watcher 只处理外部变化。
class DiaryListPage extends ConsumerStatefulWidget {
  const DiaryListPage({super.key});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  DateTime? _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  String _searchQuery = '';
  bool _isSearching = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);

    // 直接绑定内存 VaultIndex：现在是 AsyncValue
    final allMetaAsync = ref.watch(vaultIndexProvider);

    bool isMobile = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isMobile = true;
      }
    } catch (e) {}
    final bool isDesktop = !isMobile;

    return SafeArea(
      top: isMobile,
      bottom: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withOpacity(0.8),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: _isSearching && !isDesktop
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: t.common.search_hint,
                    border: InputBorder.none,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                )
              : _buildHeader(context, isDesktop),
          actions: isDesktop
              ? null
              : [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) _searchQuery = '';
                      });
                    },
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                  ),
                ],
        ),
        body: allMetaAsync.when(
          data: (allMeta) {
            final filteredMeta = _getFilteredMeta(allMeta);

            if (filteredMeta.isEmpty) {
              return _buildEmptyState(context);
            }

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: AlignedGridView.count(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 24,
                ),
                crossAxisCount: _getCrossAxisCount(context),
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                itemCount: filteredMeta.length,
                itemBuilder: (context, index) {
                  final meta = filteredMeta[index];
                  return _DiaryMetaCard(
                    meta: meta,
                    onDelete: () => _confirmDelete(context, ref, meta),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $err'),
                TextButton(
                  onPressed: () => ref.invalidate(vaultIndexProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: isDesktop
            ? null
            : allMetaAsync.when(
                data: (allMeta) => _buildMobileFABs(context, allMeta),
                loading: () => null,
                error: (_, __) => null,
              ),
      ),
    );
  }

  Widget _buildMobileFABs(BuildContext context, List<DiaryMeta> allMeta) {
    final todayMeta = allMeta.firstWhereOrNull(
      (m) => DateUtils.isSameDay(m.date, DateTime.now()),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 编辑今日按钮 (仅在存在今日日记时显示更明显的图标)
        FloatingActionButton.small(
          heroTag: 'editToday',
          onPressed: () {
            if (todayMeta != null) {
              context.push('/diary/edit?id=${todayMeta.id}&append=1');
            } else {
              context.push(
                '/diary/edit?date=${DateTime.now().toIso8601String()}',
              );
            }
          },
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            todayMeta != null ? Icons.edit_note : Icons.today,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        // 新增按钮
        FloatingActionButton(
          heroTag: 'addNew',
          onPressed: () => context.push(
            '/diary/edit?date=${DateTime.now().toIso8601String()}',
          ),
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ],
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1200) return 3;
    if (width > 700) return 2;
    return 1;
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);
    final isEn = LocaleSettings.instance.currentLocale == AppLocale.en;
    final now = DateTime.now();
    final dateToDisplay = _selectedMonth ?? now;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showMonthPicker(context),
            child: Row(
              children: [
                Text(
                  _selectedMonth == null
                      ? t.diary.all_diaries
                      : '${dateToDisplay.year}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_selectedMonth != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    isEn
                        ? DateFormat('MMM').format(dateToDisplay)
                        : '${dateToDisplay.month}月',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
                Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface),
              ],
            ),
          ),
          if (isDesktop)
            Row(
              children: [
                Container(
                  width: 200,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: t.common.search_hint,
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 桌面端新增日记与今天日记编辑按钮
                Consumer(
                  builder: (context, ref, child) {
                    final allMeta = ref.watch(vaultIndexProvider).value ?? [];
                    final todayMeta = allMeta.firstWhereOrNull(
                      (m) => DateUtils.isSameDay(m.date, DateTime.now()),
                    );
                    return Row(
                      children: [
                        IconButton(
                          tooltip: todayMeta != null ? '编辑今天' : '写今天',
                          onPressed: () {
                            if (todayMeta != null) {
                              context.push(
                                '/diary/edit?id=${todayMeta.id}&append=1',
                              );
                            } else {
                              context.push(
                                '/diary/edit?date=${DateTime.now().toIso8601String()}',
                              );
                            }
                          },
                          icon: Icon(
                            todayMeta != null ? Icons.edit_note : Icons.today,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed: () => context.push(
                            '/diary/edit?date=${DateTime.now().toIso8601String()}',
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('写日记'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DiaryMeta meta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.diary.delete_confirm_title),
        content: Text(t.diary.delete_confirm_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(diaryRepositoryProvider).deleteDiary(meta.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context) async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => YearMonthPickerSheet(initialDate: _selectedMonth),
    );

    if (result != null) {
      setState(() {
        if (result.year == 0) {
          _selectedMonth = null;
        } else {
          _selectedMonth = result;
        }
      });
    }
  }

  List<DiaryMeta> _getFilteredMeta(List<DiaryMeta> allMeta) {
    var metas = allMeta;
    if (_selectedMonth != null) {
      metas = metas.where((m) {
        return m.date.year == _selectedMonth!.year &&
            m.date.month == _selectedMonth!.month;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      metas = metas.where((m) => m.preview.toLowerCase().contains(q)).toList();
    }
    return metas;
  }

  Widget _buildEmptyState(BuildContext context) {
    bool isAndroid = false;
    try {
      if (Platform.isAndroid) isAndroid = true;
    } catch (e) {}

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_note,
              size: 80,
              color: AppTheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedMonth != null
                  ? t.diary.no_diaries_month
                  : t.diary.no_diaries,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_selectedMonth != null)
              TextButton(
                onPressed: () => setState(() => _selectedMonth = null),
                child: Text(t.common.view_all),
              ),
            if (isAndroid) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final granted = await ref
                      .read(permissionServiceProvider.notifier)
                      .requestStoragePermission();
                  if (granted) {
                    if (!mounted) return;
                    AppToast.showSuccess(
                      context,
                      t.common.permission.storage_granted,
                    );

                    // 关键：权限获得后需要触发一次全量扫描，否则数据库是空的
                    await ref
                        .read(shadowIndexSyncServiceProvider.notifier)
                        .fullScanVault();

                    // 扫描完成后再刷新内存索引
                    ref.invalidate(vaultIndexProvider);
                  } else {
                    if (!mounted) return;
                    AppToast.showError(
                      context,
                      t.common.permission.storage_denied,
                    );
                  }
                },
                icon: const Icon(Icons.security_rounded),
                label: const Text('检查存储权限'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 轻量卡片：直接接收 DiaryMeta，点击时去编辑（只加载内容）
class _DiaryMetaCard extends ConsumerWidget {
  final DiaryMeta meta;
  final VoidCallback? onDelete;

  const _DiaryMetaCard({required this.meta, this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 构造一个只有元数据（内容用 preview 代替）的 Diary 传给 DiaryCard
    // 点击时会打开编辑器，编辑器会从 getDiaryById 读取完整内容
    final diaryStub = Diary(
      id: meta.id,
      date: meta.date,
      content: meta.preview,
      tags: meta.tags,
      createdAt: meta.updatedAt,
      updatedAt: meta.updatedAt,
    );

    return DiaryCard(
      diary: diaryStub,
      onDelete: onDelete,
      // 编辑后的原地更新：VaultIndex 由 repository 在 saveDiary 中调用 upsert 完成
      // 这里不需要 onUpdated 回调（VaultIndex 直接触发整个列表重绘）
    );
  }
}
