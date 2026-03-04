import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/presentation/widgets/markdown_toolbar.dart';
import 'package:baishou/features/diary/presentation/widgets/tag_input_widget.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';

/// 日记/总结编辑器页面
/// 支持日记记录（标题、内容、标签）以及对 AI 生成总结的查看与编辑。
class DiaryEditorPage extends ConsumerStatefulWidget {
  final int? diaryId; // 如果是非空，则进入日记编辑模式
  final int? summaryId; // 如果是非空，则进入总结编辑模式，与 diaryId 互斥
  final DateTime? initialDate; // 新建日记时的默认日期

  DiaryEditorPage({super.key, this.diaryId, this.summaryId, this.initialDate})
    : assert(diaryId == null || summaryId == null, t.diary.error_dual_edit);

  @override
  ConsumerState<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends ConsumerState<DiaryEditorPage> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _contentController;

  // 标签管理
  final List<String> _tags = [];
  late TextEditingController _tagInputController;
  final FocusNode _tagFocusNode = FocusNode();

  bool _isDirty = false; // 标记内容是否有未保存的更改
  bool _isLoading = false; // 标记数据加载状态
  bool _isTransitioning = true; // 标记是否处于路由转场期间（防止 Markdown 阻塞动画）
  bool _isPreview = false; // 标记是否处于 Markdown 预览模式

  // 编辑模式：false=日记，true=总结
  bool get _isSummaryMode => widget.summaryId != null;

  // 内部追踪的实际日记 ID（处理“追加写入”机制）
  int? _currentDiaryId;

  // 总结特定状态
  SummaryType? _summaryType;
  DateTime? _summaryStartDate;
  DateTime? _summaryEndDate;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _selectedDate = now;
    _selectedTime = TimeOfDay.fromDateTime(now);
    _contentController = TextEditingController();
    _tagInputController = TextEditingController();

    _contentController.addListener(_markDirty);

    // 设置 200ms 的严格保护期，在此期间不渲染 Markdown（避免转场掉帧）
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _isTransitioning = false);
      }
    });

    if (widget.diaryId != null) {
      _isLoading = true; // 先设为加载中，防止日期闪烁
      // 延迟到第一帧绘制完成后再加载，避免阻塞路由转场动画（掉帧）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDiary(widget.diaryId!);
      });
    } else if (widget.summaryId != null) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSummary(widget.summaryId!);
      });
    } else {
      // 新增模式：直接创建干净的空白日记（不合并今日旧内容）
      _initNewDiary();
    }
  }

  /// 初始化"新增日记"流程：仅插入当前时间戳，不合并今日旧内容
  Future<void> _initNewDiary() async {
    final timeMark = '##### ${DateFormat('HH:mm').format(DateTime.now())}\n\n';
    _contentController.text = timeMark;
    _contentController.selection = TextSelection.collapsed(
      offset: timeMark.length,
    );
  }

  /// 标记内容已修改
  void _markDirty() {
    if (!_isDirty && !_isLoading) setState(() => _isDirty = true);
  }

  /// 加载日记（日记编辑模式）
  Future<void> _loadDiary(int id) async {
    setState(() => _isLoading = true);
    try {
      final diary = await ref.read(diaryRepositoryProvider).getDiaryById(id);
      if (diary != null && mounted) {
        setState(() {
          _selectedDate = diary.date;
          _selectedTime = TimeOfDay.fromDateTime(diary.date);
        });
        _populateControllers(diary.content, diary.tags);
      }
    } catch (e) {
      debugPrint('Err load diary: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 加载总结数据（总结模式）
  Future<void> _loadSummary(int id) async {
    setState(() => _isLoading = true);
    try {
      final summary = await ref
          .read(summaryRepositoryProvider)
          .getSummaryById(id);
      if (summary != null && mounted) {
        setState(() {
          _selectedDate = summary.startDate;
          _selectedTime = TimeOfDay.fromDateTime(summary.startDate);
          _summaryType = summary.type;
          _summaryStartDate = summary.startDate;
          _summaryEndDate = summary.endDate;
        });
        // 总结没有标题和标签，直接填充内容
        _contentController.text = summary.content;
        _tags.clear();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isDirty = false);
        });
      }
    } catch (e) {
      debugPrint('Err load summary: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 填充控制器内容
  /// 将 fullContent 拆分为标题和正文，并加载标签。
  void _populateControllers(String fullContent, List<String> tags) {
    _contentController.text = fullContent;
    _tags.clear();
    _tags.addAll(tags.where((t) => t.trim().isNotEmpty));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isDirty = false);
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  // ─── 标签管理 ─────────────────────────────────

  /// 添加标签
  void _addTag(String text) {
    final tag = text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _isDirty = true;
      });
    }
    _tagInputController.clear();
  }

  /// 移除标签
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _isDirty = true;
    });
  }

  // ─── 工具栏操作 ────────────────────────────────

  /// 在光标处插入 Markdown 文本
  void _insertText(String prefix, [String suffix = '']) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    if (selection.start == -1 || selection.end == -1) {
      final newText = '$text\n$prefix$suffix';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newText.length - suffix.length,
        ),
      );
      return;
    }

    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length + selectedText.length,
      ),
    );
  }

  // ─── 保存 ───────────────────────────────────────────

  /// 执行保存操作
  Future<void> _save() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      AppToast.showSuccess(context, t.diary.editor_hint);
      return;
    }

    Diary? savedDiary; // 保存成功后要带回列表页的实体

    try {
      if (_isSummaryMode) {
        final summary = await ref
            .read(summaryRepositoryProvider)
            .getSummaryById(widget.summaryId!);
        if (summary != null) {
          await ref
              .read(summaryRepositoryProvider)
              .updateSummary(
                summary.copyWith(
                  content: content,
                  startDate: _summaryStartDate,
                  endDate: _summaryEndDate,
                ),
              );
        }
      } else {
        final repo = ref.read(diaryRepositoryProvider);

        if (widget.diaryId != null) {
          // ── 编辑模式：直接用原始 ID 更新，允许用户修改日期 ──
          final diary = await repo.getDiaryById(widget.diaryId!);
          if (diary != null) {
            final updated = diary.copyWith(
              content: content,
              tags: _tags,
              date: _selectedDate,
            );
            await repo.saveDiary(
              id: updated.id,
              content: updated.content,
              date: updated.date,
              tags: updated.tags,
            );
            // 内存直挺：把修改后的实体带回列表页
            savedDiary = updated.copyWith(updatedAt: DateTime.now());
          }
        } else {
          // ── 新增模式：按日期查找，避免同一天出现两篇日记 ──
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
          final allDiaries = await repo.getAllDiaries();
          final existingDiary = allDiaries
              .where((d) => DateFormat('yyyy-MM-dd').format(d.date) == dateStr)
              .firstOrNull;

          if (existingDiary != null) {
            // 该日期已有日记，执行追加（合并内容到已有日记）
            final fullExisting =
                await repo.getDiaryById(existingDiary.id) ?? existingDiary;
            final oldContent = fullExisting.content.trimRight();
            final finalContent = oldContent.isEmpty
                ? content
                : '$oldContent\n\n$content';

            // 合并标签
            final mergedTags = {...fullExisting.tags, ..._tags}.toList();

            await repo.saveDiary(
              id: fullExisting.id,
              content: finalContent,
              date: _selectedDate,
              tags: mergedTags,
            );
            // 内存直挺：带回当天已更新的实体
            savedDiary = fullExisting.copyWith(
              content: finalContent,
              date: _selectedDate,
              tags: mergedTags,
              updatedAt: DateTime.now(),
            );
          } else {
            // 该日期没有日记，执行新建
            final newId = DateTime.now().millisecondsSinceEpoch;
            await repo.saveDiary(
              id: newId,
              content: content,
              date: _selectedDate,
              tags: _tags,
            );
            // 内存直挺：构造实体带回列表页
            savedDiary = Diary(
              id: newId,
              content: content,
              date: _selectedDate,
              tags: _tags,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        }
      }

      if (mounted) {
        setState(() => _isDirty = false);
        AppToast.showSuccess(context, t.diary.saved_toast);
        // 带回新建/更新的 Diary 实体，列表页直接内存插入
        context.pop(savedDiary);
      }
    } catch (e) {
      debugPrint('Error saving: $e');
      if (mounted) {
        AppToast.showError(
          context,
          t.diary.save_failed(e: e.toString()),
          backgroundColor: Colors.red[900],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: _buildAppBarTitle(context),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Text(t.common.save),
            ),
          ),
        ],
      ),
      body: (_isLoading || _isTransitioning)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    children: [
                      // 标签（仅日记模式）
                      if (!_isSummaryMode) ...[
                        const SizedBox(height: 8),
                        TagInputWidget(
                          tags: _tags,
                          controller: _tagInputController,
                          focusNode: _tagFocusNode,
                          onAddTag: _addTag,
                          onRemoveTag: _removeTag,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 内容：在编辑和预览之间切换
                      if (_isPreview)
                        _contentController.text.trim().isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Center(
                                  child: Text(
                                    t.diary.no_content_preview,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : MarkdownBody(
                                data: _contentController.text,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                  h1: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                  h2: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                  h3: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                  code: TextStyle(
                                    fontSize: 14,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    color: AppTheme.primary,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  blockquoteDecoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: AppTheme.primary.withOpacity(
                                          0.5,
                                        ),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  listBullet: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                  checkbox: TextStyle(color: AppTheme.primary),
                                ),
                              )
                      else
                        TextField(
                          controller: _contentController,
                          maxLines: null,
                          minLines: 10,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          decoration: InputDecoration(
                            hintText: t.diary.editor_hint,
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                          ),
                        ),
                    ],
                  ),
                ),
                // Markdown 格式化工具栏
                MarkdownToolbar(
                  isPreview: _isPreview,
                  onTogglePreview: () {
                    setState(() => _isPreview = !_isPreview);
                    if (_isPreview) FocusScope.of(context).unfocus();
                  },
                  onHideKeyboard: () => FocusScope.of(context).unfocus(),
                  onInsertText: _insertText,
                ),
              ],
            ),
    );
  }

  // ─── 总结日期逻辑 ─────────────────────────────

  /// 构建 AppBar 标题
  /// 总结模式显示周期类型和日期范围；日记模式显示星期、时间和日期。
  Widget _buildAppBarTitle(BuildContext context) {
    if (_isSummaryMode && _summaryType != null) {
      String dateText = '';
      String subText = '';

      switch (_summaryType!) {
        case SummaryType.weekly:
          subText = t.summary.stats_weekly;
          if (_summaryStartDate != null && _summaryEndDate != null) {
            dateText =
                '${_summaryStartDate!.month}.${_summaryStartDate!.day} - ${_summaryEndDate!.month}.${_summaryEndDate!.day}';
          }
          break;
        case SummaryType.monthly:
          subText = t.summary.stats_monthly;
          if (_summaryStartDate != null) {
            dateText =
                '${_summaryStartDate!.year}${t.common.year_suffix} ${_summaryStartDate!.month}${t.common.month_suffix}';
          }
          break;
        case SummaryType.quarterly:
          subText = t.summary.stats_quarterly;
          if (_summaryStartDate != null) {
            final q = (_summaryStartDate!.month / 3).ceil();
            dateText =
                '${_summaryStartDate!.year}${t.common.year_suffix} ${t.common.quarter_prefix}$q';
          }
          break;
        case SummaryType.yearly:
          subText = t.summary.stats_yearly;
          if (_summaryStartDate != null) {
            dateText = '${_summaryStartDate!.year}${t.common.year_suffix}';
          }
          break;
      }

      return GestureDetector(
        onTap: _pickSummaryDate,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    // 默认日记标题
    final dateStr = DateFormat(
      t.diary.date_format_editor,
    ).format(_selectedDate);
    final weekDay = DateFormat(
      'EEEE',
      LocaleSettings.instance.currentLocale.languageCode,
    ).format(_selectedDate);

    return GestureDetector(
      onTap: _pickDate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekDay,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isDirty = true;
      });
    }
  }

  Future<void> _pickSummaryDate() async {
    if (_summaryType == null) return;

    final now = DateTime.now();
    switch (_summaryType!) {
      case SummaryType.weekly:
        final result = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDateRange:
              (_summaryStartDate != null && _summaryEndDate != null)
              ? DateTimeRange(start: _summaryStartDate!, end: _summaryEndDate!)
              : null,
        );
        if (result != null) {
          setState(() {
            _summaryStartDate = result.start;
            _summaryEndDate = result.end;
            _isDirty = true;
          });
        }
        break;

      case SummaryType.monthly:
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDate: _summaryStartDate ?? now,
          initialDatePickerMode: DatePickerMode.year,
          helpText: t.diary.select_month,
        );
        if (date != null) {
          setState(() {
            _summaryStartDate = DateTime(date.year, date.month, 1);
            _summaryEndDate = DateTime(
              date.year,
              date.month + 1,
              0,
            ); // End of month
            _isDirty = true;
          });
        }
        break;

      case SummaryType.quarterly:
        // 简单的季度选择逻辑
        int year = _summaryStartDate?.year ?? now.year;
        int quarter = _summaryStartDate != null
            ? (_summaryStartDate!.month / 3).ceil()
            : 1;

        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(t.diary.select_quarter),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<int>(
                      value: year,
                      items: List.generate(10, (i) => 2020 + i)
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y${t.common.year_suffix}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => year = v!),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [1, 2, 3, 4]
                          .map(
                            (q) => ChoiceChip(
                              label: Text('Q$q'),
                              selected: quarter == q,
                              onSelected: (b) {
                                if (b) setDialogState(() => quarter = q);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t.common.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _summaryStartDate = DateTime(
                          year,
                          (quarter - 1) * 3 + 1,
                          1,
                        );
                        _summaryEndDate = DateTime(
                          year,
                          (quarter - 1) * 3 + 3 + 1,
                          0,
                        ); // End of quarter
                        _isDirty = true;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(t.common.confirm),
                  ),
                ],
              );
            },
          ),
        );
        break;

      case SummaryType.yearly:
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(t.summary.filter_year),
              content: SizedBox(
                width: 300,
                height: 300,
                child: YearPicker(
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  selectedDate: _summaryStartDate ?? now,
                  onChanged: (DateTime dateTime) {
                    setState(() {
                      _summaryStartDate = DateTime(dateTime.year, 1, 1);
                      _summaryEndDate = DateTime(dateTime.year, 12, 31);
                      _isDirty = true;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          },
        );
        break;
    }
  }
}
