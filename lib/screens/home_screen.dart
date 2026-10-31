import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/screens/tts_settings_screen.dart';
import 'package:libri_audio/providers/book_provider.dart';
import 'package:libri_audio/providers/theme_provider.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/screens/file_import_screen.dart';
import 'package:libri_audio/screens/book_reader_screen.dart';
import 'package:libri_audio/widgets/book_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LibriAudio'),
        actions: [
          IconButton(
            icon: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                );
              },
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Consumer<BookProvider>(
        builder: (context, bookProvider, child) {
          if (bookProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (bookProvider.books.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookProvider.books.length,
            itemBuilder: (context, index) {
              final book = bookProvider.books[index];
              return BookItem(
                book: book,
                onTap: () => _openBook(context, book),
                onRemove: () => _confirmRemoveBook(context, book),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FileImportScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Import'),
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          const Text(
            'No books yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Import books from Google Drive or your device to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FileImportScreen()),
            ),
            icon: const Icon(Icons.download),
            label: const Text('Import Books'),
          ),
        ],
      ),
    );
  }
  
  void _openBook(BuildContext context, Book book) {
    context.read<BookProvider>().setCurrentBook(book);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookReaderScreen(book: book),
      ),
    );
  }
  
  void _confirmRemoveBook(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Book'),
        content: Text('Are you sure you want to remove "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<BookProvider>().removeBook(book.id);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dark Mode'),
                  Switch(
                    value: context.watch<ThemeProvider>().isDarkMode,
                    onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Theo hệ thống'),
                  Switch(
                    value: context.watch<ThemeProvider>().themeMode == ThemeMode.system,
                    onChanged: (followSystem) {
                      final theme = context.read<ThemeProvider>();
                      if (followSystem) {
                        theme.setSystemMode();
                      } else {
                        theme.setThemeMode(theme.isDarkMode ? ThemeMode.dark : ThemeMode.light);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reading Speed'),
                  Consumer<TtsService>(
                    builder: (context, tts, child) {
                      final rate = tts.rate;
                      return Text('${(rate * 100).toInt()}%');
                    },
                  ),
                ],
              ),
              Slider(
                value: context.watch<TtsService>().rate,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (double value) => context.read<TtsService>().setRate(value),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Voice'),
                  Consumer<TtsService>(
                    builder: (context, tts, child) {
                      final voice = tts.voice;
                      return Text(voice.isEmpty ? 'Mặc định' : voice);
                    },
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over),
                title: const Text('Giọng đọc'),
                subtitle: Text(context.watch<TtsService>().engineType.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => TtsSettingsScreen.open(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
