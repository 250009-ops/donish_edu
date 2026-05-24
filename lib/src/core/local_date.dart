/// Device-local calendar helpers (timezone = device setting).

String formatLocalDate(DateTime local) {
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseLocalDate(String yyyyMmDd) {
  final parts = yyyyMmDd.split('-');
  if (parts.length != 3) {
    throw FormatException('Invalid local date: $yyyyMmDd');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String formatLocalDateLabel(DateTime local) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
