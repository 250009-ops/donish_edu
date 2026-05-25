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

/// Calendar day in device local timezone (midnight, no time component).
DateTime localDateOnly(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool isBeforeLocalDay(DateTime a, DateTime b) {
  return localDateOnly(a).isBefore(localDateOnly(b));
}

bool isAfterLocalDay(DateTime a, DateTime b) {
  return localDateOnly(a).isAfter(localDateOnly(b));
}

/// Keeps [day] within [[minDay], [maxDay]] by local calendar day.
DateTime clampLocalDay(DateTime day, DateTime minDay, DateTime maxDay) {
  final d = localDateOnly(day);
  final min = localDateOnly(minDay);
  final max = localDateOnly(maxDay);
  if (d.isBefore(min)) return min;
  if (d.isAfter(max)) return max;
  return d;
}

/// First selectable study day from server `created_at` (UTC ISO).
DateTime? memberSinceFromIso(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    return localDateOnly(DateTime.parse(iso));
  } catch (_) {
    return null;
  }
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
