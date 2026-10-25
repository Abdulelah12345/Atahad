import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';

// تستخدم مسارات الزيارة الحالية فقط، دون تغيير حساب المسافة والمدة أو ربط الصور الإضافية.
class VisitScreen extends StatefulWidget {
  final Json activity;
  const VisitScreen({super.key, required this.activity});
  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  late final ApiClient _client = context.read<ApiClient>();
  List<Json> _visits = [];
  bool _busy = false;
  bool _loading = true;
  double? _accuracy;
  String? _notice;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ProofsApi(_client).workspace();
      if (mounted) {
        setState(() => _visits = ProofsApi.maps(data['visits'])
            .where((v) =>
                v['commitmentId'] == widget.activity['commitmentId'] &&
                v['goalTaskId'] == widget.activity['goalTaskId'])
            .toList());
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enter() async {
    setState(() => _busy = true);
    final member = context.read<AuthState>().userId;
    try {
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 25)));
      if (mounted) setState(() => _accuracy = position.accuracy);
      await _client.post(
          '/api/v1/visit/enter/$member/${widget.activity['commitmentId']}',
          query: {
            'goalTaskId': widget.activity['goalTaskId']
          },
          body: {
            'latitude': position.latitude,
            'longitude': position.longitude
          });
      if (mounted) {
        setState(() => _notice = 'سجلنا وصولك. بعد ما تنتهي، سجّل مغادرتك.');
      }
      await _load();
    } on PermissionDeniedException {
      if (mounted) {
        showMessage(context, 'اسمح للتطبيق باستخدام موقعك من الإعدادات.');
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exit() async {
    setState(() => _busy = true);
    final member = context.read<AuthState>().userId;
    try {
      final result = await _client.post(
              '/api/v1/visit/exit/$member/${widget.activity['commitmentId']}')
          as Map;
      if (mounted) {
        setState(() => _notice = result['note'] as String? ??
            'حفظنا الزيارة، وتقدر تتابع نتيجة الإثبات من سجلك.');
      }
      await _load();
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _visits.any((v) => v['status'] == 'OPEN');
    return ProofPage(
        title: 'إثبات الزيارة',
        child: _loading
            ? const LoadingView()
            : ListView(padding: const EdgeInsets.all(24), children: [
                Icon(Icons.location_on_outlined,
                    size: 60, color: context.colors.primary),
                const SizedBox(height: 20),
                Text('${widget.activity['title']}',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                const ProofNotice(
                    'سجّل الوصول وأنت في المكان، ثم المغادرة بعد انتهاء نشاطك. نستخدم موقع الجهاز بإذنك؛ قد تختلف الدقة على اللابتوب.'),
                if (_notice != null) ...[
                  const SizedBox(height: 20),
                  ProofNotice(_notice!)
                ],
                if (_accuracy != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                          'دقة الموقع المتاحة: حوالي ${arabicDigits(_accuracy!.round())} متر.')),
                const SizedBox(height: 26),
                AtButton(open ? 'سجّل مغادرتي' : 'سجّل وصولي',
                    loading: _busy,
                    onPressed: open ? _exit : _enter,
                    icon: Icon(open ? Icons.logout : Icons.my_location)),
                const SizedBox(height: 28),
                Text('زيارات هذا النشاط',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final visit in _visits)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text(displayDate(visit['enteredAt']))),
                              StatusBadge(visit['status'] == 'OPEN'
                                  ? 'زيارة جارية'
                                  : 'انتهت الزيارة')
                            ]),
                            if (visit['minutes'] != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                      '${arabicDigits(visit['minutes'])} دقيقة')),
                            if (visit['note'] != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text('${visit['note']}')),
                          ]))),
              ]));
  }
}
