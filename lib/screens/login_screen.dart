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
  String? _error;

  Future<void> _handleSubmit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _authService.login(_emailController.text.trim(), _passwordController.text);
      // Navigation happens automatically via the authStateChanges() stream in main.dart
    } on FirebaseAuthException {
      setState(() => _error = "Couldn't sign in - check your email and password.");
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: panelDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("☀️", style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("SolarIoT", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text("Sign in to view your dashboard",
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: "Email"),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: "Password"),
                    onSubmitted: (_) => _handleSubmit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.offline)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSubmit,
                      child: Text(_submitting ? "Signing in..." : "Sign In"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
