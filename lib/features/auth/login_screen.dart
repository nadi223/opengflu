import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/format/phone.dart';
import '../../core/l10n/strings.dart';
import '../home/data/home_providers.dart';
import 'auth_form_widgets.dart';
import 'auth_navigation.dart';
import 'auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _phoneMode = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_phoneMode) {
        await repo.signInWithPhone(normalizePhone(_identifier.text)!, _password.text);
      } else {
        await repo.signInWithEmail(_identifier.text, _password.text);
      }
      if (!mounted) return;
      finishAuth(context, widget.from);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneEnabled = ref.watch(appConfigProvider).value?.phoneAuthEnabled == true;

    return AuthScaffold(
      title: context.tr('login_title'),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (phoneEnabled) ...[
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(context.tr('by_email'))),
                    ButtonSegment(value: true, label: Text(context.tr('by_phone'))),
                  ],
                  selected: {_phoneMode},
                  onSelectionChanged: (s) => setState(() {
                    _phoneMode = s.first;
                    _identifier.clear();
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _identifier,
                keyboardType: _phoneMode ? TextInputType.phone : TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: [_phoneMode ? AutofillHints.telephoneNumber : AutofillHints.email],
                decoration: InputDecoration(
                  labelText: context.tr(_phoneMode ? 'phone' : 'email'),
                  hintText: _phoneMode ? context.tr('phone_hint') : null,
                  prefixIcon: Icon(_phoneMode ? Icons.phone_outlined : Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (_phoneMode) {
                    return normalizePhone(value) == null ? context.tr('err_phone') : null;
                  }
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail(value))
                      ? null
                      : context.tr('err_email');
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: context.tr('password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty ? context.tr('err_required') : null,
              ),
              const SizedBox(height: 18),
              ErrorText(_error),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: LoadingLabel(loading: _loading, label: context.tr('login_btn')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push(registerLocation(from: widget.from)),
                child: Text(context.tr('no_account')),
              ),
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(context.tr('continue_guest')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
