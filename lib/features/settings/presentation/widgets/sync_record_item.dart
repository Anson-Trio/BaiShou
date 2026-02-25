import 'package:flutter/material.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 云端数据记录单行组件
class SyncRecordItem extends StatelessWidget {
  final dynamic record;
  final VoidCallback onRestore;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const SyncRecordItem({
    super.key,
    required this.record,
    required this.onRestore,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String filename = record.filename;
    DateTime lastModified = record.lastModified.toLocal();
    int size = record.sizeInBytes ?? 0;

    final sizeMb = (size / (1024 * 1024)).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 20,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.data_sync.backup_file_label(name: filename),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')} ${lastModified.hour.toString().padLeft(2, '0')}:${lastModified.minute.toString().padLeft(2, '0')} • ${t.data_sync.size_mb(size: sizeMb)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onSelected: (val) {
              if (val == 'restore') onRestore();
              if (val == 'rename') onRename();
              if (val == 'delete') onDelete();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'restore',
                child: Text(t.data_sync.restore_this),
              ),
              PopupMenuItem(value: 'rename', child: Text(t.data_sync.rename)),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  t.common.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
