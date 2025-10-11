import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_widgets.dart';
import '../application/auth_controller.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _displayName = TextEditingController();
  final _zip = TextEditingController();
  // Loading derived from provider
  // Removed unused agree flag to keep lints clean; reintroduce when adding terms checkbox

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _displayName.dispose();
    _zip.dispose();
    super.dispose();
  }

  String? _passwordRule(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  // Legacy mock submit removed; live flow handled by auth controller

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.loading;

    ref.listen(authControllerProvider, (prev, next) {
      final error = next.error;
      if (error != null && error.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    });
    return AuthScaffold(
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(subtitle: 'Create your account'),
              const SizedBox(height: 32),
              TextFormField(
                controller: _displayName,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 16,
                  letterSpacing: -0.3,
                  inherit: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'John Doe',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 22),
                ),
              ),
              const SizedBox(height: 16),
              EmailField(controller: _email),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Create password',
                hint: 'At least 8 characters',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                style: const TextStyle(
                  fontSize: 16,
                  letterSpacing: -0.3,
                  inherit: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  hintText: '••••••••',
                  prefixIcon: Icon(Icons.lock_reset_rounded, size: 22),
                ),
                validator: (v) {
                  final base = _passwordRule(_password.text);
                  if (base != null) return base;
                  if (v != _password.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _zip,
                style: const TextStyle(
                  fontSize: 16,
                  letterSpacing: -0.3,
                  inherit: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ZIP code (optional)',
                  hintText: '12345',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 22),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signUp(
                          context,
                          email: _email.text,
                          password: _password.text,
                          displayName: _displayName.text,
                          zip: _zip.text,
                        ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  TextButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (!mounted) return;
                        final popped = await Navigator.of(context).maybePop();
                        if (!popped && mounted) context.go('/login');
                      });
                    },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
