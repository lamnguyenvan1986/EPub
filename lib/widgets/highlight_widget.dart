import 'package:flutter/material.dart';
import 'package:libri_audio/models/highlight_model.dart';

class HighlightWidget extends StatelessWidget {
  final Highlight highlight;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  
  const HighlightWidget({
    super.key,
    required this.highlight,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(
          Icons.highlight,
          color: Colors.amber[600],
        ),
        title: SelectableText(
          highlight.text,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: highlight.note != null && highlight.note!.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SelectableText(
                          highlight.note!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, size: 18),
              onPressed: onDelete,
              color: Colors.red,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onTap,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
