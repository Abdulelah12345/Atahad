
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/widgets/at_button.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool loading = false;
  bool showInitialData = false;
  String originalEmail = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!showInitialData) {
      final profile = context.read<AuthState>().profile ?? {};

      nameController.text = profile['name']?.toString() ?? '';
      emailController.text = profile['email']?.toString() ?? '';
      phoneController.text = profile['phone']?.toString() ?? '';

      originalEmail = emailController.text.trim().toLowerCase();
      showInitialData = true;
    }
  }

  Future<void> updateProfile() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      final auth = context.read<AuthState>();
      final memberId = auth.userId;

      if (memberId == null) {
        throw Exception('Member ID not found');
      }

      final email = emailController.text.trim().toLowerCase();

      await auth.api.put(
        '/api/v1/member/update/$memberId',
        body: {
          'name': nameController.text.trim(),
          'email': email,
          'phone': phoneController.text.trim(),
        },
      );

      if (!mounted) return;

      if (email != originalEmail) {
        await auth.logout(callServer: false);
        return;
      }

      await auth.refreshProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الملف الشخصي بنجاح'),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث الملف الشخصي: $e'),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
      ),
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
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: colors.primary.withOpacity(0.12),
                      child: Icon(
                        Icons.person_outline,
                        size: 44,
                        color: colors.primary,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'تحديث بياناتك',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'عدّل معلوماتك الشخصية واحفظ التغييرات',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      'الاسم',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),

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

                    const SizedBox(height: 22),

                    Text(
                      'البريد الإلكتروني',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),

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
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value.trim())) {
                          return 'البريد الإلكتروني غير صحيح';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'رقم الجوال',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: '+966501234567',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل رقم الجوال';
                        }
                        if (!RegExp(r'^\+[1-9]\d{7,14}$')
                            .hasMatch(value.trim())) {
                          return 'أدخل الرقم بالصيغة الدولية مثل +966501234567';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'إذا غيّرت البريد الإلكتروني، ستحتاج لتسجيل الدخول من جديد.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),

                    const SizedBox(height: 32),

                    AtButton(
                      'حفظ التغييرات',
                      loading: loading,
                      onPressed: loading ? null : updateProfile,
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: loading ? null : () => context.pop(),
                      child: const Text('إلغاء'),
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
