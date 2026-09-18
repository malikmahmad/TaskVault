/// Pure, side-effect-free validators — kept out of widgets so they're easy
/// to unit test and reuse.
class Validators {
  Validators._();

  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 500;

  /// Returns an error message, or null if [value] is a valid task title.
  static String? title(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Title is required';
    }
    if (trimmed.length > maxTitleLength) {
      return 'Title must be $maxTitleLength characters or fewer';
    }
    return null;
  }

  /// Description is optional but bounded in length.
  static String? description(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > maxDescriptionLength) {
      return 'Description must be $maxDescriptionLength characters or fewer';
    }
    return null;
  }

  /// A due date, if provided, should not be nonsensically far in the past.
  static String? dueDate(DateTime? value) {
    if (value == null) return null;
    final earliestAllowed = DateTime(2000, 1, 1);
    if (value.isBefore(earliestAllowed)) {
      return 'Please choose a valid date';
    }
    return null;
  }
}
