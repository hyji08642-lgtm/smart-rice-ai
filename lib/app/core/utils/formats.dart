String two(int n) => n.toString().padLeft(2, '0');

String formatTime(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

String formatMonthDay(DateTime t) => '${t.month}월 ${t.day}일';

String formatNum(double v, {int digits = 1}) => v.toStringAsFixed(digits);

String formatSigned(double v, {int digits = 1}) {
  final s = v.toStringAsFixed(digits);
  return v > 0 ? '+$s' : s;
}
