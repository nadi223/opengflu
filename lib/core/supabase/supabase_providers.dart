import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// المستخدم الحالي؛ يُعاد بناؤه عند تسجيل الدخول أو الخروج.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// لا يظهر أي أثر للوحة المالك إلا إذا أعاد الـ view المسمى my_admin_status صفاً.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  try {
    final row = await ref
        .watch(supabaseClientProvider)
        .from('my_admin_status')
        .select()
        .maybeSingle();
    return row != null;
  } catch (_) {
    return false;
  }
});
