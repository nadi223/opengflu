import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_store.dart';

const String _kTheme = 'settings.theme';
const String _kColumns = 'settings.grid_columns';
const String _kNotifications = 'settings.notifications';
const String _kLocale = 'settings.locale';

class SettingsState {
  const SettingsState({
    required this.themeMode,
    required this.gridColumns,
    required this.notificationsEnabled,
    required this.localeCode,
  });

  final ThemeMode themeMode;
  final int gridColumns;
  final bool notificationsEnabled;
  final String localeCode;

  SettingsState copyWith({
    ThemeMode? themeMode,
    int? gridColumns,
    bool? notificationsEnabled,
    String? localeCode,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      gridColumns: gridColumns ?? this.gridColumns,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      localeCode: localeCode ?? this.localeCode,
    );
  }
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeName = prefs.getString(_kTheme);
    final columns = prefs.getInt(_kColumns);
    return SettingsState(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      gridColumns: (columns == 3) ? 3 : 2,
      notificationsEnabled: prefs.getBool(_kNotifications) ?? true,
      localeCode: prefs.getString(_kLocale) == 'en' ? 'en' : 'ar',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_kTheme, mode.name);
  }

  Future<void> setGridColumns(int columns) async {
    state = state.copyWith(gridColumns: columns);
    await ref.read(sharedPreferencesProvider).setInt(_kColumns, columns);
  }

  Future<void> setNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await ref.read(sharedPreferencesProvider).setBool(_kNotifications, enabled);
  }

  Future<void> setLocale(String code) async {
    state = state.copyWith(localeCode: code);
    await ref.read(sharedPreferencesProvider).setString(_kLocale, code);
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);
