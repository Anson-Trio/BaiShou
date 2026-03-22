/// 外观设置卡片
///
/// 主题模式切换、种子颜色选择、语言切换

import 'package:baishou/core/localization/locale_service.dart';
import 'package:baishou/core/theme/theme_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 外观设置（主题+语言）
class AppearanceSettingsCard extends ConsumerWidget {
  const AppearanceSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ExpansionTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(t.settings.appearance),
            subtitle: Text(
              '${_getThemeModeText(themeState.mode)} · ${_getLanguageText(currentLocale)}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.settings.theme_mode),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(t.settings.theme_system),
                          icon: const Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(t.settings.theme_light),
                          icon: const Icon(Icons.wb_sunny_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(t.settings.theme_dark),
                          icon: const Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {themeState.mode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(newSelection.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(t.settings.theme_color),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ColorOption(color: const Color(0xFF9AD4EA)),
                        const _CustomColorPicker(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(t.settings.language),
                    const SizedBox(height: 8),
                    _LanguageSelector(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return t.settings.theme_system;
      case ThemeMode.light:
        return t.settings.theme_light;
      case ThemeMode.dark:
        return t.settings.theme_dark;
    }
  }

  static String _getLanguageText(AppLocale? locale) {
    if (locale == null) return t.settings.language_system;
    switch (locale) {
      case AppLocale.zh:
        return t.settings.language_zh;
      case AppLocale.en:
        return t.settings.language_en;
      case AppLocale.ja:
        return t.settings.language_ja;
      case AppLocale.zhTw:
        return t.settings.language_zh_tw;
    }
  }
}

// ─── 颜色选项 ─────────────────────────────────────────────────

class _ColorOption extends ConsumerWidget {
  final Color color;
  const _ColorOption({required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isSelected = themeState.seedColor.value == color.value;

    return GestureDetector(
      onTap: () {
        ref.read(themeProvider.notifier).setSeedColor(color);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

// ─── 自定义色盘 ───────────────────────────────────────────────

class _CustomColorPicker extends ConsumerWidget {
  const _CustomColorPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isCustom =
        themeState.seedColor.value != const Color(0xFF9AD4EA).value;

    return GestureDetector(
      onTap: () => _showColorPickerDialog(context, ref),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isCustom
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: isCustom ? 2 : 1,
          ),
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF6B6B),
              Color(0xFFFFD93D),
              Color(0xFF6BCB77),
              Color(0xFF4D96FF),
              Color(0xFFC77DFF),
              Color(0xFFFF6B6B),
            ],
          ),
        ),
        child: isCustom
            ? Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: themeState.seedColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              )
            : const Icon(Icons.add, color: Colors.white, size: 18),
      ),
    );
  }

  Future<void> _showColorPickerDialog(
      BuildContext context, WidgetRef ref) async {
    final themeState = ref.read(themeProvider);
    double hue = HSLColor.fromColor(themeState.seedColor).hue;
    double saturation = HSLColor.fromColor(themeState.seedColor).saturation;
    double lightness = HSLColor.fromColor(themeState.seedColor).lightness;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final previewColor =
              HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
          return AlertDialog(
            title: const Text('自定义颜色'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: previewColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: previewColor.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('色相'),
                    Expanded(
                      child: Slider(
                        value: hue,
                        min: 0,
                        max: 360,
                        activeColor: previewColor,
                        onChanged: (v) => setDialogState(() => hue = v),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('饱和'),
                    Expanded(
                      child: Slider(
                        value: saturation,
                        min: 0,
                        max: 1,
                        activeColor: previewColor,
                        onChanged: (v) =>
                            setDialogState(() => saturation = v),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('明度'),
                    Expanded(
                      child: Slider(
                        value: lightness,
                        min: 0.2,
                        max: 0.9,
                        activeColor: previewColor,
                        onChanged: (v) =>
                            setDialogState(() => lightness = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t.common.cancel),
              ),
              FilledButton(
                onPressed: () {
                  ref.read(themeProvider.notifier).setSeedColor(previewColor);
                  Navigator.pop(ctx);
                },
                child: Text(t.common.save),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── 语言选择器 ───────────────────────────────────────────────

class _LanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _LanguageChip(locale: null),
        _LanguageChip(locale: AppLocale.zh),
        _LanguageChip(locale: AppLocale.zhTw),
        _LanguageChip(locale: AppLocale.en),
        _LanguageChip(locale: AppLocale.ja),
      ],
    );
  }
}

class _LanguageChip extends ConsumerWidget {
  final AppLocale? locale;
  const _LanguageChip({this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isSelected = currentLocale == locale;

    return ChoiceChip(
      label: Text(AppearanceSettingsCard._getLanguageText(locale)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(localeProvider.notifier).setLocale(locale);
        }
      },
    );
  }
}
