import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/summary/domain/services/raw_data_exporter.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 原始数据导出视图
/// 提供按日期范围导出原始日记文本的功能，并支持一键复制到剪贴板。
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
      confirmText: t.common.confirm,
      cancelText: t.common.cancel,
      saveText: t.common.select,
    );

    if (result != null) {
      setState(() {
        _dateRange = result;
      });
    }
  }

  Future<void> _exportData() async {
    if (_dateRange == null) {
      AppToast.showError(context, t.summary.error_select_range);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final text = await ref
          .read(rawDataExporterProvider)
          .exportRawData(_dateRange!.start, _dateRange!.end);

      if (text.isEmpty) {
        if (mounted) AppToast.showSuccess(context, t.summary.no_data_range);
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        AppToast.showSuccess(context, t.summary.toast_raw_exported);
      }
    } catch (e) {
      if (mounted)
        AppToast.showError(context, '${t.summary.export_failed}: $e');
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
          Text(
            t.summary.raw_data_title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t.summary.raw_data_desc,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 日期范围选择器
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
                          ? t.summary.tap_to_select_range
                          : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)}  ${t.common.to}  ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
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
              label: Text(t.summary.export_and_copy),
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
