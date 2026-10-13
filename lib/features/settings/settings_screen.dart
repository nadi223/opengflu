import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: context.tr('theme'),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(context.tr('theme_dark')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(context.tr('theme_light')),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(context.tr('theme_system')),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => controller.setThemeMode(s.first),
            ),
          ),
          _Section(
            title: context.tr('grid_columns'),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {settings.gridColumns},
              onSelectionChanged: (s) => controller.setGridColumns(s.first),
            ),
          ),
          _Section(
            title: context.tr('language'),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ar', label: Text(context.tr('arabic'))),
                ButtonSegment(value: 'en', label: Text(context.tr('english'))),
              ],
              selected: {settings.localeCode},
              onSelectionChanged: (s) => controller.setLocale(s.first),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('notifications')),
            value: settings.notificationsEnabled,
            onChanged: controller.setNotifications,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
