import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/summary/domain/services/raw_data_exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SummaryRawDataView extends ConsumerStatefulWidget {
  const SummaryRawDataView({super.key});

  @override
  ConsumerState<SummaryRawDataView> createState() => _SummaryRawDataViewState();
}

class _SummaryRawDataViewState extends ConsumerState<SummaryRawDataView> {
  DateTimeRange? _dateRange;
  bool _isExporting = false;

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      initialDateRange:
          _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      confirmText: '确定',
      cancelText: '取消',
      saveText: '选择',
    );

    if (result != null) {
      setState(() {
        _dateRange = result;
      });
    }
  }

  Future<void> _exportData() async {
    if (_dateRange == null) {
      AppToast.show(context, '请先选择日期范围');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final text = await ref
          .read(rawDataExporterProvider)
          .exportRawData(_dateRange!.start, _dateRange!.end);

      if (text.isEmpty) {
        if (mounted) AppToast.show(context, '该范围内没有日记数据');
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        AppToast.show(context, '原始数据已复制到剪贴板', icon: Icons.check);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, '导出失败: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '原始数据导出 (Raw Data Export)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '无损导出指定日期范围内的所有日记数据，包含元数据和标签。',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Date Range Selector
          InkWell(
            onTap: _selectDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dateRange == null
                          ? '点击选择日期范围'
                          : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)}  至  ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _dateRange == null ? Colors.grey : null,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          const Spacer(),

          if (_isExporting)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton.icon(
              onPressed: _dateRange == null ? null : _exportData,
              icon: const Icon(Icons.file_download),
              label: const Text('导出并复制'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppTheme.primary,
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
