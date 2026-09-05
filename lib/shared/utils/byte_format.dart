/// Purpose: Render a byte count the way a person reads one.
/// Inputs: A number of bytes.
/// Returns: A short string.
/// Side effects: None.
/// Notes: Binary units, because that is what the upload limits this app works
/// against are stated in: telling somebody their file is 26 MB when the limit
/// is "25 MB" and it was rejected would be actively confusing.
library;

/// The unit names, smallest first.
const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

/// Purpose: Format a byte count.
/// Inputs: [bytes].
/// Returns: Something like `24.6 MB`.
/// Side effects: None.
/// Notes: One decimal place below a gigabyte and none for plain bytes, which is
/// enough precision to compare two files and little enough to read at a glance.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 ${_units.first}';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${_units[unit]}';
}
