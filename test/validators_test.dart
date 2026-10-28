import 'package:flutter_test/flutter_test.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';

void main() {
  test('validateEmail', () {
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('not-an-email'), isNotNull);
    expect(validateEmail(' a@b.co '), isNull);
  });

  test('validatePassword needs 8+ characters', () {
    expect(validatePassword(''), isNotNull);
    expect(validatePassword('short'), isNotNull);
    expect(validatePassword('longenough1'), isNull);
  });

  test('friendlyAuthCode maps known codes and never leaks internals', () {
    expect(friendlyAuthCode('wrong-password'), 'Incorrect email or password.');
    expect(friendlyAuthCode('email-already-in-use'), contains('already exists'));
    expect(friendlyAuthCode('something-new'), contains('something-new'));
  });

  test('friendlyError returns AppFailure message and a safe default', () {
    expect(friendlyError(const AppFailure('Nope')), 'Nope');
    expect(friendlyError(Exception('boom')), isNot(contains('boom')));
  });
}
