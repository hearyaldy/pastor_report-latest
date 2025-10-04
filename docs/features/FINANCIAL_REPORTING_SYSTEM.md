# Financial Reporting System - District Tithe & Offering Tracking

## Overview

This document outlines the implementation plan for a comprehensive financial reporting system that allows church treasurers to submit tithe and offering data, district pastors to compile reports, and mission administrators to view overall financial statistics.

## Problem Statement

**Current Challenge:** District pastors need accurate, up-to-date information on tithe and offering collections from each church in their district. Currently:
- Data is stored locally on individual devices
- No centralized collection point
- No aggregation at district or mission level
- Manual compilation required

## Organizational Hierarchy

```
Mission (Highest Level)
  └── Region
      └── District (Pastor manages this level)
          └── Local Church (Treasurer enters data here)
```

### Hierarchy Levels

1. **Mission** - Highest organizational level (e.g., Sabah Mission)
2. **Region** - Geographic grouping of districts (optional/future)
3. **District** - Collection of churches managed by one district pastor
4. **Local Church** - Individual church with treasurer and members

## Current State Analysis

### ✅ What Already Exists

#### 1. User Model
- Location: `lib/models/user_model.dart:47-172`
- Has fields: `mission`, `district`, `region`
- Role system: `user`, `editor`, `missionAdmin`, `admin`, `superAdmin`
- **Gap:** No specific roles for "district pastor" or "church treasurer"

#### 2. Mission Structure
- Location: `lib/models/mission_model.dart:5-81`
- Stored in Firestore collection: `missions`
- Can have departments linked to missions
- **Gap:** No region or district sub-collections

#### 3. Church Model
- Location: `lib/models/church_model.dart:1-113`
- Fields: `userId`, `churchName`, `elderName`, `status`, `memberCount`
- **Gap:** No link to district, region, or mission

#### 4. Borang B Report (Monthly Ministerial Report)
- Location: `lib/models/borang_b_model.dart:5-267`
- **Already has `tithe` and `offerings` fields!** (lines 45-46, 82-83)
- Storage: Local only via SharedPreferences (`lib/services/borang_b_storage_service.dart`)
- **Critical Gap:** NOT synced to Firestore - each pastor's data stays on their device

### ❌ What's Missing

1. **No Region or District Models/Collections**
   - These organizational levels don't exist in Firestore

2. **No Church-District-Region-Mission Linking**
   - Churches aren't linked to districts
   - Districts aren't defined as collections
   - No hierarchical relationship

3. **No Tithe/Offering Aggregation**
   - Borang B data is local only, not in cloud
   - No way for district pastor to see all churches' financial data
   - No aggregation at district or mission level

4. **No Role Separation for Treasurer vs Pastor**
   - Current roles don't distinguish between church treasurer and district pastor

5. **No Reporting/Export System for Districts**
   - No way to compile district reports
   - No way to submit reports to mission level

## Solution Architecture

### Data Structure

#### Firestore Collections

```
missions/
  {missionId}/
    - name: string
    - code: string
    - createdAt: timestamp

regions/
  {regionId}/
    - name: string
    - missionId: string (reference)
    - createdAt: timestamp

districts/
  {districtId}/
    - name: string
    - code: string
    - regionId: string (reference)
    - missionId: string (reference)
    - pastorId: string (user reference)
    - createdAt: timestamp

churches/
  {churchId}/
    - name: string
    - districtId: string (reference)
    - regionId: string (reference)
    - missionId: string (reference)
    - treasurerId: string (user reference)
    - elderName: string
    - status: string (church/company/branch)
    - memberCount: number
    - createdAt: timestamp

financial_reports/
  {reportId}/
    - churchId: string (reference)
    - districtId: string (reference)
    - regionId: string (reference)
    - missionId: string (reference)
    - month: timestamp
    - year: number
    - tithe: number
    - offerings: number
    - specialOfferings: number
    - submittedBy: string (user reference)
    - submittedAt: timestamp
    - status: string (draft/submitted/approved)
    - remittanceSlipUrl: string (optional)
```

### User Roles & Permissions

#### Role Definitions

| Role | Access Level | Permissions |
|------|--------------|-------------|
| `churchTreasurer` | Church Level | Enter/edit financial data for assigned church |
| `districtPastor` | District Level | View all churches in assigned district, compile reports |
| `regionalLeader` | Region Level (Future) | View all districts in assigned region |
| `missionAdmin` | Mission Level | View all regions/districts/churches, manage structure |
| `admin` | System Level | Full access to all missions |
| `superAdmin` | Global Level | Full system access |

#### User Model Updates

```dart
// Extended UserModel
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole userRole;

  // Organizational Assignment
  final String? missionId;
  final String? regionId;
  final String? districtId;
  final String? churchId; // For treasurers

  // Permissions
  bool get canEnterFinancialData => userRole == UserRole.churchTreasurer;
  bool get canViewDistrictReports => userRole == UserRole.districtPastor;
  bool get canViewMissionReports => userRole == UserRole.missionAdmin;
}
```

## Implementation Plan

### Phase 1: Organization Structure (Week 1)

**Goal:** Create the Mission → Region → District → Church hierarchy

#### Tasks:

1. **Create Models**
   - [ ] `RegionModel` (`lib/models/region_model.dart`)
   - [ ] `DistrictModel` (`lib/models/district_model.dart`)
   - [ ] Update `ChurchModel` to include `districtId`, `regionId`, `missionId`

2. **Create Services**
   - [ ] `RegionService` for CRUD operations
   - [ ] `DistrictService` for CRUD operations
   - [ ] Update `ChurchStorageService` to use Firestore (currently local)

3. **Admin Screens**
   - [ ] Region Management Screen
   - [ ] District Management Screen
   - [ ] Update Church Management to assign to districts

4. **Firestore Setup**
   - [ ] Create collections: `regions`, `districts`
   - [ ] Update `churches` collection structure
   - [ ] Add indexes for queries

**Deliverables:**
- Functional organizational hierarchy
- Admin can create/manage regions, districts, churches
- Churches linked to districts, districts to regions, regions to missions

---

### Phase 2: User Roles & Assignment (Week 2)

**Goal:** Separate church treasurers from district pastors

#### Tasks:

1. **Update User Model**
   - [ ] Add `districtPastor` and `churchTreasurer` to `UserRole` enum
   - [ ] Add `churchId` field for treasurer assignment
   - [ ] Update `toMap()` and `fromMap()` methods

2. **Update Auth Service**
   - [ ] Handle new roles during registration
   - [ ] Update permission checks

3. **Admin Features**
   - [ ] Assign treasurers to churches
   - [ ] Assign pastors to districts
   - [ ] Role management UI updates

4. **User Dashboard Routing**
   - [ ] Route treasurers to Treasurer Dashboard
   - [ ] Route district pastors to District Dashboard
   - [ ] Route mission admins to Mission Dashboard

**Deliverables:**
- Two distinct user types: Treasurer and District Pastor
- Assignment system in admin panel
- Role-based dashboard routing

---

### Phase 3: Financial Data Collection (Week 3-4)

**Goal:** Enable church treasurers to enter tithe/offering data in Firestore

#### Tasks:

1. **Migrate Borang B to Firestore**
   - [ ] Create `FinancialReportModel` (simplified from Borang B)
   - [ ] Create `FinancialReportService` with Firestore operations
   - [ ] Migration utility to move existing local data to cloud (optional)

2. **Financial Report Model**
```dart
class FinancialReportModel {
  final String id;
  final String churchId;
  final String districtId;
  final String missionId;
  final DateTime month;
  final double tithe;
  final double offerings;
  final double specialOfferings;
  final String? notes;
  final String submittedBy; // treasurerId
  final DateTime submittedAt;
  final String status; // draft, submitted, approved
  final String? remittanceSlipUrl;
}
```

3. **Treasurer Dashboard**
   - [ ] Create `TreasurerDashboard` screen
   - [ ] Financial entry form (tithe, offerings, date)
   - [ ] Submission history view
   - [ ] Remittance slip upload (optional)

4. **Validation & Notifications**
   - [ ] Validate data entry
   - [ ] Auto-reminder for monthly submissions
   - [ ] Confirmation notifications

**Deliverables:**
- Treasurers can enter monthly financial data
- Data stored in Firestore
- Simple, focused treasurer interface
- Submission tracking

---

### Phase 4: District & Mission Aggregation (Week 5)

**Goal:** District pastors can view compiled reports from all their churches

#### Tasks:

1. **District Aggregation Service**
   - [ ] Create `DistrictReportService`
   - [ ] Query all churches in district
   - [ ] Aggregate tithe/offerings by month, quarter, year
   - [ ] Real-time updates with Firestore streams

2. **District Pastor Dashboard**
   - [ ] View all churches in district
   - [ ] District financial summary (total tithe, total offerings)
   - [ ] Breakdown by individual churches
   - [ ] Time period filters (monthly, quarterly, yearly)
   - [ ] Visual charts and graphs

3. **Mission Aggregation**
   - [ ] Create `MissionReportService`
   - [ ] Aggregate all districts in mission
   - [ ] Mission-wide totals and statistics

4. **Report Compilation**
   - [ ] District pastor can compile monthly report
   - [ ] Submit compiled report to mission
   - [ ] Track submission status

**Deliverables:**
- District pastors see live totals from all churches
- Mission admins see overall mission statistics
- Report compilation and submission workflow

---

### Phase 5: Dashboards & Reports (Week 6)

**Goal:** Polished dashboards and export capabilities

#### Tasks:

1. **Enhanced Treasurer Dashboard**
   - [ ] Monthly submission checklist
   - [ ] Historical data view
   - [ ] Edit submitted reports (if allowed)

2. **Enhanced District Dashboard**
   - [ ] Church-by-church comparison
   - [ ] Trend analysis
   - [ ] Missing submissions alerts
   - [ ] Export district report as PDF

3. **Enhanced Mission Dashboard**
   - [ ] Regional breakdowns
   - [ ] District comparisons
   - [ ] Year-over-year analysis
   - [ ] Export mission report as PDF/Excel

4. **Notifications System**
   - [ ] Remind treasurers of submission deadlines
   - [ ] Alert district pastors of missing data
   - [ ] Notify mission admin of completed district reports

**Deliverables:**
- Professional dashboards for all roles
- PDF/Excel export functionality
- Automated notifications
- Analytics and insights

---

## User Workflows

### Workflow 1: Church Treasurer Submits Data

1. Treasurer logs in
2. Routed to Treasurer Dashboard
3. Sees their assigned church
4. Clicks "Submit Monthly Report"
5. Enters:
   - Month/Year
   - Tithe amount
   - Offering amount
   - Special offerings (optional)
   - Notes (optional)
   - Upload remittance slip (optional)
6. Clicks "Submit"
7. Data saved to Firestore → `financial_reports` collection
8. Confirmation shown
9. District pastor sees update in real-time

### Workflow 2: District Pastor Compiles Report

1. District pastor logs in
2. Routed to District Dashboard
3. Sees all churches in their district
4. Views financial summary:
   - Total tithe for current month
   - Total offerings for current month
   - Breakdown by church
5. Can filter by time period (monthly, quarterly, yearly)
6. Reviews which churches haven't submitted
7. Clicks "Compile District Report"
8. Reviews aggregated data
9. Adds district-level notes
10. Clicks "Submit to Mission"
11. Report sent to mission admin
12. Confirmation shown

### Workflow 3: Mission Admin Views Reports

1. Mission admin logs in
2. Routed to Mission Dashboard
3. Sees overview:
   - Total tithe across all districts
   - Total offerings across all districts
   - District-by-district breakdown
4. Can drill down into:
   - Specific regions
   - Specific districts
   - Specific churches
5. Views trends and analytics
6. Exports report as PDF or Excel
7. Shares with conference or stakeholders

---

## Technical Specifications

### Database Indexes (Firestore)

```javascript
// financial_reports collection indexes
financial_reports:
  - churchId (ASC) + month (DESC)
  - districtId (ASC) + month (DESC)
  - missionId (ASC) + month (DESC)
  - submittedBy (ASC) + month (DESC)
  - status (ASC) + month (DESC)
```

### Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Financial Reports
    match /financial_reports/{reportId} {
      // Treasurers can create/edit their own church's reports
      allow create: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'churchTreasurer'
        && request.resource.data.churchId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.churchId;

      // Treasurers can read/update their own church's reports
      allow read, update: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'churchTreasurer'
        && resource.data.churchId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.churchId;

      // District pastors can read all reports in their district
      allow read: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'districtPastor'
        && resource.data.districtId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.districtId;

      // Mission admins can read all reports in their mission
      allow read: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'missionAdmin'
        && resource.data.missionId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.missionId;

      // Admins and superAdmins can do everything
      allow read, write: if request.auth != null
        && (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'admin'
        || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'superAdmin');
    }

    // Churches - district pastors can read their churches
    match /churches/{churchId} {
      allow read: if request.auth != null
        && (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'districtPastor'
        && resource.data.districtId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.districtId);
    }

    // Districts - mission admins can read their districts
    match /districts/{districtId} {
      allow read: if request.auth != null
        && (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'missionAdmin'
        && resource.data.missionId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.missionId);
    }
  }
}
```

### API Endpoints (Firebase Functions - Optional)

```javascript
// Cloud Functions for aggregation (if needed for performance)

// 1. Aggregate district financial data
exports.aggregateDistrictFinancials = functions.firestore
  .document('financial_reports/{reportId}')
  .onWrite(async (change, context) => {
    // Recalculate district totals when a report is added/updated/deleted
  });

// 2. Send reminder notifications
exports.sendMonthlyReminders = functions.pubsub
  .schedule('0 9 25 * *') // 9 AM on the 25th of each month
  .onRun(async (context) => {
    // Send reminders to treasurers who haven't submitted
  });
```

---

## UI Mockups

### Treasurer Dashboard

```
┌─────────────────────────────────────────────────────┐
│  Financial Entry - [Church Name]                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  📅 Month: [December 2025 ▼]                        │
│                                                      │
│  💰 Tithe:           RM [________]                   │
│  🎁 Offerings:       RM [________]                   │
│  ⭐ Special Offerings: RM [________] (Optional)      │
│                                                      │
│  📝 Notes: [________________________]               │
│                                                      │
│  📎 Remittance Slip: [Upload] (Optional)            │
│                                                      │
│  [Submit Report]  [Save as Draft]                   │
│                                                      │
│  ─────────────────────────────────────────────────  │
│                                                      │
│  📊 Submission History                              │
│  ✅ November 2025 - RM 5,000 (Tithe) + RM 2,000     │
│  ✅ October 2025 - RM 4,800 (Tithe) + RM 1,800      │
│  ✅ September 2025 - RM 5,200 (Tithe) + RM 2,100    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### District Pastor Dashboard

```
┌─────────────────────────────────────────────────────┐
│  District Financial Overview - [District Name]      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  📅 Period: [December 2025 ▼]                       │
│                                                      │
│  ┌──────────────────┬──────────────────┐            │
│  │  Total Tithe     │  Total Offerings │            │
│  │  RM 45,000       │  RM 18,000       │            │
│  └──────────────────┴──────────────────┘            │
│                                                      │
│  📊 Churches (8/10 Submitted)                       │
│  ┌─────────────────────────────────────────┐        │
│  │ ✅ Church A    RM 8,000  | RM 3,000     │        │
│  │ ✅ Church B    RM 6,500  | RM 2,500     │        │
│  │ ✅ Church C    RM 5,200  | RM 2,100     │        │
│  │ ⏳ Church D    (Pending submission)     │        │
│  │ ⏳ Church E    (Pending submission)     │        │
│  └─────────────────────────────────────────┘        │
│                                                      │
│  [📈 View Trends]  [📄 Export PDF]                  │
│  [📧 Remind Pending Churches]                       │
│  [✅ Compile & Submit to Mission]                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Mission Admin Dashboard

```
┌─────────────────────────────────────────────────────┐
│  Mission Financial Overview - [Mission Name]        │
├─────────────────────────────────────────────────────┤
│                                                      │
│  📅 Period: [Q4 2025 ▼]                             │
│                                                      │
│  ┌──────────────────┬──────────────────┐            │
│  │  Total Tithe     │  Total Offerings │            │
│  │  RM 450,000      │  RM 180,000      │            │
│  └──────────────────┴──────────────────┘            │
│                                                      │
│  📊 By District                                     │
│  ┌─────────────────────────────────────────┐        │
│  │ District 1    RM 120K | RM 48K | ✅     │        │
│  │ District 2    RM 95K  | RM 38K | ✅     │        │
│  │ District 3    RM 110K | RM 44K | ✅     │        │
│  │ District 4    RM 85K  | RM 34K | ⏳     │        │
│  └─────────────────────────────────────────┘        │
│                                                      │
│  📈 Trend Chart                                     │
│  [Bar/Line Chart showing monthly trends]            │
│                                                      │
│  [📊 Detailed Analytics]  [📄 Export Report]        │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## Benefits

### For Church Treasurers
✅ Simple, focused interface for data entry
✅ No complex forms - just tithe and offerings
✅ Mobile-friendly for remote areas
✅ Offline capability with auto-sync
✅ Submission history tracking

### For District Pastors
✅ Real-time visibility into all church finances
✅ Accurate, up-to-date data (no manual compilation)
✅ Easy identification of missing submissions
✅ Professional reports for mission submission
✅ Trend analysis and insights

### For Mission Administrators
✅ Complete overview of mission finances
✅ District-by-district comparison
✅ Data-driven decision making
✅ Easy export for conference reporting
✅ Transparency across the organization

### For the Organization
✅ **Accuracy:** Direct entry reduces transcription errors
✅ **Timeliness:** Real-time updates instead of waiting for physical reports
✅ **Transparency:** Everyone sees the same verified data
✅ **Compliance:** Built-in reminders ensure timely reporting
✅ **Accountability:** Clear audit trail of who submitted what and when

---

## Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Organization Structure | Week 1 | Region/District/Church hierarchy |
| Phase 2: User Roles | Week 2 | Treasurer and District Pastor roles |
| Phase 3: Financial Collection | Week 3-4 | Treasurer data entry system |
| Phase 4: Aggregation | Week 5 | District and Mission reports |
| Phase 5: Polish & Export | Week 6 | Dashboards and PDF exports |

**Total Estimated Time:** 6 weeks

---

## Future Enhancements

### Phase 6+ (Optional)
- [ ] Multi-currency support
- [ ] Budget planning and tracking
- [ ] Expense reporting
- [ ] Financial forecasting with AI
- [ ] Integration with accounting software
- [ ] Mobile app (native iOS/Android)
- [ ] SMS notifications for areas with limited internet
- [ ] Bulk import from Excel
- [ ] Advanced analytics dashboard
- [ ] Conference-level aggregation

---

## Technical Dependencies

### Required Packages
- `cloud_firestore`: Already installed ✅
- `firebase_storage`: For remittance slip uploads (if needed)
- `pdf`: Already installed ✅ (for PDF export)
- `excel`: Already installed ✅ (for Excel export)
- `charts_flutter` or `fl_chart`: For data visualization
- `firebase_messaging`: For push notifications (optional)

### Firebase Setup
- Firestore database (already set up)
- Storage bucket (for file uploads)
- Cloud Functions (optional, for aggregations)
- Cloud Messaging (optional, for notifications)

---

## Success Metrics

### Key Performance Indicators (KPIs)

1. **Submission Rate**
   - Target: 90%+ of churches submit monthly reports on time
   - Measure: (Churches submitted / Total churches) × 100

2. **Data Accuracy**
   - Target: <5% discrepancy between reported and actual remittances
   - Measure: Audit matching with bank deposits

3. **Time Savings**
   - Target: 80% reduction in time spent compiling reports
   - Measure: Before (manual) vs After (automated)

4. **User Adoption**
   - Target: 80%+ of treasurers actively using the system
   - Measure: Active users / Total registered treasurers

5. **Report Turnaround**
   - Target: District reports submitted within 3 days of month-end
   - Measure: Days between month-end and submission

---

## Risk Mitigation

### Potential Risks & Solutions

| Risk | Impact | Mitigation |
|------|--------|------------|
| Low internet connectivity in rural areas | High | Offline mode with auto-sync when online |
| User resistance to new system | Medium | Training videos, simple UI, gradual rollout |
| Data security concerns | High | Firestore security rules, encryption, audit logs |
| Incorrect data entry | Medium | Validation rules, confirmation prompts |
| System downtime | Low | Firebase 99.95% uptime SLA, backup exports |

---

## Conclusion

This Financial Reporting System will transform how the mission tracks tithe and offerings, providing:
- **Real-time visibility** for district pastors
- **Simplified data entry** for church treasurers
- **Comprehensive analytics** for mission administrators
- **Reduced manual work** across the organization
- **Improved accuracy** and accountability

By leveraging Firebase Firestore and the existing app infrastructure, this system can be implemented incrementally over 6 weeks with minimal disruption to current operations.

---

**Document Version:** 1.0
**Last Updated:** 2025-10-04
**Author:** Claude Code
**Status:** Proposal - Awaiting Approval
