import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
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
        _error = '$e';
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
      if (mounted) showError(context, e);
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
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;
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
                          padding: const EdgeInsets.all(Space.s4),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final m = _messages[_messages.length - 1 - i];
                            if (m['type'] == 'SYSTEM') return _SystemMessage(message: m);
                            final mine = m['senderId'] == widget.me;
                            return _Bubble(message: m, mine: mine, onLongPress: mine ? () => _delete(m) : null);
                          },
                        ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, Space.s2 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'اكتب رسالة', counterText: ''),
                ),
              ),
              const SizedBox(width: Space.s2),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
                icon: const Icon(Icons.send_rounded),
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
  final VoidCallback? onLongPress;

  const _Bubble({required this.message, required this.mine, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final fg = mine ? c.onPrimary : c.ink;
    return Align(
      // right to left: start = right side (my messages), end = left side
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.only(bottom: Space.s2),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
          decoration: BoxDecoration(
            color: mine ? c.primary : c.surface,
            border: mine ? null : Border.all(color: c.line),
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(Radii.lg),
              topEnd: const Radius.circular(Radii.lg),
              bottomStart: Radius.circular(mine ? Radii.sm : Radii.lg),
              bottomEnd: Radius.circular(mine ? Radii.lg : Radii.sm),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) Text('${message['senderName'] ?? ''}', style: text.labelMedium!.copyWith(color: c.shadda)),
              Text('${message['content'] ?? ''}', style: text.bodyMedium!.copyWith(color: fg)),
              Text(timeAr(message['sentAt']), style: text.labelSmall!.copyWith(color: fg.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final Map<String, dynamic> message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Space.s2),
        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
        decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(Radii.md)),
        child: Text('${message['content'] ?? ''}', style: text.labelMedium!.copyWith(color: c.primary), textAlign: TextAlign.center),
      ),
    );
  }
}
