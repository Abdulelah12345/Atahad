import 'package:flutter/material.dart';
import 'package:atahad/main.dart';
import 'package:atahad/core/theme/theme_state.dart';
import 'support/proofs_fake_api.dart';

// Entry point for isolated visual QA, never used by lib/main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ProofsFakeApi();
  final app = AtahadApp(
    theme: ThemeState(),
    api: api,
    auth: ProofsFakeAuth(api, admin: Uri.base.queryParameters['admin'] == '1'),
  );
  runApp(
    Uri.base.queryParameters['phone'] == '1'
        ? Center(child: SizedBox(width: 390, child: app))
        : app,
  );
}
