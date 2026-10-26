import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/widgets.dart';

// OWNER: Subhiyyah - a simple version (GET /commitment/lockStatus)
// the member donates by himself to Ehsan, then proves it (screenshots or the bank email), the app opens again
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: AsyncView<Map<String, dynamic>>(
          load: () async => Map<String, dynamic>.from(
            await api.get('/api/v1/commitment/lockStatus') as Map,
          ),
          builder: (context, status, reload) {
            final penalties = (status['penalties'] as List?) ?? const [];
            return ListView(
              padding: const EdgeInsets.all(Space.s6),
              children: [
                const SizedBox(height: Space.s8),
                Text(
                  'فاتك كم يوم',
                  style: text.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.s2),
                Text(
                  'تبرّع لمنصة إحسان بالمبلغ، وأثبت التبرع، ويرجع التطبيق ينفتح.',
                  style: text.bodyMedium!.copyWith(color: c.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.s6),
                Center(
                  child: RiyalAmount(
                    status['totalToDonate'] as num?,
                    style: text.displayLarge,
                  ),
                ),
                const SizedBox(height: Space.s6),
                for (final p in penalties)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s2),
                    child: AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${(p as Map)['commitmentTitle'] ?? ''}',
                              style: text.labelLarge,
                            ),
                          ),
                          RiyalAmount(p['amount'] as num?),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Space.s6),
                AtButton(
                  'تبرّعت',
                  kind: AtButtonKind.gold,
                  onPressed: () => context.push('/proofs/donations'),
                ),
                const SizedBox(height: Space.s3),
                AtButton(
                  'عندي عذر',
                  kind: AtButtonKind.outline,
                  onPressed: () => context.push('/requests'),
                ),
                const SizedBox(height: Space.s3),
                AtButton(
                  'تسجيل الخروج',
                  kind: AtButtonKind.text,
                  onPressed: () => context.read<AuthState>().logout(),
                ),
                const SizedBox(height: Space.s3),
                AtButton(
                  'متابعة تعهّد المشي',
                  kind: AtButtonKind.text,
                  onPressed: () => context.push('/walking'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
