import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiaryEditorPage extends ConsumerStatefulWidget {
  final int? diaryId;
  final DateTime? initialDate;

  const DiaryEditorPage({super.key, this.diaryId, this.initialDate});

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
      builder: (context) => _DateTimePickerSheet(
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
      await ref
          .read(diaryRepositoryProvider)
          .saveDiary(
            id: widget.diaryId,
            date: _combinedDateTime,
            content: combinedContent,
            tags: _tags,
          );

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
                      // Title
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
                      _buildTagInput(),

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
                _buildToolbar(context),
              ],
            ),
    );
  }

  // ─── Tag Input Widget ───────────────────────────────
  Widget _buildTagInput() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Existing tags as chips
        ..._tags.map(
          (tag) => Chip(
            label: Text(
              '#$tag',
              style: const TextStyle(fontSize: 12, color: AppTheme.primary),
            ),
            deleteIcon: const Icon(Icons.close, size: 14),
            deleteIconColor: AppTheme.primary.withOpacity(0.6),
            onDeleted: () => _removeTag(tag),
            backgroundColor: AppTheme.primary.withOpacity(0.08),
            side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
        // Input for new tag
        SizedBox(
          width: 120,
          child: TextField(
            controller: _tagInputController,
            focusNode: _tagFocusNode,
            style: const TextStyle(fontSize: 13, color: AppTheme.primary),
            decoration: InputDecoration(
              hintText: '添加标签...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onSubmitted: (value) {
              // Split by comma to support multiple tags at once
              final parts = value.split(RegExp(r'[,，]'));
              for (final part in parts) {
                _addTag(part);
              }
              _tagFocusNode.requestFocus();
            },
          ),
        ),
      ],
    );
  }

  // ─── Toolbar ────────────────────────────────────────
  Widget _buildToolbar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToolBtn(
                      icon: Icons.format_bold,
                      onPressed: () => _insertText('**', '**'),
                    ),
                    _ToolBtn(
                      icon: Icons.format_italic,
                      onPressed: () => _insertText('*', '*'),
                    ),
                    _ToolBtn(
                      icon: Icons.title,
                      onPressed: () => _insertText('## '),
                    ),
                    _divider(),
                    _ToolBtn(
                      icon: Icons.format_list_bulleted,
                      onPressed: () => _insertText('- '),
                    ),
                    _ToolBtn(
                      icon: Icons.check_box_outlined,
                      onPressed: () => _insertText('- [ ] '),
                    ),
                    _divider(),
                    _ToolBtn(
                      icon: Icons.link,
                      onPressed: () => _insertText('[', '](url)'),
                    ),
                    _ToolBtn(
                      icon: Icons.image,
                      onPressed: () => _insertText('![', '](image_url)'),
                    ),
                  ],
                ),
              ),
            ),
            // Preview toggle
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPreview ? Icons.edit : Icons.menu_book_rounded,
                      color: _isPreview ? AppTheme.primary : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _isPreview = !_isPreview);
                      if (_isPreview) FocusScope.of(context).unfocus();
                    },
                    tooltip: _isPreview ? '编辑' : '预览',
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_hide),
                    onPressed: () => FocusScope.of(context).unfocus(),
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 8),
    width: 1,
    height: 20,
    color: Colors.grey[300],
  );
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ToolBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      color: Colors.grey[600],
      iconSize: 22,
      splashRadius: 20,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

class _DateTimePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final TimeOfDay initialTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const _DateTimePickerSheet({
    required this.initialDate,
    required this.initialTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  State<_DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<_DateTimePickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  final int _minYear = 2000;
  final int _maxYear = 2200;

  // Cache widgets to improve performance
  late List<Widget> _yearWidgets;
  late List<Widget> _monthWidgets;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;

    // Clamp initial date to valid range just in case
    if (_selectedYear < _minYear) _selectedYear = _minYear;
    if (_selectedYear > _maxYear) _selectedYear = _maxYear;

    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _minYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);

    // Initialize cached widgets
    _yearWidgets = List.generate(
      _maxYear - _minYear + 1,
      (index) => Center(
        child: Text(
          '${_minYear + index}年',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );

    _monthWidgets = List.generate(
      12,
      (index) => Center(
        child: Text('${index + 1}月', style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      final bool isLeapYear =
          (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonth[month];
  }

  void _updateDate() {
    final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
    if (_selectedDay > daysInMonth) {
      _selectedDay = daysInMonth;
    }
    if (_dayController.hasClients &&
        _dayController.selectedItem > daysInMonth - 1) {
      _dayController.jumpToItem(daysInMonth - 1);
    }

    widget.onDateChanged(DateTime(_selectedYear, _selectedMonth, _selectedDay));
  }

  // Custom Picker Widget helper
  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required List<Widget> children,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      onSelectedItemChanged: onSelectedItemChanged,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(
              color: AppTheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
      ),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: '日期'),
              Tab(text: '时间'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Custom Date Tab
                Row(
                  children: [
                    // Year
                    Expanded(
                      flex: 2,
                      child: _buildPicker(
                        controller: _yearController,
                        children: _yearWidgets,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedYear = _minYear + index;
                            _updateDate();
                          });
                        },
                      ),
                    ),
                    // Month
                    Expanded(
                      flex: 1,
                      child: _buildPicker(
                        controller: _monthController,
                        children: _monthWidgets,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedMonth = index + 1;
                            _updateDate();
                          });
                        },
                      ),
                    ),
                    // Day
                    Expanded(
                      flex: 1,
                      child: _buildPicker(
                        controller: _dayController,
                        children: List.generate(
                          _getDaysInMonth(_selectedYear, _selectedMonth),
                          (index) => Center(
                            child: Text(
                              '${index + 1}日',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedDay = index + 1;
                            _updateDate();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Time Tab
                CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2020,
                    1,
                    1,
                    widget.initialTime.hour,
                    widget.initialTime.minute,
                  ),
                  use24hFormat: true,
                  onDateTimeChanged: (dt) {
                    widget.onTimeChanged(TimeOfDay.fromDateTime(dt));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
