
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/at_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool loading = false;
  bool showPassword = false;

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      await context.read<AuthState>().login(
        emailController.text,
        passwordController.text,
      );

      if (!mounted) return;

      final auth = context.read<AuthState>();
      context.go(auth.isAdmin ? '/admin' : '/');

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // status 0 = the app did not reach the backend (it is off, restarting, or another network): say that, not "check your data"
          content: Text(e is ApiException && e.status == 0
              ? 'ما قدرنا نوصل للسيرفر. تأكد إن الباك شغّال وإن الجوال على نفس الشبكة.'
              : 'تعذر تسجيل الدخول، تأكد من بياناتك وحاول مرة ثانية'),
          backgroundColor: context.colors.danger,
        ),
      );

    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    const Center(
                      child: AppLogo(width: 170, tagline: true),
                    ),

                    const SizedBox(height: 40),

                    Text(
                      'تسجيل الدخول',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'أهلًا بعودتك، كمل تعهداتك معنا',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'البريد الإلكتروني',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        hintText: 'example@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل البريد الإلكتروني';
                        }

                        if (!value.contains('@')) {
                          return 'البريد الإلكتروني غير صحيح';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'كلمة المرور',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        hintText: 'أدخل كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'أدخل كلمة المرور';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    AtButton(
                      'تسجيل الدخول',
                      loading: loading,
                      onPressed: loading ? null : login,
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ما عندك حساب؟',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),

                        TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('إنشاء حساب'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
