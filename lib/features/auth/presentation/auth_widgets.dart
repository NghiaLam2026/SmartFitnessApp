import 'package:flutter/material.dart';

/// App logo + title used on both screens
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.subtitle});
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Modern gradient icon container
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Smart Fitness',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              letterSpacing: -0.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]
      ],
    );
  }
}

/// Consistent page scaffold with centered, responsive card
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.showBackButton = false,
  });
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).maybePop();
                    }
                  });
                },
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final max = c.maxWidth;
            final cardWidth = max < 600 ? max - 32 : 440.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                vertical: showBackButton ? 8 : 32,
                horizontal: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints.tightFor(width: cardWidth),
                  child: Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shadowColor: Colors.black.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          child,
                          const SizedBox(height: 24),
                          Text(
                            'By continuing you agree to our Terms & Privacy.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              letterSpacing: -0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Reusable email field with simple validation
class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      style: const TextStyle(
        fontSize: 16,
        letterSpacing: -0.3,
        inherit: true,
      ),
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'your@email.com',
        prefixIcon: Icon(Icons.mail_outline_rounded, size: 22),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Email is required';
        final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
        return ok ? null : 'Enter a valid email';
      },
    );
  }
}

/// Password field with show/hide toggle
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: const [AutofillHints.password],
      style: const TextStyle(
        fontSize: 16,
        letterSpacing: -0.3,
        inherit: true,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? '••••••••',
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 22,
          ),
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
    );
  }
}
