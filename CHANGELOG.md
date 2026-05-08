# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.7] - 2025-04-XX

### Added
- RELEASE_NOTES.md file with detailed release information
- Enhanced caching mechanisms for dashboard data
- Bulk loading methods for churches, districts, and departments

### Changed
- Updated app version to 3.0.7+1
- Modernized department webview page to match app styling
- Optimized dashboard loading with cached futures
- Reduced database reads with efficient querying

### Fixed
- Infinite loading loops in dashboard sections
- Memory leaks in authentication provider
- Excessive logging that was degrading performance
- Continuous rebuild issues in department management

### Performance
- Reduced Firestore read operations by ~70%
- Improved memory management with proper stream disposal
- Faster UI response with smarter data loading
- Eliminated continuous loading states

## [3.0.6] - 2025-03-XX

### Added
- Initial release with core functionality
- Basic dashboard implementation
- Department management features
- Financial reporting capabilities

[3.0.7]: https://github.com/hearyhealdysairin/pastor_report/compare/v3.0.6...v3.0.7
[3.0.6]: https://github.com/hearyhealdysairin/pastor_report/releases/tag/v3.0.6