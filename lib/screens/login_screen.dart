
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../services/auth_service.dart";
import "../theme.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _handleSubmit() async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Navigation remains handled by authStateChanges() in main.dart.
    } on FirebaseAuthException {
      if (mounted) {
        setState(() {
          _error = "Couldn't sign in. Check your email and password.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 40 : 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: isWide
                      ? Row(
                          children: [
                            const Expanded(
                              child: _LoginWelcomePanel(),
                            ),
                            const SizedBox(width: 48),
                            Expanded(
                              child: _buildLoginCard(),
                            ),
                          ],
                        )
                      : _buildLoginCard(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(28),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: AppColors.accentIndigo.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accentIndigo.withOpacity(0.30),
              ),
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              color: AppColors.accentIndigoHover,
              size: 29,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            "Welcome back",
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Sign in to monitor your solar system and manage your devices.",
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 30),

          const _FieldLabel("Email address"),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: _inputDecoration(
              hint: "you@example.com",
              icon: Icons.mail_outline_rounded,
            ),
          ),

          const SizedBox(height: 20),
          const _FieldLabel("Password"),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _handleSubmit(),
            decoration: _inputDecoration(
              hint: "Enter your password",
              icon: Icons.lock_outline_rounded,
            ).copyWith(
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? "Show password"
                    : "Hide password",
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.offline.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.offline.withOpacity(0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.offline,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.offline,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentIndigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.accentIndigo.withOpacity(0.55),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 19,
                          width: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text("Signing in..."),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Secure access to your solar dashboard",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: AppColors.textMuted,
      ),
      filled: true,
      fillColor: AppColors.sidebarBg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.panelBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.panelBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.accentIndigo,
          width: 1.5,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LoginWelcomePanel extends StatelessWidget {
  const _LoginWelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentIndigo.withOpacity(0.17),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                color: AppColors.accentIndigoHover,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              "SolarIoT",
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        const Text(
          "Your energy.\nUnder control.",
          style: TextStyle(
            fontSize: 43,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.6,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Monitor solar performance, track energy trends, "
          "and manage connected devices from one place.",
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 16,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 34),
        const _FeatureRow(
          icon: Icons.bolt_rounded,
          title: "Live solar monitoring",
          description: "Keep an eye on voltage and current.",
        ),
        const SizedBox(height: 20),
        const _FeatureRow(
          icon: Icons.show_chart_rounded,
          title: "Energy insights",
          description: "Understand your system's performance.",
        ),
        const SizedBox(height: 20),
        const _FeatureRow(
          icon: Icons.devices_rounded,
          title: "Device management",
          description: "Monitor and control connected circuits.",
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.panelBorder),
          ),
          child: Icon(
            icon,
            color: AppColors.accentIndigoHover,
            size: 21,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
