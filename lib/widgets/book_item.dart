import 'package:flutter/material.dart';
import 'package:libri_audio/models/book_model.dart';

class BookItem extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  
  const BookItem({
    super.key,
    required this.book,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(book.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) => onRemove(),
        child: ListTile(
          leading: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 80,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  alignment: Alignment.center,
                  child: Icon(
                    book.fileType == 'pdf' 
                      ? Icons.picture_as_pdf 
                      : book.fileType == 'epub' 
                        ? Icons.book 
                        : Icons.description,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (book.chapterIndex != null)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      book.chapterIndex.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            book.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.author != null && book.author!.isNotEmpty) 
                Text(
                  book.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (book.lastRead != null) 
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(book.lastRead!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          trailing: Icon(
            Icons.play_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
  
  String _formatDateTime(DateTime datetime) {
    final now = DateTime.now();
    final diff = now.difference(datetime);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
