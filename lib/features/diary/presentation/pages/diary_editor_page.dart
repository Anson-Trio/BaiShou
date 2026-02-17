import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/presentation/widgets/datetime_picker_sheet.dart';
import 'package:baishou/features/diary/presentation/widgets/markdown_toolbar.dart';
import 'package:baishou/features/diary/presentation/widgets/tag_input_widget.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiaryEditorPage extends ConsumerStatefulWidget {
  final int? diaryId;
  final int? summaryId; // 新增：总结编辑模式
  final DateTime? initialDate;

  const DiaryEditorPage({
    super.key,
    this.diaryId,
    this.summaryId,
    this.initialDate,
  }) : assert(
         diaryId == null || summaryId == null,
         'Cannot edit diary and summary at the same time',
       );

  @override
  ConsumerState<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends ConsumerState<DiaryEditorPage> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  // Tag management
  final List<String> _tags = [];
  late TextEditingController _tagInputController;
  final FocusNode _tagFocusNode = FocusNode();

  bool _isDirty = false;
  bool _isLoading = false;
  bool _isPreview = false;

  // 编辑模式：false=日记，true=总结
  bool get _isSummaryMode => widget.summaryId != null;

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

  void _markDirty() {
    if (!_isDirty && !_isLoading) setState(() => _isDirty = true);
  }

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

  // ─── Tag Management ─────────────────────────────────
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

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _isDirty = true;
    });
  }

  // ─── Toolbar Actions ────────────────────────────────
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

  // ─── Date & Time Pickers ────────────────────────────
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

  DateTime get _combinedDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  // ─── Save ───────────────────────────────────────────
  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _contentController.text.trim();
    final combinedContent = '$title\n$body'.trim();

    if (combinedContent.isEmpty) {
      AppToast.show(context, '写点什么吧...', icon: Icons.edit_outlined);
      return;
    }

    try {
      if (_isSummaryMode) {
        // 总结模式：只保存内容
        final summary = await ref
            .read(summaryRepositoryProvider)
            .getSummaryById(widget.summaryId!);
        if (summary != null) {
          await ref
              .read(summaryRepositoryProvider)
              .updateSummary(
                summary.copyWith(content: _contentController.text.trim()),
              );
        }
      } else {
        // 日记模式：保存标题+内容+标签
        await ref
            .read(diaryRepositoryProvider)
            .saveDiary(
              id: widget.diaryId,
              date: _combinedDateTime,
              content: combinedContent,
              tags: _tags,
            );
      }

      if (mounted) {
        setState(() => _isDirty = false);
        AppToast.show(context, '已保存 ✨');
        context.pop();
      }
    } catch (e) {
      debugPrint('Error saving: $e');
      if (mounted) {
        AppToast.show(
          context,
          '保存失败',
          icon: Icons.error_outline,
          backgroundColor: Colors.red[900],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy年MM月dd日').format(_selectedDate);
    final timeStr = _selectedTime.format(context);
    final weekDay = DateFormat('EEEE', 'zh_CN').format(_selectedDate);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
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
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              AppToast.show(context, 'AI 功能开发中...', icon: Icons.construction);
            },
            color: AppTheme.primary,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('保存'),
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
                      // Title (日记模式才显示)
                      if (!_isSummaryMode) ...[
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          decoration: InputDecoration(
                            hintText: '标题',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.next,
                        ),

                        // Tags (chip-based)
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

                      // Content: toggle between editor and preview
                      if (_isPreview)
                        _contentController.text.trim().isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Center(
                                  child: Text(
                                    '还没有内容可以预览',
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
                            hintText: '今天发生了什么？...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                          ),
                        ),
                    ],
                  ),
                ),
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
}
