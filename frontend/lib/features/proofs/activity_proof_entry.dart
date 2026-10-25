import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/widgets.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';
import 'proofs_home_screen.dart';

// بطاقة اليوم تصل للمهمة نفسها؛ لا يكتب العضو أي معرفات ولا يختار مهمة من هدف شخص آخر.
Future<void> openActivityProof(BuildContext context, Json activity) async {
  try {
    final data = await ProofsApi(context.read<ApiClient>()).workspace();
    final day = dateInput(riyadhNow());
    Json? saved;
    for (final proof in ProofsApi.maps(data['proofs'])) {
      if (proof['weekId'] == activity['weekId'] &&
          proof['goalTaskId'] == activity['goalTaskId'] &&
          '${proof['activityTime']}'.startsWith(day) &&
          proof['status'] != 'REJECTED') {
        saved = proof;
        break;
      }
    }
    if (!context.mounted) return;
    if (saved != null && saved['managed'] == true) {
      await context.push(
          '/proofs/session/${saved['id']}?title=${Uri.encodeComponent('${activity['title']}')}');
    } else if (saved != null) {
      await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => RecordDetails(
              item: saved!, kind: 'PROOF', onChanged: () async {}));
    } else if ((activity['remaining'] as num? ?? 1) <= 0) {
      showMessage(context, 'هذا النشاط مكتمل للأسبوع الحالي.');
    } else {
      await context.push('/proofs/start', extra: activity);
    }
  } catch (error) {
    if (context.mounted) proofError(context, error);
  }
}
