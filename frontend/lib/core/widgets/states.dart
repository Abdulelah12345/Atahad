import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';
import 'at_button.dart';

// loading / error / empty, and a helper that loads data from the API and shows the right one
//   AsyncView<List>(
//     load: () async => await api.get('/api/v1/habit/getMyHabits') as List,
//     builder: (context, habits, reload) => ListView(...),
//   )
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  const AsyncView({super.key, required this.load, required this.builder});

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  Future<void> _reload() async {
    final next = widget.load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
        if (snapshot.hasError) return ErrorView(message: '${snapshot.error}', onRetry: _reload);
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: context.colors.danger),
            const SizedBox(height: Space.s3),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: Space.s4),
              AtButton('حاول مرة ثانية', onPressed: onRetry, kind: AtButtonKind.outline, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.colors.inkSubtle),
            const SizedBox(height: Space.s3),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.colors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

// shows the error message from the server at the bottom of the screen
void showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'صار خطأ، حاول مرة ثانية.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
