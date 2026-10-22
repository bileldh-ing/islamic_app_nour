import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/format.dart';

void main() {
  test('digits are always Western', () {
    expect(RegExp('[\u0660-\u0669\u06F0-\u06F9]').hasMatch(Fmt.western('١٢٤٧ ۵')), isFalse);
    expect(Fmt.two(7), '07');
  });
}
