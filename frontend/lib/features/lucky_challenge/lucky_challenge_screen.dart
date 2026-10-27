
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/at_button.dart';
import 'lucky_challenge_api.dart';

class LuckyChallengeScreen extends StatefulWidget {
  const LuckyChallengeScreen({super.key});

  @override
  State<LuckyChallengeScreen> createState() => _LuckyChallengeScreenState();
}

class _LuckyChallengeScreenState extends State<LuckyChallengeScreen> {

  late final LuckyChallengeApi api;
  final ImagePicker picker = ImagePicker();

  Map<String, dynamic>? challenge;

  String selectedDifficulty = 'MEDIUM';
  String? message;

  bool loading = false;
  bool checking = true;

  @override
  void initState() {
    super.initState();
    api = LuckyChallengeApi(context.read<ApiClient>());
    loadChallenge();
  }

  Future<void> loadChallenge() async {
    setState(() => checking = true);

    try {
      final result = await api.getMyChallenge();

      if (!mounted) return;

      setState(() {
        challenge = result;
        selectedDifficulty = result['difficulty']?.toString() ?? 'MEDIUM';
        checking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        challenge = null;
        checking = false;
      });
    }
  }

  Future<void> randomChallenge() async {
    if (loading) return;

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final result = await api.randomChallenge(selectedDifficulty);

      if (!mounted) return;

      setState(() {
        challenge = result;
        selectedDifficulty =
            result['difficulty']?.toString() ?? selectedDifficulty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> acceptChallenge() async {
    if (loading || challenge == null) return;

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final id = (challenge!['id'] as num).toInt();

      await api.acceptChallenge(id);

      if (!mounted) return;

      setState(() {
        challenge!['status'] = 'ACCEPTED';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submitProof() async {
    if (loading || challenge == null) return;

    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null || !mounted) return;

      setState(() {
        loading = true;
        message = null;
      });

      final bytes = await image.readAsBytes();
      final isPng = image.name.toLowerCase().endsWith('.png');
      final mimeType = isPng ? 'image/png' : 'image/jpeg';

      final proofImage = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final id = (challenge!['id'] as num).toInt();
      final result = await api.submitProof(id, proofImage);

      if (!mounted) return;

      final updated = await api.getMyChallenge();

      if (!mounted) return;

      setState(() {
        challenge = updated;
        message = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String difficultyName(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return 'سهل';
      case 'HARD':
        return 'صعب';
      default:
        return 'متوسط';
    }
  }

  int difficultyPoints(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return 10;
      case 'HARD':
        return 30;
      default:
        return 20;
    }
  }

  Widget difficultyOption(
      String difficulty,
      String title,
      int points,
      IconData icon,
      ) {
    final c = context.colors;
    final selected = selectedDifficulty == difficulty;
    final disabled = challenge != null || loading;

    return Expanded(
      child: InkWell(
        onTap: disabled
            ? null
            : () {
          setState(() {
            selectedDifficulty = difficulty;
          });
        },
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AnimatedContainer(
          duration: Motion.base,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s2,
            vertical: Space.s5,
          ),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected ? c.primary : c.lineStrong,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? c.primary : c.inkMuted,
              ),
              const SizedBox(height: Space.s3),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? c.primary : c.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Space.s1),
              Text(
                '$points نقطة',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? c.primary : c.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoMessage(String value) {
    final c = context.colors;

    return AppCard(
      color: c.primarySoft,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: c.primary),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget attemptsIndicator(int attempts) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المحاولات المستخدمة: $attempts من 3',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: c.inkMuted,
          ),
        ),
        const SizedBox(height: Space.s2),
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                decoration: BoxDecoration(
                  color: index < attempts ? c.primary : c.primarySoft,                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget challengeCard(
      String status,
      int attempts,
      int points,
      ) {
    final c = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.casino_outlined,
                color: c.primary,
                size: 26,
              ),
              const SizedBox(width: Space.s2),
              Expanded(
                child: Text(
                  'تحدي اليوم',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s3,
                  vertical: Space.s2,
                ),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text(
                  '$points نقطة',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: Space.s6),

          Text(
            challenge?['title']?.toString() ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: c.ink,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: Space.s6),

          attemptsIndicator(attempts),

          const SizedBox(height: Space.s6),

          if (status == 'OFFERED') ...[
            AtButton(
              'أقبل التحدي',
              onPressed: loading ? null : acceptChallenge,
              loading: loading,
              icon: const Icon(Icons.check_circle_outline),
            ),
            const SizedBox(height: Space.s3),
            AtButton(
              attempts >= 3
                  ? 'انتهت المحاولات'
                  : 'غيّر التحدي (${3 - attempts} متبقية)',
              kind: AtButtonKind.outline,
              onPressed: loading || attempts >= 3
                  ? null
                  : randomChallenge,
              icon: const Icon(Icons.refresh),
            ),
          ],

          if (status == 'ACCEPTED')
            AtButton(
              'ارفع الإثبات',
              onPressed: loading ? null : submitProof,
              loading: loading,
              icon: const Icon(Icons.camera_alt_outlined),
            ),

          if (status == 'COMPLETED') ...[
            Icon(
              Icons.verified_outlined,
              color: c.primary,
              size: 54,
            ),
            const SizedBox(height: Space.s3),
            Text(
              'أحسنت! أكملت تحدي اليوم',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: c.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Space.s2),
            Text(
              'حصلت على $points نقطة',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],

          if (status == 'REJECTED')
            const Text(
              'لم يتم قبول الإثبات لهذا التحدي.',
              textAlign: TextAlign.center,
            ),

          if (status == 'ESCALATED')
            const Text(
              'الذكاء الاصطناعي لم يتمكن من التأكد من الإثبات.',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final status = challenge?['status']?.toString() ?? '';
    final attempts = (challenge?['attempts'] as num?)?.toInt() ?? 0;

    final currentDifficulty =
        challenge?['difficulty']?.toString() ?? selectedDifficulty;

    final points =
        (challenge?['points'] as num?)?.toInt() ??
            difficultyPoints(currentDifficulty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحدي الحظ'),
        centerTitle: true,
      ),
      body: checking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              color: c.primarySoft,
              child: Column(
                children: [
                  Icon(
                    Icons.casino_outlined,
                    color: c.primary,
                    size: 44,
                  ),
                  const SizedBox(height: Space.s3),
                  Text(
                    'تحدي الحظ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                  Text(
                    'اختر صعوبة التحدي، أنجز المهمة، وارفع صورة الإثبات لتحصل على نقاط.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.inkMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Space.s6),

            Text(
              'مستوى الصعوبة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: Space.s3),

            Row(
              children: [
                difficultyOption(
                  'EASY',
                  'سهل',
                  10,
                  Icons.sentiment_satisfied_alt_outlined,
                ),
                const SizedBox(width: Space.s2),
                difficultyOption(
                  'MEDIUM',
                  'متوسط',
                  20,
                  Icons.local_fire_department_outlined,
                ),
                const SizedBox(width: Space.s2),
                difficultyOption(
                  'HARD',
                  'صعب',
                  30,
                  Icons.bolt_outlined,
                ),
              ],
            ),

            const SizedBox(height: Space.s3),

            Text(
              challenge == null
                  ? 'اختر الصعوبة قبل توليد التحدي. لا يمكن تغييرها بعد أول محاولة.'
                  : 'الصعوبة المختارة: ${difficultyName(currentDifficulty)} — $points نقطة',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.inkMuted,
              ),
            ),

            const SizedBox(height: Space.s6),

            if (challenge == null)
              AppCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      color: c.primary,
                      size: 38,
                    ),
                    const SizedBox(height: Space.s3),
                    Text(
                      'مستعد لتحدي اليوم؟',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Space.s2),
                    Text(
                      'عندك 3 فرص للحصول على التحدي المناسب لك.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                    const SizedBox(height: Space.s5),
                    AtButton(
                      'فاجئني',
                      onPressed: loading ? null : randomChallenge,
                      loading: loading,
                      icon: const Icon(Icons.casino_outlined),
                    ),
                  ],
                ),
              )
            else
              challengeCard(status, attempts, points),

            if (loading) ...[
              const SizedBox(height: Space.s5),
              const Center(child: CircularProgressIndicator()),
            ],

            if (message != null) ...[
              const SizedBox(height: Space.s5),
              infoMessage(message!),
            ],

            const SizedBox(height: Space.s8),

            Text(
              'تحدٍّ واحد يوميًا • 3 فرص للاختيار • بدون غرامات مالية',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
