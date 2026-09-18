import 'package:flutter_test/flutter_test.dart';
import 'package:taskvault/utils/validators.dart';

void main() {
  group('Validators.title', () {
    test('rejects empty string', () {
      expect(Validators.title(''), isNotNull);
    });

    test('rejects whitespace-only string', () {
      expect(Validators.title('   '), isNotNull);
    });

    test('rejects null', () {
      expect(Validators.title(null), isNotNull);
    });

    test('accepts a normal title', () {
      expect(Validators.title('Buy groceries'), isNull);
    });

    test('rejects a title longer than the max length', () {
      final tooLong = 'a' * (Validators.maxTitleLength + 1);
      expect(Validators.title(tooLong), isNotNull);
    });

    test('accepts a title exactly at the max length', () {
      final atLimit = 'a' * Validators.maxTitleLength;
      expect(Validators.title(atLimit), isNull);
    });
  });

  group('Validators.description', () {
    test('accepts empty description (optional field)', () {
      expect(Validators.description(''), isNull);
      expect(Validators.description(null), isNull);
    });

    test('rejects a description longer than the max length', () {
      final tooLong = 'a' * (Validators.maxDescriptionLength + 1);
      expect(Validators.description(tooLong), isNotNull);
    });
  });

  group('Validators.dueDate', () {
    test('accepts null (no due date set)', () {
      expect(Validators.dueDate(null), isNull);
    });

    test('accepts a reasonable future date', () {
      expect(Validators.dueDate(DateTime(2026, 12, 31)), isNull);
    });

    test('rejects an unreasonably old date', () {
      expect(Validators.dueDate(DateTime(1990, 1, 1)), isNotNull);
    });
  });
}
