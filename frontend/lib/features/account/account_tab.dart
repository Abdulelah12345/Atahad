import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/state/data_refresh.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/theme/theme_state.dart';
import '../../core/widgets/app_card.dart';

// OWNER: Abdulelah - the "حسابي" tab
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final profile = auth.profile ?? {};
    final c = context.colors;
    final themeMode = context.watch<ThemeState>().mode;

    final name = profile['name']?.toString() ?? '-';
    final email = profile['email']?.toString() ?? '-';
    final phone = profile['phone']?.toString() ?? '-';
    final level = profile['level']?.toString() ?? '-';
    final points = (profile['points'] ?? profile['taskPoints'])?.toString() ?? '0';
    final weeks = profile['consecutiveWeeks']?.toString() ?? '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        centerTitle: true,
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'تغيير المظهر',
            initialValue: themeMode,
            onSelected: (mode) => context.read<ThemeState>().setMode(mode),
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.dark_mode_outlined
                  : themeMode == ThemeMode.light
                  ? Icons.light_mode_outlined
                  : Icons.brightness_auto_outlined,
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.light, child: Text('فاتح')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('داكن')),
              PopupMenuItem(value: ThemeMode.system, child: Text('حسب الجهاز')),
            ],
          ),
          const SizedBox(width: Space.s2),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: auth.refreshProfile,
        child: ListView(
          padding: const EdgeInsets.all(Space.s4),
          children: [
            const SizedBox(height: Space.s4),
            CircleAvatar(
              radius: 38,
              backgroundColor: c.primarySoft,
              child: Icon(Icons.person_outline, size: 40, color: c.primary),
            ),
            const SizedBox(height: Space.s3),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Space.s1),
            Text(
              'إدارة حسابك وإنجازاتك',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Space.s6),

            if (auth.isMember) ...[
              _sectionTitle(context, 'ملخص الإنجازات'),
              Row(
                children: [
                  _summaryCard(context, Icons.stars_outlined, points, 'النقاط'),
                  const SizedBox(width: Space.s2),
                  _summaryCard(context, Icons.military_tech_outlined, level, 'المستوى'),
                  const SizedBox(width: Space.s2),
                  _summaryCard(context, Icons.local_fire_department_outlined, weeks, 'أسابيع متتالية'),
                ],
              ),
              const SizedBox(height: Space.s4),
              AppCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: Icon(Icons.grid_view_rounded, color: c.primary),
                  title: const Text('خريطة الإنجازات'),
                  subtitle: const Text('اضغط لاستعراض نشاطك وإحصائياتك'),
                  childrenPadding: const EdgeInsets.all(Space.s2),
                  children: const [_ActivityHeatmap()],
                ),
              ),
              const SizedBox(height: Space.s6),
            ],

            _sectionTitle(context, 'الملف الشخصي'),
            AppCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                leading: Icon(Icons.person_outline, color: c.primary),
                title: const Text('معلوماتي الشخصية'),
                subtitle: const Text('الاسم والبريد الإلكتروني ورقم الجوال'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
                children: [
                  _detailRow(context, 'الاسم', name),
                  _detailRow(context, 'البريد الإلكتروني', email),
                  _detailRow(context, 'رقم الجوال', phone),
                ],
              ),
            ),
            const SizedBox(height: Space.s3),
            _actionTile(context, Icons.edit_outlined, 'تعديل الملف الشخصي', () {
              context.push('/update-profile');
            }),
            const SizedBox(height: Space.s6),

            _sectionTitle(context, 'إعدادات الحساب'),
            _actionTile(context, Icons.calendar_month_outlined, 'Google Calendar', () {
              context.push('/google-calendar');
            }),
            if (auth.isMember) ...[
              const SizedBox(height: Space.s3),
              _actionTile(context, Icons.person_off_outlined, 'تعطيل الحساب', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('بنضيف تعطيل الحساب قريبًا')),
                );
              }),
            ],
            const SizedBox(height: Space.s3),
            _actionTile(context, Icons.logout, 'تسجيل الخروج', () async {
              await context.read<AuthState>().logout();
            }, destructive: true),
            const SizedBox(height: Space.s8),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _summaryCard(BuildContext context, IconData icon, String value, String label) {
    final c = context.colors;
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.s1, vertical: Space.s4),
        child: Column(
          children: [
            Icon(icon, color: c.primary, size: 24),
            const SizedBox(height: Space.s2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: Space.s1),
            Text(label, textAlign: TextAlign.center, maxLines: 2,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      child: Row(
        children: [
          SizedBox(width: 105, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.inkMuted))),
          const SizedBox(width: Space.s2),
          Expanded(child: Text(value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool destructive = false}) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: destructive ? Theme.of(context).colorScheme.error : c.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

// Commitment Heatmap
class _ActivityHeatmap extends StatefulWidget {
  const _ActivityHeatmap();

  @override
  State<_ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<_ActivityHeatmap> {
  bool _loading = true;
  bool _error = false;

  int _year = DateTime.now().year;

  Map<String, int> _activity = {};

  final ScrollController _scrollController = ScrollController();

  DateTime? _selectedDate;

  static const double _boxSize = 16;
  static const double _boxGap = 5;
  static const double _weekWidth = _boxSize + _boxGap;

  final List<String> _months = const [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  final List<String> _weekDays = const [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivity();
    });
    DataRefresh.instance.addListener(_quietLoad);
  }

  // a proof or a task done on another page: the map gets its new square without the spinner
  void _quietLoad() {
    if (!_loading && !_error) _loadActivity(silent: true);
  }

  @override
  void dispose() {
    DataRefresh.instance.removeListener(_quietLoad);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      final api = context.read<ApiClient>();

      final result = await api.get('/api/v1/member/activity-map');

      if (result is! List) {
        throw Exception('Invalid activity map response');
      }

      final Map<String, int> activity = {};
      int year = DateTime.now().year;

      for (final item in result) {
        if (item is! Map) continue;

        final date = item['date']?.toString();

        if (date == null) continue;

        final parsedDate = DateTime.tryParse(date);

        if (parsedDate == null) continue;

        year = parsedDate.year;

        final completed =
            int.tryParse(item['completed']?.toString() ?? '0') ?? 0;

        activity[date] = completed;
      }

      if (!mounted) return;

      setState(() {
        _activity = activity;
        _year = year;
        _selectedDate = null;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    } catch (e) {
      if (!mounted || silent) return; // a quiet reload keeps the map on screen

      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Color _activityColor(BuildContext context, int completed) {
    final primary = context.colors.primary;

    if (completed >= 4) return primary;
    if (completed == 3) return primary.withOpacity(0.75);
    if (completed == 2) return primary.withOpacity(0.50);
    if (completed == 1) return primary.withOpacity(0.25);

    return Theme.of(context).colorScheme.onSurface.withOpacity(0.09);
  }

  // New: calculate the longest achievement streak.
  int _longestStreak() {
    int longest = 0;
    int current = 0;

    final firstDay = DateTime(_year, 1, 1);
    final lastDay = DateTime(_year, 12, 31);

    for (
    DateTime date = firstDay;
    !date.isAfter(lastDay);
    date = date.add(const Duration(days: 1))
    ) {
      final completed = _activity[_dateKey(date)] ?? 0;

      if (completed > 0) {
        current++;

        if (current > longest) {
          longest = current;
        }
      } else {
        current = 0;
      }
    }

    return longest;
  }

  // New: improved interactive day square.
  Widget _dayBox(BuildContext context, DateTime date) {
    if (date.year != _year) {
      return const SizedBox(
        width: _boxSize,
        height: _boxSize,
      );
    }

    final dateString = _dateKey(date);
    final completed = _activity[dateString] ?? 0;

    final isSelected = _selectedDate != null &&
        _dateKey(_selectedDate!) == dateString;

    return Tooltip(
      message: '$dateString\nالإنجازات: $completed',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedDate = null;
            } else {
              _selectedDate = date;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _boxSize,
          height: _boxSize,
          decoration: BoxDecoration(
            color: _activityColor(context, completed),
            borderRadius: BorderRadius.circular(4),
            border: isSelected
                ? Border.all(
              color: context.colors.primary,
              width: 2,
            )
                : null,
          ),
        ),
      ),
    );
  }

  // New: month labels above the heatmap.
  Widget _buildMonthLabels(DateTime calendarStart, int totalWeeks) {
    int previousMonth = 0;

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          for (int week = 0; week < totalWeeks; week++)
            Builder(
              builder: (context) {
                final weekStart = calendarStart.add(
                  Duration(days: week * 7),
                );

                DateTime? monthStart;

                for (int day = 0; day < 7; day++) {
                  final date = weekStart.add(Duration(days: day));

                  if (date.year == _year && date.day == 1) {
                    monthStart = date;
                    break;
                  }
                }

                final month = monthStart?.month;

                String label = '';

                if (month != null && month != previousMonth) {
                  previousMonth = month;
                  label = _months[month - 1];
                }

                return SizedBox(
                  width: _weekWidth,
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: 75,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.65),
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // New: weekday labels.
  Widget _buildWeekDayLabels(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        for (int i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: _boxGap),
            child: SizedBox(
              height: _boxSize,
              width: 50,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  i == 0 || i == 2 || i == 4 || i == 6
                      ? _weekDays[i]
                      : '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeatmap(BuildContext context) {
    final firstDay = DateTime(_year, 1, 1);
    final lastDay = DateTime(_year, 12, 31);

    final calendarStart = firstDay.subtract(
      Duration(days: firstDay.weekday - 1),
    );

    final totalWeeks =
        (lastDay.difference(calendarStart).inDays ~/ 7) + 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthLabels(calendarStart, totalWeeks),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int week = 0; week < totalWeeks; week++)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: _boxGap,
                          ),
                          child: Column(
                            children: [
                              for (int day = 0; day < 7; day++)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: _boxGap,
                                  ),
                                  child: _dayBox(
                                    context,
                                    calendarStart.add(
                                      Duration(
                                        days: week * 7 + day,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        _buildWeekDayLabels(context),
      ],
    );
  }

  Widget _legendBox(BuildContext context, int completed) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: _activityColor(context, completed),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // New: statistics cards.
  Widget _statCard(
      BuildContext context,
      IconData icon,
      String value,
      String title,
      String subtitle,
      Color iconColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(
              icon,
              color: iconColor,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New: selected day details.
  Widget _selectedDayCard(BuildContext context) {
    if (_selectedDate == null) {
      return const SizedBox.shrink();
    }

    final date = _selectedDate!;
    final dateString = _dateKey(date);
    final completed = _activity[dateString] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.primary.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                context.colors.primary.withOpacity(0.12),
                child: Icon(
                  Icons.calendar_today_outlined,
                  color: context.colors.primary,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  '${date.day} ${_months[date.month - 1]} ${date.year}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                tooltip: 'إغلاق',
                onPressed: () {
                  setState(() {
                    _selectedDate = null;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                completed > 0
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: completed > 0
                    ? context.colors.primary
                    : context.colors.inkMuted,
              ),

              const SizedBox(width: 8),

              Text(
                completed > 0
                    ? 'إنجازات هذا اليوم: $completed'
                    : 'لا توجد إنجازات مسجلة في هذا اليوم',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final activeDays =
        _activity.values.where((completed) => completed > 0).length;

    final totalCompleted = _activity.values.fold<int>(
      0,
          (sum, completed) => sum + completed,
    );

    final longestStreak = _longestStreak();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.grid_view_rounded,
                  color: colors.primary,
                  size: 26,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'خريطة الإنجازات',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: _loading ? null : _loadActivity,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث النشاط',
                ),
              ],
            ),

            Text(
              'نشاطك اليومي خلال سنة $_year',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.inkMuted,
              ),
            ),

            const SizedBox(height: 22),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error)
              Center(
                child: Column(
                  children: [
                    const Text('تعذر تحميل خريطة الإنجازات'),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: _loadActivity,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 680;

                    final cardWidth = isWide
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            context,
                            Icons.bar_chart_rounded,
                            '$activeDays',
                            'أيام نشطة',
                            'خلال السنة',
                            colors.primary,
                          ),
                        ),

                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            context,
                            Icons.check_circle_outline,
                            '$totalCompleted',
                            'إنجازات مسجلة',
                            'إجمالي الإنجازات',
                            colors.primary,
                          ),
                        ),

                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            context,
                            Icons.local_fire_department_outlined,
                            '$longestStreak',
                            'أطول سلسلة إنجاز',
                            'يوم متتالي',
                            Colors.deepOrange,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 22),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withOpacity(0.4),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeatmap(context),

                      const SizedBox(height: 16),

                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        runSpacing: 6,
                        children: [
                          const Text('أقل'),

                          _legendBox(context, 0),
                          _legendBox(context, 1),
                          _legendBox(context, 2),
                          _legendBox(context, 3),
                          _legendBox(context, 4),

                          const Text('أكثر'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'اضغط على أي يوم لمعرفة إنجازاته، واسحب لاستعراض السنة',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_selectedDate != null) ...[
                  const SizedBox(height: 16),
                  _selectedDayCard(context),
                ],

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        color: colors.primary,
                        size: 36,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'استمر على هذا المنوال!',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'كل يوم إنجاز يقربك أكثر من أهدافك.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
