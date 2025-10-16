# Version 3.0.2 Release Notes

## Overview
This release focuses on critical Android compatibility updates to ensure the app remains fully compliant with Google Play's requirements for Android 15 compatibility.

## Android Compatibility Updates
- Added support for 16 KB memory page sizes as required for Android 15+
- Updated target SDK to Android 15 (API level 35)
- Optimized native library handling for compatibility with newer Android versions
- Implemented proper resource alignment for 16 KB pages

## Why This Update Is Important
Google Play requires all apps targeting Android 15+ to support 16 KB memory page sizes by November 1, 2025. Without this update, no new versions could be published after that date.

## Other Improvements
- Further refined UI layouts and performance
- Continued improvements to the report generation system

## Technical Updates
- Updated build number from 12 to 13
- Updated version from 3.0.1 to 3.0.2
- Modified Gradle configuration for Android 15+ compatibility

---
*Release Date: October 10, 2025*
