import 'package:intl/intl.dart';

class DateTimeUtils {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _displayDateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');

  // Format dates for display
  static String formatDateForDisplay(DateTime date) {
    return _displayDateFormat.format(date);
  }

  static String formatDateTimeForDisplay(DateTime dateTime) {
    return _displayDateTimeFormat.format(dateTime);
  }

  // Format dates for database
  static String formatDateForDb(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatDateTimeForDb(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  // Parse dates from database
  static DateTime parseDateFromDb(String dateString) {
    return _dateFormat.parse(dateString);
  }

  static DateTime parseDateTimeFromDb(String dateTimeString) {
    return _dateTimeFormat.parse(dateTimeString);
  }

  // Get time periods
  static DateTime get startOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime get endOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  static DateTime get startOfWeek {
    final now = DateTime.now();
    final weekday = now.weekday;
    return now.subtract(Duration(days: weekday - 1));
  }

  static DateTime get startOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static DateTime get startOfYear {
    final now = DateTime.now();
    return DateTime(now.year, 1, 1);
  }

  // Time ago formatter
  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return formatDateForDisplay(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
