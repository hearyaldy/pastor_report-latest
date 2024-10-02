// lib/utils/date_utils.dart
import 'package:intl/intl.dart'; // Make sure intl package is installed

// Function to format the current date in the desired format
String getCurrentFormattedDate() {
  final now = DateTime.now();
  final formatter = DateFormat('EEEE | MMMM d, yyyy'); // Format: Day of the week | Month day, year
  return formatter.format(now);
}