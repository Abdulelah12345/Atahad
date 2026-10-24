import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

// OWNER: Abdulelah - the "حسابي" tab (empty for now)
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: const EmptyView(message: 'قيد التطوير', icon: Icons.person_outline),
    );
  }
}
