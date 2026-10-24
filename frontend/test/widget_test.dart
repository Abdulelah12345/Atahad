import 'package:atahad/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numbers are shown with Arabic digits', () {
    expect(arabicDigits(70), '٧٠');
    expect(money(70), '٧٠٫٠٠');
  });
}
