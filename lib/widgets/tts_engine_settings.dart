import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libri_audio/services/neural_tts/cloud_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/neural_tts_engine.dart';
import 'package:libri_audio/services/neural_tts/offline_voices.dart';
import 'package:libri_audio/services/tts_service.dart';

/// Cài đặt bộ đọc trong màn Cài đặt: chọn bộ đọc, tải giọng offline,
/// nhập key Azure / Google Cloud, nghe thử.
class TtsEngineSettings extends StatelessWidget {
  const TtsEngineSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<TtsService>();
    final engines = TtsEngineType.values
        .where((t) => t != TtsEngineType.offline || tts.offlineSupported)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<TtsEngineType>(
          groupValue: tts.engineType,
          onChanged: (value) {
            if (value != null) tts.setEngineType(value);
          },
          child: Column(
            children: [
              for (final t in engines)
                RadioListTile<TtsEngineType>(
                  value: t,
                  title: Text(t.label),
                  subtitle: Text(_engineDescription(t)),
                ),
            ],
          ),
        ),
        if (!tts.offlineSupported)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Trình duyệt này không chạy được giọng offline.'),
          ),
        const Divider(),
        if (tts.engineType == TtsEngineType.offline) const _OfflineVoices(),
        if (tts.engineType == TtsEngineType.azure) const _AzureSettings(),
        if (tts.engineType == TtsEngineType.google) const _GoogleSettings(),
        if (tts.engineError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              tts.engineError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              FilledButton.icon(
                icon: Icon(tts.isSpeaking ? Icons.stop : Icons.play_arrow),
                label: Text(tts.isSpeaking ? 'Dừng' : 'Nghe thử'),
                onPressed: () => tts.isSpeaking ? tts.stop() : tts.preview(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _engineDescription(TtsEngineType type) {
    switch (type) {
      case TtsEngineType.system:
        return 'Miễn phí, không cần mạng. Chất lượng tuỳ máy.';
      case TtsEngineType.offline:
        return 'Miễn phí, không cần mạng sau khi tải giọng (64 MB).';
      case TtsEngineType.azure:
        return 'Giọng tự nhiên nhất. Cần mạng và key Azure Speech.';
      case TtsEngineType.google:
        return 'Giọng tự nhiên. Cần mạng và API key Google Cloud.';
    }
  }
}

class _OfflineVoices extends StatelessWidget {
  const _OfflineVoices();

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<TtsService>();
    return Column(
      children: [
        for (final voice in offlineViVoices) _voiceTile(context, tts, voice),
      ],
    );
  }

  Widget _voiceTile(BuildContext context, TtsService tts, OfflineVoice voice) {
    final installed = tts.isOfflineVoiceInstalled(voice.id);
    final downloading = tts.downloadingVoiceId == voice.id;
    final selected = tts.offlineVoiceId == voice.id;

    Widget trailing;
    if (downloading) {
      final progress = tts.downloadProgress;
      trailing = SizedBox(
        width: 48,
        child: progress != null && progress < 1
            ? Text('${(progress * 100).toInt()}%', textAlign: TextAlign.end)
            : const Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
      );
    } else if (installed) {
      trailing = IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Xoá giọng',
        onPressed: () => tts.deleteOfflineVoice(voice.id),
      );
    } else {
      trailing = IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Tải giọng (${voice.sizeMb} MB)',
        onPressed: tts.downloadingVoiceId != null ? null : () => _download(context, tts, voice),
      );
    }

    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: installed ? null : Theme.of(context).disabledColor,
      ),
      title: Text(voice.label),
      subtitle: Text(installed
          ? voice.description
          : downloading
              ? 'Đang tải và giải nén...'
              : '${voice.description}. Cần tải ${voice.sizeMb} MB.'),
      trailing: trailing,
      onTap: installed ? () => tts.setOfflineVoice(voice.id) : null,
    );
  }

  Future<void> _download(BuildContext context, TtsService tts, OfflineVoice voice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await tts.downloadOfflineVoice(voice.id);
      await tts.setOfflineVoice(voice.id);
      messenger.showSnackBar(SnackBar(content: Text('Đã tải giọng ${voice.label}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

/// Ô nhập key: không hiện lại key đã lưu, chỉ báo đã có key.
class _KeyField extends StatefulWidget {
  final String label;
  final bool hasKey;
  final String helpText;
  final Future<void> Function(String key) onSave;

  const _KeyField({
    required this.label,
    required this.hasKey,
    required this.helpText,
    required this.onSave,
  });

  @override
  State<_KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<_KeyField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave(_controller.text);
    _controller.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu key')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hasKey ? 'Đã lưu key. Nhập key mới để thay.' : null,
              helperText: widget.helpText,
              helperMaxLines: 3,
              suffixIcon: IconButton(icon: const Icon(Icons.save), onPressed: _save),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (widget.hasKey)
            TextButton(
              onPressed: () => widget.onSave(''),
              child: const Text('Xoá key đã lưu'),
            ),
        ],
      ),
    );
  }
}

class _AzureSettings extends StatefulWidget {
  const _AzureSettings();

  @override
  State<_AzureSettings> createState() => _AzureSettingsState();
}

class _AzureSettingsState extends State<_AzureSettings> {
  late final TextEditingController _region =
      TextEditingController(text: context.read<TtsService>().azureRegion);

  @override
  void dispose() {
    _region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<TtsService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyField(
          label: 'Key Azure Speech',
          hasKey: tts.hasAzureKey,
          helpText: 'Tạo tài nguyên Speech trên portal.azure.com, gói F0 miễn phí '
              '0,5 triệu ký tự/tháng. Key chỉ lưu trên máy này.',
          onSave: (key) => tts.setAzureConfig(key: key),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _region,
            decoration: const InputDecoration(
              labelText: 'Vùng (region)',
              helperText: 'Vùng của tài nguyên Speech, ví dụ southeastasia, eastasia',
            ),
            onSubmitted: (v) => tts.setAzureConfig(region: v),
            onEditingComplete: () => tts.setAzureConfig(region: _region.text),
          ),
        ),
        _VoiceDropdown(
          voices: azureViVoices,
          value: tts.azureVoice,
          onChanged: (v) => tts.setAzureConfig(voice: v),
        ),
      ],
    );
  }
}

class _GoogleSettings extends StatelessWidget {
  const _GoogleSettings();

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<TtsService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyField(
          label: 'API key Google Cloud',
          hasKey: tts.hasGoogleKey,
          helpText: 'Bật Cloud Text-to-Speech API trong console.cloud.google.com rồi tạo '
              'API key. Key chỉ lưu trên máy này.',
          onSave: (key) => tts.setGoogleConfig(key: key),
        ),
        _VoiceDropdown(
          voices: googleViVoices,
          value: tts.googleVoice,
          onChanged: (v) => tts.setGoogleConfig(voice: v),
        ),
      ],
    );
  }
}

class _VoiceDropdown extends StatelessWidget {
  final List<CloudVoice> voices;
  final String value;
  final void Function(String voice) onChanged;

  const _VoiceDropdown({required this.voices, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: voices.any((v) => v.id == value) ? value : null,
        decoration: const InputDecoration(labelText: 'Giọng'),
        items: [
          for (final v in voices) DropdownMenuItem(value: v.id, child: Text(v.label)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
