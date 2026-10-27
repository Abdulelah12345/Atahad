
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/app_card.dart';
import 'learn_quest_api.dart';

class LearnQuestScreen extends StatefulWidget {
  const LearnQuestScreen({super.key});

  @override
  State<LearnQuestScreen> createState() => _LearnQuestScreenState();
}

class _LearnQuestScreenState extends State<LearnQuestScreen> {
  final _searchController = TextEditingController();

  late final LearnQuestApi _api;
  late Future<bool> _learningGoalFuture;

  String _type = 'all';
  String _query = '';
  List<LearnResource> _resources = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  static const _filters = [
    ('all', 'الكل', Icons.grid_view_rounded),
    ('books', 'كتب', Icons.menu_book_rounded),
    ('podcasts', 'بودكاست', Icons.headphones_rounded),
    ('courses', 'دورات', Icons.school_outlined),
  ];

  @override
  void initState() {
    super.initState();

    _api = LearnQuestApi(context.read<ApiClient>());
    _learningGoalFuture = _api.hasLearningGoal();
  }

  @override
  void dispose() {
    _requestId++;
    _searchController.dispose();
    super.dispose();
  }

  void _retryLearningGoal() {
    setState(() {
      _learningGoalFuture = _api.hasLearningGoal();
    });
  }

  Future<void> _search({String? type}) async {
    final query = _searchController.text.trim();

    if (type != null) {
      _type = type;
    }

    if (query.isEmpty) {
      setState(() {
        _query = '';
        _resources = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    final request = ++_requestId;

    FocusScope.of(context).unfocus();

    setState(() {
      _query = query;
      _loading = true;
      _error = null;
      _resources = [];
    });

    try {
      final items = await _api.search(query, type: _type);

      if (!mounted || request != _requestId) return;

      setState(() => _resources = items);
    } catch (_) {
      if (!mounted || request != _requestId) return;

      setState(() {
        _error = 'تعذر تحميل المصادر حاليًا. حاول مرة ثانية.';
      });
    } finally {
      if (mounted && request == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openResource(LearnResource item) async {
    final raw = item.url;
    final uri = raw == null ? null : Uri.tryParse(raw);

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رابط هذا المصدر غير متوفر حاليًا'),
        ),
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلة التعلّم'),
        centerTitle: true,
      ),
      body: FutureBuilder<bool>(
        future: _learningGoalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _state(
              Icons.wifi_off_rounded,
              'تعذر التحقق من أهدافك حاليًا. حاول مرة ثانية.',
              action: 'إعادة المحاولة',
              onPressed: _retryLearningGoal,
            );
          }

          if (snapshot.data != true) {
            return _state(
              Icons.auto_stories_outlined,
              'مكتبة التعلّم مخصصة للأهداف التعليمية.\n'
                  'أضف تعهّدًا للقراءة أو الدراسة أو تعلّم مهارة '
                  'عشان تستفيد من المكتبة.',
              action: 'إعادة التحقق',
              onPressed: _retryLearningGoal,
            );
          }

          return _buildLibrary();
        },
      ),
    );
  }

  Widget _buildLibrary() {
    final c = context.colors;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s4,
              Space.s2,
              Space.s4,
              Space.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Space.s3),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: c.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: Space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تعلّم شيء جديد اليوم',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: Space.s1),
                            Text(
                              'كتب، بودكاست ودورات في مكان واحد',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.s4),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'وش ودك تتعلّم؟ مثل Java أو تطوير الذات',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'بحث',
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: c.primary,
                      ),
                      onPressed: _loading ? null : _search,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s3),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final selected = _type == filter.$1;

                      return Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: Space.s2,
                        ),
                        child: ChoiceChip(
                          selected: selected,
                          avatar: Icon(
                            filter.$3,
                            size: 17,
                            color: selected ? c.primary : null,
                          ),
                          label: Text(filter.$2),
                          onSelected: (_) {
                            if (_type == filter.$1) return;

                            setState(() {
                              _type = filter.$1;
                            });

                            if (_searchController.text.trim().isNotEmpty) {
                              _search(type: filter.$1);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _state(
        Icons.wifi_off_rounded,
        _error!,
        action: 'إعادة المحاولة',
        onPressed: _search,
      );
    }

    if (_query.isEmpty) {
      // a start the member can tap, so the page is never empty
      const ideas = ['تطوير الذات', 'روايات', 'البرمجة', 'اللغة الإنجليزية', 'إدارة الوقت', 'التاريخ'];
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_outlined, color: context.colors.primary, size: 48),
              const SizedBox(height: Space.s3),
              const Text('ابحث عن مهارة أو موضوع، أو ابدأ بواحد من هذي:', textAlign: TextAlign.center),
              const SizedBox(height: Space.s4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [
                  for (final idea in ideas)
                    ActionChip(
                      label: Text(idea),
                      onPressed: () {
                        _searchController.text = idea;
                        _search();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_resources.isEmpty) {
      return _state(
        Icons.search_off_rounded,
        'ما لقينا نتائج لـ «$_query». جرّب كلمة مختلفة.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Space.s4,
        0,
        Space.s4,
        Space.s6,
      ),
      itemCount: _resources.length + 1,
      separatorBuilder: (_, __) =>
      const SizedBox(height: Space.s3),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: Space.s2,
            ),
            child: Text(
              'لقينا ${_resources.length} مصدر',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          );
        }

        return _resourceCard(_resources[index - 1]);
      },
    );
  }

  Widget _resourceCard(LearnResource item) {
    final c = context.colors;

    final (icon, typeLabel) = switch (item.type) {
      'BOOK' => (Icons.menu_book_outlined, 'كتاب'),
      'PODCAST' => (Icons.headphones_outlined, 'بودكاست'),
      'COURSE' => (Icons.school_outlined, 'دورة'),
      _ => (Icons.auto_stories_outlined, 'محتوى'),
    };

    return AppCard(
      onTap: () => _openResource(item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: SizedBox(
              width: 80,
              height: 105,
              child: item.imageUrl == null
                  ? Container(
                color: c.primary.withValues(alpha: .08),
                child: Icon(
                  icon,
                  color: c.primary,
                  size: 32,
                ),
              )
                  : Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: c.primary.withValues(alpha: .08),
                  child: Icon(
                    icon,
                    color: c.primary,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: Space.s2),
                if (item.creator.isNotEmpty)
                  Text(
                    item.creator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: Space.s1),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: Space.s3),
                Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: c.primary,
                    ),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        color: c.primary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '• ${item.source}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.open_in_new_rounded,
            color: c.primary,
            size: 19,
          ),
        ],
      ),
    );
  }

  Widget _state(
      IconData icon,
      String message, {
        String? action,
        VoidCallback? onPressed,
      }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: context.colors.primary,
              size: 48,
            ),
            const SizedBox(height: Space.s3),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: Space.s4),
              OutlinedButton(
                onPressed: onPressed,
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
