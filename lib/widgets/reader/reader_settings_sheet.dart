import 'package:flutter/material.dart';
import 'package:libri_audio/providers/reader_settings_provider.dart';
import 'package:provider/provider.dart';

/// Bảng tùy chọn hiển thị (Aa): font, cỡ chữ, giãn dòng, lề, nền, cuộn/lật trang.
/// Dùng chung cho EPUB, MOBI và PDF dạng chữ; đổi là áp dụng ngay và được lưu lại.
class ReaderSettingsSheet extends StatelessWidget {
  const ReaderSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const ReaderSettingsSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReaderSettingsProvider>();
    final s = provider.settings;
    final theme = Theme.of(context);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(text, style: theme.textTheme.labelLarge),
        );

    Widget slider({
      required String title,
      required double value,
      required double min,
      required double max,
      required int divisions,
      required String display,
      required ValueChanged<double> onChanged,
    }) =>
        Row(
          children: [
            SizedBox(width: 96, child: Text(title)),
            Expanded(
              child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
            ),
            SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
          ],
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Hiển thị', style: theme.textTheme.titleLarge),
                const Spacer(),
                TextButton(onPressed: provider.reset, child: const Text('Mặc định')),
              ],
            ),
            label('Cách đọc'),
            SegmentedButton<ReaderLayout>(
              segments: const [
                ButtonSegment(value: ReaderLayout.scroll, icon: Icon(Icons.swap_vert), label: Text('Cuộn')),
                ButtonSegment(value: ReaderLayout.paginate, icon: Icon(Icons.auto_stories), label: Text('Lật trang')),
              ],
              selected: {s.layout},
              onSelectionChanged: (v) => provider.update(s.copyWith(layout: v.first)),
            ),
            label('Màu nền'),
            Wrap(
              spacing: 8,
              children: [
                for (final t in ReaderTheme.values) _ThemeChip(theme: t, selected: s.theme == t, settings: s),
              ],
            ),
            label('Phông chữ'),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in ReaderSettings.fontFamilies.entries)
                  ChoiceChip(
                    label: Text(entry.value, style: TextStyle(fontFamily: entry.key)),
                    selected: s.fontFamily == entry.key,
                    onSelected: (_) => provider.update(s.copyWith(fontFamily: entry.key)),
                  ),
                FilterChip(
                  label: const Text('Căn đều'),
                  selected: s.justify,
                  onSelected: (v) => provider.update(s.copyWith(justify: v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            slider(
              title: 'Cỡ chữ',
              value: s.fontSize,
              min: 12,
              max: 36,
              divisions: 24,
              display: s.fontSize.round().toString(),
              onChanged: (v) => provider.update(s.copyWith(fontSize: v.roundToDouble())),
            ),
            slider(
              title: 'Giãn dòng',
              value: s.lineHeight,
              min: 1.1,
              max: 2.4,
              divisions: 13,
              display: s.lineHeight.toStringAsFixed(1),
              onChanged: (v) => provider.update(s.copyWith(lineHeight: (v * 10).round() / 10)),
            ),
            slider(
              title: 'Lề',
              value: s.margin,
              min: 4,
              max: 64,
              divisions: 15,
              display: s.margin.round().toString(),
              onChanged: (v) => provider.update(s.copyWith(margin: v.roundToDouble())),
            ),
            const SizedBox(height: 8),
            _Preview(settings: s),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final ReaderTheme theme;
  final bool selected;
  final ReaderSettings settings;

  const _ThemeChip({required this.theme, required this.selected, required this.settings});

  @override
  Widget build(BuildContext context) {
    final colors = settings.copyWith(theme: theme).colors(Theme.of(context));
    final name = switch (theme) {
      ReaderTheme.app => 'Theo app',
      ReaderTheme.light => 'Trắng',
      ReaderTheme.sepia => 'Giấy cũ',
      ReaderTheme.dark => 'Tối',
    };
    return ChoiceChip(
      avatar: CircleAvatar(
        backgroundColor: colors.background,
        child: Text('A', style: TextStyle(color: colors.text, fontSize: 12)),
      ),
      label: Text(name),
      selected: selected,
      onSelected: (_) => context.read<ReaderSettingsProvider>().update(settings.copyWith(theme: theme)),
    );
  }
}

class _Preview extends StatelessWidget {
  final ReaderSettings settings;
  const _Preview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final colors = settings.colors(Theme.of(context));
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: settings.margin, vertical: 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Trăm năm trong cõi người ta, chữ tài chữ mệnh khéo là ghét nhau.',
        style: settings.textStyle(colors.text),
        textAlign: settings.justify ? TextAlign.justify : TextAlign.start,
      ),
    );
  }
}
