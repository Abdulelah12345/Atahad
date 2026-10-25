
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/theme_state.dart';

// OWNER: Abdulelah - the "حسابي" tab (empty for now)
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final profile = auth.profile ?? {};
    final colors = context.colors;

    final name = profile['name']?.toString() ?? '-';
    final email = profile['email']?.toString() ?? '-';
    final phone = profile['phone']?.toString() ?? '-';
    final plan = profile['plan']?.toString() ?? '-';
    final level = profile['level']?.toString() ?? '-';
    final points = profile['taskPoints']?.toString() ?? '0';
    final weeks = profile['consecutiveWeeks']?.toString() ?? '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: auth.refreshProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 16),

            CircleAvatar(
              radius: 42,
              backgroundColor: colors.primary.withOpacity(0.12),
              child: Icon(
                Icons.person_outline,
                size: 45,
                color: colors.primary,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 6),

            Text(
              email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.inkMuted,
              ),
            ),

            const SizedBox(height: 30),

            _sectionTitle(context, 'المعلومات الشخصية'),

            _infoTile(Icons.person_outline, 'الاسم', name),
            _infoTile(Icons.email_outlined, 'البريد الإلكتروني', email),
            _infoTile(Icons.phone_outlined, 'رقم الجوال', phone),

            const SizedBox(height: 24),

            if (auth.isMember) ...[
              _sectionTitle(context, 'الاشتراك والإنجازات'),

              _infoTile(
                Icons.workspace_premium_outlined,
                'نوع الاشتراك',
                plan,
              ),
              _infoTile(
                Icons.military_tech_outlined,
                'المستوى',
                level,
              ),
              _infoTile(
                Icons.stars_outlined,
                'النقاط',
                points,
              ),
              _infoTile(
                Icons.local_fire_department_outlined,
                'الأسابيع المتتالية',
                weeks,
              ),

              const SizedBox(height: 24),
            ],

            _sectionTitle(context, 'المظهر'),

            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('فاتح')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('داكن')),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android_outlined), label: Text('مثل الجوال')),
              ],
              selected: {context.watch<ThemeState>().mode},
              showSelectedIcon: false,
              onSelectionChanged: (selected) => context.read<ThemeState>().setMode(selected.first),
            ),

            const SizedBox(height: 24),

            _sectionTitle(context, 'إعدادات الحساب'),

            _actionTile(
              Icons.edit_outlined,
              'تعديل الملف الشخصي',
                  () {
                context.push('/update-profile');
              },
            ),

            _actionTile(
              Icons.calendar_month_outlined,
              'Google Calendar',
                  () {
                context.push('/google-calendar');
              },
            ),

            if (auth.isMember)
              _actionTile(
                Icons.person_off_outlined,
                'تعطيل الحساب',
                    () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('بنضيف تعطيل الحساب قريبًا'),
                    ),
                  );
                },
              ),

            const SizedBox(height: 14),

            _actionTile(
              Icons.logout,
              'تسجيل الخروج',
                  () async {
                await context.read<AuthState>().logout();
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget _actionTile(
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
