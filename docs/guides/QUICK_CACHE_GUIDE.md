# Quick Cache Implementation Guide

## How to Use Optimized Data Service in Your Code

### 1. Fetching Missions (One-Time)

```dart
import 'package:pastor_report/services/optimized_data_service.dart';

final dataService = OptimizedDataService.instance;

// Get missions (cache-first)
List<Mission> missions = await dataService.getMissions();

// Force refresh (bypass cache)
List<Mission> freshMissions = await dataService.getMissions(forceRefresh: true);
```

### 2. Fetching Departments (One-Time)

```dart
// By mission ID
List<Department> departments = await dataService.getDepartmentsByMissionId(
  'mission_id_here',
);

// By mission name
List<Department> departments = await dataService.getDepartmentsByMissionName(
  'Sabah Mission',
);

// Force refresh
List<Department> freshDepts = await dataService.getDepartmentsByMissionId(
  'mission_id_here',
  forceRefresh: true,
);
```

### 3. Streaming Data (Real-Time with Cache)

```dart
// Stream missions
StreamBuilder<List<Mission>>(
  stream: dataService.streamMissions(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    final missions = snapshot.data!;
    return ListView.builder(
      itemCount: missions.length,
      itemBuilder: (context, index) {
        return ListTile(title: Text(missions[index].name));
      },
    );
  },
)

// Stream departments
StreamBuilder<List<Department>>(
  stream: dataService.streamDepartmentsByMissionName('Sabah Mission'),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    final departments = snapshot.data!;
    return GridView.builder(...);
  },
)
```

### 4. Invalidating Cache (After Updates)

```dart
// After adding/editing/deleting a department
await dataService.invalidateMissionDepartmentsCache(missionId);

// After changing missions
await dataService.invalidateMissionsCache();

// Clear all department caches
await dataService.invalidateDepartmentsCache();
```

### 5. Using Cache Service Directly

```dart
import 'package:pastor_report/services/cache_service.dart';

final cache = CacheService.instance;

// Cache custom data
await cache.setCache('my_key', {'data': 'value'}, 'custom');

// Retrieve cached data
final data = await cache.getCached('my_key');

// Clear specific cache
await cache.clearCache('my_key');

// Clear all cache
await cache.clearAllCache();
```

## Migration Examples

### Before (Direct Firestore)

```dart
// ❌ OLD WAY - No caching, many reads
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('missions')
      .orderBy('name')
      .snapshots(),
  builder: (context, snapshot) {
    // ... convert to Mission objects
  },
)
```

### After (Optimized Service)

```dart
// ✅ NEW WAY - Cached, fewer reads
StreamBuilder<List<Mission>>(
  stream: OptimizedDataService.instance.streamMissions(),
  builder: (context, snapshot) {
    final missions = snapshot.data ?? [];
    // ... use missions directly
  },
)
```

## Key Benefits

### Automatic Features

✅ **Cache-first loading** - Instant display from cache
✅ **Rate limiting** - Max one fetch per 5 seconds
✅ **Offline support** - Works without internet
✅ **Auto-invalidation** - Cache expires automatically
✅ **Stream sharing** - Single listener per data type
✅ **Memory efficient** - Reuses controllers

### Cost Savings

- **First app open**: ~70 reads (cached for 12-24 hours)
- **Subsequent opens**: ~0 reads (from cache)
- **Filter changes**: 0 reads (client-side filtering)
- **Real-time updates**: Still work! (Firebase optimizes)

## Admin Update Pattern

When admin modifies data:

```dart
// 1. Update Firestore
await FirebaseFirestore.instance
    .collection('missions')
    .doc(missionId)
    .collection('departments')
    .doc(deptId)
    .update(data);

// 2. Invalidate cache immediately
await OptimizedDataService.instance.invalidateMissionDepartmentsCache(missionId);

// 3. UI auto-updates via streams (already listening)
// No manual refresh needed!
```

## Testing Cache

### Verify Cache is Working

```dart
// 1. Open app (should fetch from Firestore)
// 2. Close app
// 3. Turn off WiFi
// 4. Open app (should load from cache!)
// 5. If it loads → Cache is working ✅
```

### Check Cache Contents

```dart
import 'package:shared_preferences/shared_preferences.dart';

void debugCache() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();

  print('Cached items: ${keys.length}');
  for (final key in keys) {
    if (key.startsWith('cache_')) {
      print('Found cache: $key');
    }
  }
}
```

## Troubleshooting

### Cache not working?

1. Check initialization in `main.dart`
2. Verify `shared_preferences` package installed
3. Look for error logs
4. Try `clearAllCache()` and restart

### Stale data?

1. Reduce cache duration in `cache_service.dart`
2. Use `forceRefresh: true`
3. Invalidate cache after writes
4. Add manual refresh button

### Too many reads still?

1. Check Firebase Console metrics
2. Ensure using `OptimizedDataService`
3. Verify streams aren't duplicated
4. Check for direct Firestore calls

## Next Steps

1. ✅ Cache already enabled in `main.dart`
2. ✅ Dashboard using optimized service
3. 📝 Update other screens to use `OptimizedDataService`
4. 📊 Monitor Firebase usage (should drop 80-95%)
5. 🎯 Fine-tune cache durations based on data update frequency
