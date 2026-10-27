import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';

class GoogleCalendarScreen extends StatefulWidget {
  const GoogleCalendarScreen({super.key});

  @override
  State<GoogleCalendarScreen> createState() => _GoogleCalendarScreenState();
}

class _GoogleCalendarScreenState extends State<GoogleCalendarScreen> {
  bool _loading = false;
  bool _connected = false;
  List<dynamic> _schedules = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();
      final result = await api.get('/api/v1/google-calendar/status');

      if (!mounted) return;

      setState(() {
        _connected = result is Map && result['connected'] == true;
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();
      final result = await api.get('/api/v1/google-calendar/connect');

      if (result is! String || result.isEmpty) {
        throw Exception('Invalid Google authorization URL');
      }

      final opened = await launchUrl(
        Uri.parse(result),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Unable to open Google authorization page');
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();
      final result = await api.post('/api/v1/google-calendar/generate');

      if (!mounted) return;

      setState(() {
        _schedules = result is List ? result : [];
      });

      if (_schedules.isEmpty) {
        _showMessage('ما فيه مواعيد مقترحة حاليًا');
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();

      await api.post(
        '/api/v1/google-calendar/approve-schedule',
        body: _schedules,
      );

      if (!mounted) return;

      setState(() => _schedules = []);

      _showMessage('تمت إضافة المواعيد إلى Google Calendar بنجاح');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();
      await api.post('/api/v1/google-calendar/reject-schedule');

      if (!mounted) return;

      setState(() => _schedules = []);
      _showMessage('تم إلغاء الجدول المقترح');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();
      await api.delete('/api/v1/google-calendar/disconnect');

      if (!mounted) return;

      setState(() {
        _connected = false;
        _schedules = [];
      });

      _showMessage('تم فصل Google Calendar');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(Object error) {
    _showMessage(error.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Calendar'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading ? null : _checkStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _schedules.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.calendar_month_outlined, size: 70),
          const SizedBox(height: 16),

          Text(
            _connected
                ? 'Google Calendar متصل'
                : 'اربط حساب Google Calendar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 20),

          if (!_connected)
            ElevatedButton(
              onPressed: _loading ? null : _connect,
              child: const Text('ربط Google Calendar'),
            ),

          if (_connected) ...[
            ElevatedButton(
              onPressed: _loading ? null : _generate,
              child: const Text('Generate AI Schedule'),
            ),

            const SizedBox(height: 20),

            if (_schedules.isNotEmpty) ...[
              Text(
                'الجدول المقترح',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 12),

              for (final item in _schedules)
                if (item is Map)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['title'] ?? 'تعهد'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),

                          const SizedBox(height: 8),

                          if (item['suggestions'] is List)
                            for (final suggestion in item['suggestions'])
                              if (suggestion is Map)
                                ListTile(
                                  leading: const Icon(Icons.event),
                                  title: Text(
                                    '${suggestion['date'] ?? ''}',
                                  ),
                                  subtitle: Text(
                                    '${suggestion['startTime'] ?? ''} - ${suggestion['endTime'] ?? ''}',
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _loading ? null : _approve,
                icon: const Icon(Icons.check),
                label: const Text('Approve - إضافة للتقويم'),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: _loading ? null : _reject,
                icon: const Icon(Icons.close),
                label: const Text('Reject - إلغاء'),
              ),
            ],

            const SizedBox(height: 30),

            TextButton(
              onPressed: _loading ? null : _disconnect,
              child: const Text('فصل Google Calendar'),
            ),
          ],
        ],
      ),
    );
  }
}