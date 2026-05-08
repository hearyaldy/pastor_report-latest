// lib/utils/cache_utility.dart

class CacheUtility {
  // Simple in-memory cache
  static final Map<String, _CacheEntry> _cache = {};

  static void set(
    String key,
    dynamic value, {
    Duration duration = const Duration(minutes: 5),
  }) {
    _cache[key] = _CacheEntry(
      value: value,
      expiryTime: DateTime.now().add(duration),
    );
  }

  static dynamic get(String key) {
    final entry = _cache[key];
    if (entry != null) {
      if (DateTime.now().isBefore(entry.expiryTime)) {
        return entry.value;
      } else {
        // Entry has expired, remove it
        _cache.remove(key);
      }
    }
    return null;
  }

  static bool has(String key) {
    final entry = _cache[key];
    if (entry != null) {
      if (DateTime.now().isBefore(entry.expiryTime)) {
        return true;
      } else {
        // Entry has expired, remove it
        _cache.remove(key);
      }
    }
    return false;
  }

  static void remove(String key) {
    _cache.remove(key);
  }

  static void clear() {
    _cache.clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiryTime;

  _CacheEntry({required this.value, required this.expiryTime});
}
