const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "Thu, 23 Oct · 18:00"
String formatEventDate(DateTime d) {
  final local = d.toLocal();
  return '${_weekdays[local.weekday - 1]}, ${local.day} ${_months[local.month - 1]}'
      ' · ${_two(local.hour)}:${_two(local.minute)}';
}

/// "23 Oct 2026, 18:00"
String formatFullDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '${_two(local.hour)}:${_two(local.minute)}';
}
