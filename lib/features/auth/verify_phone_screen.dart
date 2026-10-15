import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/strings.dart';
import 'auth_form_widgets.dart';
import 'auth_navigation.dart';
import 'auth_repository.dart';

class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key, required this.phone, this.from});

  final String phone;
  final String? from;

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4) {
      setState(() => _error = context.tr('err_required'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyPhone(widget.phone, _code.text);
      if (!mounted) return;
      finishAuth(context, widget.from);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendPhoneCode(widget.phone);
      if (mounted) setState(() => _info = context.tr('code_resent'));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('verify_title'),
      children: [
        Text(context.tr('verify_hint')),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(widget.phone, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, letterSpacing: 6),
          decoration: InputDecoration(
            labelText: context.tr('verify_code'),
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        ErrorText(_error),
        if (_info != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_info!),
          ),
        FilledButton(
          onPressed: _loading ? null : _verify,
          child: LoadingLabel(loading: _loading, label: context.tr('verify_btn')),
        ),
        TextButton(onPressed: _resend, child: Text(context.tr('resend_code'))),
      ],
    );
  }
}
