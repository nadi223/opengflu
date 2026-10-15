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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _phoneMode = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final phone = _phone.text.trim().isEmpty ? null : normalizePhone(_phone.text);

      if (_phoneMode) {
        final started = await repo.signUpWithPhone(
          e164Phone: phone!,
          password: _password.text,
          fullName: _name.text,
        );
        if (!mounted) return;
        if (started) {
          finishAuth(context, widget.from);
        } else {
          context.push(verifyPhoneLocation(phone: phone, from: widget.from));
        }
      } else {
        final started = await repo.signUpWithEmail(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          e164Phone: phone,
        );
        if (!mounted) return;
        if (started) {
          finishAuth(context, widget.from);
        } else {
          setState(() => _info = context.tr('confirm_email_sent'));
        }
      }
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
      title: context.tr('register_title'),
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
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: context.tr('full_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().length < 2 ? context.tr('err_name') : null,
              ),
              const SizedBox(height: 14),
              if (!_phoneMode) ...[
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: context.tr('email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail(v ?? ''))
                      ? null
                      : context.tr('err_email'),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: context.tr(_phoneMode ? 'phone' : 'phone_optional'),
                  hintText: context.tr('phone_hint'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) {
                    return _phoneMode ? context.tr('err_phone') : null;
                  }
                  return normalizePhone(value) == null ? context.tr('err_phone') : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: context.tr('password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').length < 8 ? context.tr('err_password') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: context.tr('confirm_password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v != _password.text ? context.tr('err_password_match') : null,
              ),
              const SizedBox(height: 18),
              ErrorText(_error),
              if (_info != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_info!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: LoadingLabel(loading: _loading, label: context.tr('register_btn')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(loginLocation(from: widget.from)),
                child: Text(context.tr('have_account')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
