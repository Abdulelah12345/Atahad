
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/at_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool loading = false;
  bool showPassword = false;

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      await context.read<AuthState>().register(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      context.go('/');

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذر إنشاء الحساب، تأكد من بياناتك وحاول مرة ثانية'),
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
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
                      child: AppLogo(width: 150, tagline: true),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'إنشاء حساب',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'ابدأ رحلتك مع أتعهد وحقق أهدافك',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text('الاسم', style: Theme.of(context).textTheme.labelLarge),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'أدخل اسمك',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل اسمك';
                        }
                        if (value.trim().length > 50) {
                          return 'الاسم يجب ألا يتجاوز 50 حرف';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    Text('البريد الإلكتروني', style: Theme.of(context).textTheme.labelLarge),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'example@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل البريد الإلكتروني';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                          return 'البريد الإلكتروني غير صحيح';
                        }
                        if (value.trim().length > 100) {
                          return 'البريد الإلكتروني طويل جدًا';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    Text('رقم الجوال', style: Theme.of(context).textTheme.labelLarge),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: '+966501234567',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل رقم الجوال';
                        }
                        if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value.trim())) {
                          return 'أدخل الرقم بالصيغة الدولية مثل +966501234567';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    Text('كلمة المرور', style: Theme.of(context).textTheme.labelLarge),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: '8 أحرف على الأقل',
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
                        if (value.length < 8) {
                          return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    Text('تأكيد كلمة المرور', style: Theme.of(context).textTheme.labelLarge),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: !showPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => register(),
                      decoration: const InputDecoration(
                        hintText: 'أعد إدخال كلمة المرور',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'أكّد كلمة المرور';
                        }
                        if (value != passwordController.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    AtButton(
                      'إنشاء حساب',
                      loading: loading,
                      onPressed: loading ? null : register,
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'عندك حساب؟',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('تسجيل الدخول'),
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
