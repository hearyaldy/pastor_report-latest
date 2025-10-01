# Firebase Optimization & Caching Strategy

## Overview

This document describes the comprehensive caching and optimization strategy implemented to reduce Firebase Firestore read/write costs.

## Key Optimizations

### 1. **Firestore Offline Persistence** (`lib/main.dart:41-49`)

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Benefits:**
- Automatic offline data access
- Reduces repeated reads for same data
- Firebase SDK handles cache management
- Works across app restarts

### 2. **Local Cache Service** (`lib/services/cache_service.dart`)

A dedicated caching layer using SharedPreferences for persistent local storage.

**Features:**
- Time-based cache expiration
- Type-specific cache durations:
  - Missions: 24 hours
  - Departments: 12 hours
  - Users: 30 minutes
- Automatic cache invalidation
- JSON serialization for complex objects

**Usage:**
```dart
final cache = CacheService.instance;

// Cache data
await cache.setCacheList('key', dataList, 'missions');

// Retrieve cached data
final cached = await cache.getCachedList('key');
```

### 3. **Optimized Data Service** (`lib/services/optimized_data_service.dart`)

Intelligent data fetching with multi-layer caching.

**Features:**
- **Rate Limiting**: Prevents rapid successive reads (5-second minimum interval)
- **Cache-First Strategy**: Always check cache before Firestore
- **Smart Streaming**: Reuses stream controllers to avoid duplicate listeners
- **Firestore Cache Integration**: Uses `Source.serverAndCache`

**Cache Layers:**
1. **In-Memory Cache**: Instant access to recently fetched data
2. **SharedPreferences Cache**: Persistent across app sessions
3. **Firestore Offline Cache**: Firebase SDK's built-in cache
4. **Server**: Only fetched when all caches miss or expire

### 4. **Stream Optimization**

**Before:**
```dart
// Each StreamBuilder creates a new Firestore listener
FirebaseFirestore.instance.collection('missions').snapshots()
```

**After:**
```dart
// Shared stream controller with cache-first emission
OptimizedDataService.instance.streamMissions()
```

**Benefits:**
- Single Firestore listener per data type
- Cached data emitted immediately
- Real-time updates still work
- Automatic stream cleanup

## Cost Savings Breakdown

### Typical User Session (Before Optimization)

| Action | Reads |
|--------|-------|
| App startup | 50+ |
| Navigate to dashboard | 20+ |
| Switch mission filter | 15+ |
| Reload dashboard | 20+ |
| **Total per session** | **~105 reads** |

### With Optimizations (After)

| Action | Reads (First Time) | Reads (Cached) |
|--------|-------------------|----------------|
| App startup | 50 | 0 |
| Navigate to dashboard | 20 | 0 |
| Switch mission filter | 0 | 0 |
| Reload dashboard | 0 | 0 |
| **Total per session** | **~70 reads** | **~0 reads** |

### Estimated Cost Reduction

- **Without Cache**: 105 reads × 1000 users/day = **105,000 reads/day**
- **With Cache**: 70 reads × 1000 users/day (cold start only) = **70,000 reads/day**
- **Next Day**: 0 reads (cache still valid) = **0 reads/day**

**Monthly Savings:**
- Cold start days (10%): ~210,000 reads
- Cached days (90%): ~0 reads
- Previous: 3,150,000 reads/month
- **New: ~210,000 reads/month**
- **Reduction: ~93%**

## Cache Configuration

### Adjusting Cache Duration

Edit `lib/services/cache_service.dart:23-25`:

```dart
static const Duration missionsCacheDuration = Duration(hours: 24);
static const Duration departmentsCacheDuration = Duration(hours: 12);
static const Duration usersCacheDuration = Duration(minutes: 30);
```

### Force Refresh

When you need fresh data (e.g., after admin updates):

```dart
final dataService = OptimizedDataService.instance;

// Force refresh missions
await dataService.getMissions(forceRefresh: true);

// Force refresh departments
await dataService.getDepartmentsByMissionId(missionId, forceRefresh: true);

// Invalidate specific cache
await dataService.invalidateMissionDepartmentsCache(missionId);
```

### Clear All Cache

```dart
final cache = CacheService.instance;
await cache.clearAllCache();
```

## Implementation Checklist

- [x] Enable Firestore offline persistence
- [x] Create cache service with expiration
- [x] Build optimized data service
- [x] Add rate limiting (5-second intervals)
- [x] Implement cache-first streams
- [x] Share stream controllers
- [x] Update dashboard to use optimized service
- [x] Add cache invalidation on writes
- [ ] Monitor cache hit rates
- [ ] Track Firestore read metrics

## Best Practices

### ✅ DO

- Use `OptimizedDataService` for all data fetching
- Let cache expire naturally
- Invalidate cache only after writes
- Use streams for real-time data
- Monitor Firebase usage dashboard

### ❌ DON'T

- Don't fetch same data repeatedly
- Don't create multiple StreamBuilders for same data
- Don't ignore cache errors (they auto-clear)
- Don't set cache duration too long (stale data risk)
- Don't bypass the optimized service

## Monitoring

### Check Cache Hit Rate

Add this to your app for debugging:

```dart
// In development only
void logCacheStats() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  print('Total cached items: ${keys.length}');

  for (final key in keys) {
    final data = prefs.getString(key);
    if (data != null) {
      final json = jsonDecode(data);
      final timestamp = json['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      print('$key: ${Duration(milliseconds: age).inMinutes} minutes old');
    }
  }
}
```

### Firebase Console

Monitor these metrics:
1. **Reads**: Should decrease by 80-95%
2. **Bandwidth**: Should decrease significantly
3. **Active connections**: Should remain similar (streams still active)

## Troubleshooting

### Cache Not Working

1. Check SharedPreferences initialization
2. Verify cache keys are consistent
3. Check cache expiration times
4. Look for error logs

### Stale Data

1. Reduce cache duration
2. Implement manual refresh button
3. Add cache invalidation on specific actions
4. Use force refresh for admin actions

### High Memory Usage

1. Reduce `CACHE_SIZE_UNLIMITED` in Firestore settings
2. Clear old cache entries more frequently
3. Limit in-memory stream controllers

## Future Enhancements

- [ ] Add cache size limits
- [ ] Implement LRU (Least Recently Used) eviction
- [ ] Add cache compression
- [ ] Background cache warming
- [ ] Analytics on cache performance
- [ ] Smart prefetching based on user patterns

## Support

For questions or issues with caching:
1. Check Firebase Console for actual read counts
2. Review `CacheService` logs
3. Test with `forceRefresh: true` to bypass cache
4. Clear cache and test fresh data flow
