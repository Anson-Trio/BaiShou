import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/presentation/widgets/datetime_picker_sheet.dart';
import 'package:baishou/features/diary/presentation/widgets/markdown_toolbar.dart';
import 'package:baishou/features/diary/presentation/widgets/tag_input_widget.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:baishou/features/diary/application/file_sync_service.dart';
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
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  // 标签管理
  final List<String> _tags = [];
  late TextEditingController _tagInputController;
  final FocusNode _tagFocusNode = FocusNode();

  bool _isDirty = false; // 标记内容是否有未保存的更改
  bool _isLoading = false; // 标记数据加载状态
  bool _isPreview = false; // 标记是否处于 Markdown 预览模式

  // 编辑模式：false=日记，true=总结
  bool get _isSummaryMode => widget.summaryId != null;

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
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _tagInputController = TextEditingController();

    _titleController.addListener(_markDirty);
    _contentController.addListener(_markDirty);

    if (widget.diaryId != null) {
      _loadDiary(widget.diaryId!);
    } else if (widget.summaryId != null) {
      _loadSummary(widget.summaryId!);
    }
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
        _titleController.text = '';
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
    final splitIndex = fullContent.indexOf('\n');
    String title = '';
    String body = '';

    if (splitIndex != -1) {
      title = fullContent.substring(0, splitIndex);
      body = fullContent.substring(splitIndex + 1);
    } else {
      title = fullContent;
    }

    _titleController.text = title;
    _contentController.text = body;
    _tags.clear();
    _tags.addAll(tags.where((t) => t.trim().isNotEmpty));

    // 填充后需要重置 _isDirty，因为 listener 会在赋值时触发 _markDirty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isDirty = false);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
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

  // ─── 日期和时间选择器 ────────────────────────────

  /// 显示自定义日期时间选择器
  Future<void> _showDateTimePicker() async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DateTimePickerSheet(
        initialDate: _selectedDate,
        initialTime: _selectedTime,
        onDateChanged: (d) => setState(() {
          _selectedDate = d;
          _isDirty = true;
        }),
        onTimeChanged: (t) => setState(() {
          _selectedTime = t;
          _isDirty = true;
        }),
      ),
    );
  }

  /// 合并日期和时间
  DateTime get _combinedDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  // ─── 保存 ───────────────────────────────────────────

  /// 执行保存操作
  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _contentController.text.trim();
    // 将标题和正文拼接保存，标题作为第一行
    // 注意：只 trimRight()，保留当 title 为空时的首个 \n，避免正文被当成标题解析
    final combinedContent = '$title\n${body.trimRight()}';

    if (combinedContent.trim().isEmpty) {
      AppToast.showSuccess(context, t.diary.editor_hint);
      return;
    }

    try {
      if (_isSummaryMode) {
        // 总结模式：只更新总结的正文内容和可能变动的日期范围
        final summary = await ref
            .read(summaryRepositoryProvider)
            .getSummaryById(widget.summaryId!);
        if (summary != null) {
          await ref
              .read(summaryRepositoryProvider)
              .updateSummary(
                summary.copyWith(
                  content: _contentController.text.trim(),
                  startDate: _summaryStartDate,
                  endDate: _summaryEndDate,
                ),
              );
        }
      } else {
        // 日记模式：保存完整的日记实体
        await ref
            .read(diaryRepositoryProvider)
            .saveDiary(
              id: widget.diaryId,
              date: _combinedDateTime,
              content: combinedContent,
              tags: _tags,
            );

        // 触发文件同步 (Task 4)
        if (mounted) {
          final diary = Diary(
            id:
                widget.diaryId ??
                0, // 这里的 ID 如果是新建的可能需要从 DB 获取，但 FileSyncService 目前主要用日期
            date: _combinedDateTime,
            content: combinedContent,
            tags: _tags,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          ref.read(fileSyncServiceProvider.notifier).syncDiaryToFile(diary);
        }
      }

      if (mounted) {
        setState(() => _isDirty = false);
        AppToast.showSuccess(context, t.diary.saved_toast);
        context.pop(); // 保存成功后返回上一页
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
      body: _isLoading
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
                      // 标题（仅在日记模式下显示）
                      if (!_isSummaryMode) ...[
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          decoration: InputDecoration(
                            hintText: t.common.title,
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.next,
                        ),

                        // 标签（流式布局）
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
    final timeStr = _selectedTime.format(context);
    final weekDay = DateFormat(
      'EEEE',
      LocaleSettings.instance.currentLocale.languageCode,
    ).format(_selectedDate);

    return GestureDetector(
      onTap: _showDateTimePicker,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$weekDay / $timeStr',
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
