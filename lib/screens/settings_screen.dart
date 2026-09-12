import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/providers/theme_provider.dart';
import 'package:libri_audio/services/tts_service.dart';
import 'package:libri_audio/widgets/audio_visualizer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Display',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              subtitle: Text(
                context.watch<ThemeProvider>().isDarkMode 
                  ? 'Enabled' 
                  : 'Disabled',
              ),
              trailing: Switch(
                value: context.watch<ThemeProvider>().isDarkMode,
                onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Audio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    context.watch<TtsService>().isSpeaking 
                      ? Icons.volume_up 
                      : Icons.volume_off,
                  ),
                  title: const Text('Text-to-Speech'),
                  subtitle: Text(
                    context.watch<TtsService>().isSpeaking 
                      ? 'Enabled' 
                      : 'Disabled',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Speed'),
                      Consumer<TtsService>(
                        builder: (context, tts, child) {
                          return Text('${(tts.rate * 100).toInt()}%');
                        },
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: context.watch<TtsService>().rate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: (value) => context.read<TtsService>().setRate(value),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AudioVisualizer(
                    isPlaying: context.watch<TtsService>().isSpeaking,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'App',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Clear All Data'),
              subtitle: const Text('Remove all books and settings'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showClearDataDialog(context),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Data'),
        content: const Text('This will delete all books and settings. Are you sure?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Add logic to clear data
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
