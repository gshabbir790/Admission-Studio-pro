/// Exact port of the HTML app's `sanitizeFilename()` (spec §24 filenames):
/// strip filesystem-invalid characters, collapse whitespace to underscores,
/// cap length at 60, fall back to a generated name when blank.
class FilenameUtils {
  FilenameUtils._();

  static String sanitize(String? name, String fallback) {
    var n = (name ?? '').trim();
    if (n.isEmpty) n = fallback;
    n = n.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').replaceAll(RegExp(r'\s+'), '_');
    return n.length > 60 ? n.substring(0, 60) : n;
  }

  /// Collision-safe `.jpg` filename generator, matching the HTML app's
  /// `usedNames` map in `downloadZip()`: `Ali.jpg`, then `Ali_2.jpg`, etc.
  static String uniqueJpgName(String base, Set<String> usedNames) {
    var name = '$base.jpg';
    var counter = 2;
    while (usedNames.contains(name)) {
      name = '${base}_$counter.jpg';
      counter++;
    }
    usedNames.add(name);
    return name;
  }
}
