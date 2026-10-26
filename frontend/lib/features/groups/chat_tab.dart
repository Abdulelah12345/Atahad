import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_ui.dart';
import 'group_widgets.dart';

// the group chat: member messages (TEXT) and app messages (SYSTEM). It refreshes every 10 seconds.
// press and hold your message to delete it
class ChatTab extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final int? me;

  const ChatTab({super.key, required this.api, required this.groupId, required this.me});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with AutomaticKeepAliveClientMixin {
  final _input = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final list = await widget.api.messages(widget.groupId);
      list.sort((a, b) => '${a['sentAt']}'.compareTo('${b['sentAt']}'));
      if (mounted) setState(() {
        _messages = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted && !silent) setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.api.send(widget.groupId, content);
      _input.clear();
      await _load(silent: true);
    } catch (e) {
      if (mounted) showGroupError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> message) async {
    if (!await confirm(context, 'تحذف الرسالة؟', '${message['content'] ?? ''}', yes: 'احذف')) return;
    try {
      await widget.api.deleteMessage(message['id'] as int);
      await _load(silent: true);
    } catch (e) {
      if (mounted) showGroupError(context, e);
    }
  }

  // "اليوم" / "أمس" / "٢٤/١٠"
  static String _dayLabel(Object? value) {
    final d = DateTime.tryParse('${value ?? ''}');
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    return dayAr(value);
  }

  static String _dayKey(Object? value) => '${value ?? ''}'.length >= 10 ? '${value ?? ''}'.substring(0, 10) : '';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _messages.isEmpty
                      ? const EmptyView(message: 'ابدأ السوالف وشجّع المجموعة.', icon: Icons.chat_bubble_outline)
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s2),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final index = _messages.length - 1 - i;
                            final m = _messages[index];
                            final before = index > 0 ? _messages[index - 1] : null;
                            final newDay = before == null || _dayKey(before['sentAt']) != _dayKey(m['sentAt']);
                            final Widget item;
                            if (m['type'] == 'SYSTEM') {
                              item = _SystemMessage(message: m);
                            } else {
                              final mine = m['senderId'] == widget.me;
                              // the name and the avatar only on the first message of a run from the same person
                              final first = newDay || before!['type'] == 'SYSTEM' || before['senderId'] != m['senderId'];
                              item = _Bubble(message: m, mine: mine, first: first, onLongPress: mine ? () => _delete(m) : null);
                            }
                            if (!newDay) return item;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: Space.s3),
                                  child: Row(
                                    children: [
                                      Expanded(child: Divider(color: c.line)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: Space.s3),
                                        child: Text(_dayLabel(m['sentAt']), style: text.labelSmall),
                                      ),
                                      Expanded(child: Divider(color: c.line)),
                                    ],
                                  ),
                                ),
                                item,
                              ],
                            );
                          },
                        ),
        ),
        // the writing bar
        Container(
          padding: EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, Space.s2 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: const [BoxShadow(color: Color(0x1410245E), blurRadius: 20, offset: Offset(0, -6))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة للمجموعة',
                    counterText: '',
                    filled: true,
                    fillColor: c.surfaceSunken,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.xl), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.xl), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.xl), borderSide: BorderSide(color: c.accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: Space.s2),
              Semantics(
                button: true,
                label: 'أرسل',
                child: GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: c.primaryEdge, offset: const Offset(0, 3))],
                    ),
                    child: _sending
                        ? Padding(padding: const EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                        : Icon(Icons.send_rounded, color: c.onPrimary, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool mine;
  final bool first;
  final VoidCallback? onLongPress;

  const _Bubble({required this.message, required this.mine, required this.first, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final fg = mine ? c.onPrimary : c.ink;
    final name = '${message['senderName'] ?? ''}';
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? c.primary : c.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: Radius.circular(mine ? 6 : 18),
            bottomEnd: Radius.circular(mine ? 18 : 6),
          ),
          boxShadow: [BoxShadow(color: mine ? c.primaryEdge : c.line, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && first) Text(name, style: text.labelMedium!.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
            Text('${message['content'] ?? ''}', style: text.bodyMedium!.copyWith(color: fg)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(timeAr(message['sentAt']), style: text.labelSmall!.copyWith(color: fg.withValues(alpha: 0.7), fontSize: 10.5)),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: first ? Space.s2 : 2, bottom: 2),
      child: Row(
        // right to left: my messages on the right (start)
        mainAxisAlignment: mine ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: mine
            ? [bubble]
            : [
                bubble,
                const SizedBox(width: 6),
                first ? MemberAvatar(name, size: 30) : const SizedBox(width: 30),
              ],
      ),
    );
  }
}

// a message from the app: translated, with an icon for its kind
class _SystemMessage extends StatelessWidget {
  final Map<String, dynamic> message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final raw = '${message['content'] ?? ''}';
    final content = systemTextAr(raw);
    final (IconData icon, Color fg, Color bg) = switch (raw) {
      _ when raw.contains('joined the group') => (Icons.waving_hand_rounded, c.success, c.successSoft),
      _ when raw.contains('left the group') || raw.contains('was removed') => (Icons.logout_rounded, c.inkMuted, c.surfaceSunken),
      _ when raw.startsWith('Match result') || raw.contains('match') => (Icons.sports_kabaddi_rounded, c.urgentText, c.urgentSoft),
      _ when raw.startsWith('New goal') || raw.startsWith('The goal') => (Icons.flag_rounded, c.primary, c.primarySoft),
      _ => (Icons.auto_awesome_rounded, c.pardonText, c.pardonSoft), // the weekly summary of the AI
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.lg)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Flexible(child: Text(content, style: text.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w600, height: 1.6))),
            ],
          ),
        ),
      ),
    );
  }
}
