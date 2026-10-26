
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';

class GroupMatchingScreen extends StatefulWidget {
  final int groupId;
  final int memberId;

  const GroupMatchingScreen({
    super.key,
    required this.groupId,
    required this.memberId,
  });

  @override
  State<GroupMatchingScreen> createState() => _GroupMatchingScreenState();
}

class _GroupMatchingScreenState extends State<GroupMatchingScreen> {
  bool _loadingSuggestions = false;
  bool _loadingMatches = false;
  bool _suggestionsRequested = false;
  bool _saving = false;

  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatches();
    });
  }

  List<Map<String, dynamic>> _toList(dynamic result) {
    if (result is! List) {
      throw Exception('Invalid response from server');
    }

    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _loadSuggestions() async {
    if (_loadingSuggestions) return;

    setState(() {
      _loadingSuggestions = true;
      _suggestionsRequested = true;
    });

    try {
      final api = context.read<ApiClient>();

      final result = await api.get(
        '/api/v1/group-match/suggest/${widget.groupId}',
      );

      if (!mounted) return;

      setState(() {
        _suggestions = _toList(result);
      });
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingSuggestions = false);
      }
    }
  }

  Future<void> _loadMatches() async {
    if (_loadingMatches) return;

    setState(() => _loadingMatches = true);

    try {
      final api = context.read<ApiClient>();

      final result = await api.get(
        '/api/v1/group-match/get/${widget.groupId}',
      );

      if (!mounted) return;

      setState(() {
        _matches = _toList(result);
      });
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingMatches = false);
      }
    }
  }

  Future<void> _challenge(Map<String, dynamic> group) async {
    if (_saving) return;

    final opponentId = _number(group['groupId']);
    final groupName = group['name']?.toString() ??
        group['groupName']?.toString() ??
        'المجموعة';

    if (opponentId <= 0) {
      _message('معرّف المجموعة غير صحيح');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال تحدي'),
        content: Text('هل تبي تتحدى مجموعة $groupName؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إرسال التحدي'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    try {
      final api = context.read<ApiClient>();

      await api.post(
        '/api/v1/group-match/challenge/${widget.groupId}',
        query: {'opponentGroupId': opponentId},
      );

      _message('تم إرسال التحدي بنجاح');

      await _loadMatches();
      await _loadSuggestions();
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _respond(int matchId, bool accept) async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final api = context.read<ApiClient>();

      await api.put(
        '/api/v1/group-match/respond/$matchId/$accept',
      );

      _message(
        accept ? 'تم قبول التحدي بنجاح' : 'تم رفض التحدي',
      );

      await _loadMatches();
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'بانتظار الموافقة';
      case 'ACTIVE':
        return 'تحدي جاري';
      case 'FINISHED':
        return 'منتهي';
      case 'DECLINED':
        return 'مرفوض';
      default:
        return status;
    }
  }

  Widget _suggestionCard(Map<String, dynamic> group) {
    final name = group['name']?.toString() ??
        group['groupName']?.toString() ??
        'مجموعة';

    final score = _number(group['compatibilityScore']).clamp(0, 100);

    final goal = group['goalTitle']?.toString() ?? '-';
    final reason = group['reason']?.toString() ?? '';
    final members = group['membersCount']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$score%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),

            const SizedBox(height: 12),

            Text('الهدف: $goal'),
            const SizedBox(height: 6),
            Text('عدد الأعضاء: $members'),

            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'سبب التوافق: $reason',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _challenge(group),
                icon: const Icon(Icons.sports_kabaddi),
                label: const Text('إرسال تحدي'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchCard(Map<String, dynamic> match) {
    final matchId = _number(match['id']);
    final status = match['status']?.toString() ?? '';

    final challengerId = _number(match['challengerId']);
    final opponentId = _number(match['opponentId']);

    final challengerName =
        match['challengerName']?.toString() ?? 'المجموعة الأولى';

    final opponentName =
        match['opponentName']?.toString() ?? 'المجموعة الثانية';

    final isIncoming = opponentId == widget.groupId;
    final otherName = isIncoming ? challengerName : opponentName;

    final challengerScore = _number(match['challengerScore']);
    final opponentScore = _number(match['opponentScore']);

    final winner = match['winnerName']?.toString();
    final startDate = match['startDate']?.toString();
    final endDate = match['endDate']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تحدي مع $otherName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text('الحالة: ${_statusText(status)}'),

            if (status == 'PENDING')
              Text(
                isIncoming
                    ? 'مجموعتكم مستقبلة التحدي'
                    : 'تم إرسال التحدي للمجموعة الأخرى',
              ),

            if (startDate != null && endDate != null) ...[
              const SizedBox(height: 8),
              Text('من $startDate إلى $endDate'),
            ],

            if (status == 'FINISHED') ...[
              const SizedBox(height: 12),
              Text('$challengerName: $challengerScore%'),
              Text('$opponentName: $opponentScore%'),
              const SizedBox(height: 8),
              Text(
                winner == null || winner == 'null'
                    ? 'النتيجة: تعادل'
                    : 'الفائز: $winner',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],

            if (status == 'PENDING' && isIncoming) ...[
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving || matchId <= 0
                          ? null
                          : () => _respond(matchId, true),
                      child: const Text('قبول'),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving || matchId <= 0
                          ? null
                          : () => _respond(matchId, false),
                      child: const Text('رفض'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديات المجموعات'),
        centerTitle: true,
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await _loadMatches();

          if (_suggestionsRequested) {
            await _loadSuggestions();
          }
        },

        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 55,
            ),

            const SizedBox(height: 12),

            Text(
              'AI Group Matching',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 8),

            const Text(
              'اكتشف مجموعات تشبه أهداف مجموعتك وتحداهم لمدة أسبوع',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                _loadingSuggestions || _saving ? null : _loadSuggestions,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  _loadingSuggestions
                      ? 'جاري البحث بالذكاء الاصطناعي...'
                      : 'اكتشف المجموعات المتوافقة',
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_loadingSuggestions)
              const Center(child: CircularProgressIndicator()),

            if (_suggestionsRequested &&
                !_loadingSuggestions &&
                _suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'ما لقينا مجموعات متوافقة حاليًا',
                  textAlign: TextAlign.center,
                ),
              ),

            for (final group in _suggestions)
              _suggestionCard(group),

            const SizedBox(height: 26),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'التحديات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),

                IconButton(
                  onPressed: _loadingMatches ? null : _loadMatches,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث التحديات',
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_loadingMatches)
              const Center(child: CircularProgressIndicator())
            else if (_matches.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'ما عندك تحديات حاليًا',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final match in _matches)
                _matchCard(match),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
