import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_navigation.dart';
import '../../auth/auth_repository.dart';

String _soon(BuildContext context, String titleKey) =>
    '/soon?title=${Uri.encodeComponent(context.tr(titleKey))}';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  /// تُلتقط كل القيم قبل إغلاق الدرج، فلا نستخدم context أو ref بعد إزالته.
  void _go(
    BuildContext context,
    WidgetRef ref,
    String target, {
    bool needsLogin = false,
  }) {
    final router = GoRouter.of(context);
    final loggedIn = ref.read(currentUserProvider) != null;
    Navigator.of(context).pop();
    if (needsLogin && !loggedIn) {
      router.push(loginLocation(from: target));
      return;
    }
    router.push(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim();
    final subtitle = user?.email ?? user?.phone ?? '';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppColors.ink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.door_front_door_outlined,
                    color: AppColors.gold,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user == null
                        ? context.tr('menu_guest')
                        : (name == null || name.isEmpty ? subtitle : name),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user == null ? context.tr('menu_guest_hint') : subtitle,
                    style: const TextStyle(color: Color(0xFFD9D2BE), fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(context.tr('menu_add_listing')),
                    onTap: () => _go(
                      context,
                      ref,
                      _soon(context, 'menu_add_listing'),
                      needsLogin: true,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_border),
                    title: Text(context.tr('menu_favorites')),
                    onTap: () => _go(
                      context,
                      ref,
                      _soon(context, 'menu_favorites'),
                      needsLogin: true,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(context.tr('menu_chats')),
                    onTap: () => _go(
                      context,
                      ref,
                      _soon(context, 'menu_chats'),
                      needsLogin: true,
                    ),
                  ),
                  // لوحة المالك: لا أثر لها عند غير المسؤولين.
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(context.tr('menu_admin')),
                      onTap: () => _go(context, ref, _soon(context, 'menu_admin')),
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.tr('settings')),
                    onTap: () => _go(context, ref, '/settings'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (user == null)
              ListTile(
                leading: const Icon(Icons.login),
                title: Text(context.tr('menu_login')),
                onTap: () => _go(context, ref, loginLocation()),
              )
            else
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(context.tr('menu_logout')),
                onTap: () {
                  final repo = ref.read(authRepositoryProvider);
                  Navigator.of(context).pop();
                  repo.signOut();
                },
              ),
          ],
        ),
      ),
    );
  }
}
