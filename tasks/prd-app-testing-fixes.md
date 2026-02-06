# PRD: TutorNotification App Testing & Bug Fixes

## Introduction

This PRD documents the testing performed on the TutorNotification Flutter app and the bug fixes required to ensure all features work correctly on Android emulator. The focus is on fixing discovered issues and ensuring end-to-end functionality.

## Goals

- Fix all bugs discovered during comprehensive app testing
- Ensure all Firestore composite indexes are properly configured
- Verify all core features work without errors
- Document all fixes for future reference

## User Stories

### US-001: Fix Batch Schedule Time Display Bug
**Description:** As a teacher, I want to see the correct batch schedule time format so I can quickly identify when classes occur.

**Acceptance Criteria:**
- [x] Batch cards display time in "HH:MM - HH:MM" format (e.g., "09:00 - 10:00")
- [x] No Dart closure references displayed (e.g., "Closure: () => String...")
- [x] Time format consistent across Home, Batches, and Attendance screens
- [x] `flutter analyze` passes with no errors

**Fix Applied:**
- File: `lib/models/batch.dart:87`
- Changed: `${startTime.format24h}` → `${startTime.format24h()}`
- Root cause: Method reference instead of method call

---

### US-002: Create Students Collection Composite Index
**Description:** As a developer, I need the correct Firestore index for querying students so the students list loads without errors.

**Acceptance Criteria:**
- [x] Create composite index: `students` collection with `isActive` (Asc), `name` (Asc)
- [x] Index status shows "Enabled" in Firebase Console
- [x] Students list loads without "failed-precondition" error
- [x] Students can be added to batches successfully

**Fix Applied:**
- Created index via Firebase Console
- Previous incorrect index: `batchId, name` (batchId is path, not query field)
- Correct index: `isActive, name` (matches actual query filters)

---

### US-003: Create Attendance Date Range Index
**Description:** As a developer, I need the correct Firestore index for querying attendance by date so the Reports tab shows today's attendance.

**Acceptance Criteria:**
- [x] Create composite index: `attendance` collection with `batchId` (Asc), `date` (Asc)
- [x] Reports "Today" tab shows attendance records for current day
- [x] Today's Summary on Home screen shows correct counts
- [x] No "failed-precondition" errors on Reports screen

**Fix Applied:**
- Created index via Firebase Console: `attendance` → `batchId (Asc), date (Asc)`
- Query requires composite index because it combines `batchId` equality with `date` range filters

---

### US-004: Verify Add Student Flow
**Description:** As a teacher, I want to add students to a batch so I can mark their attendance.

**Acceptance Criteria:**
- [x] "Add Student" dialog opens from batch details
- [x] Form accepts student name and parent phone (10 digits)
- [x] Student appears in list after adding
- [x] Student data saved to Firestore correctly
- [x] `flutter analyze` passes with no errors

---

### US-005: Verify Mark Attendance Flow
**Description:** As a teacher, I want to mark attendance for students so parents are notified.

**Acceptance Criteria:**
- [x] Attendance screen shows all students in batch
- [x] Tapping student cycles status: Unmarked → Present → Absent → Late
- [x] Status counters update in real-time
- [x] Confirmation dialog shows attendance summary before submit
- [x] Attendance record created in Firestore after submit
- [x] `flutter analyze` passes with no errors

---

### US-006: Verify Reports Display
**Description:** As a teacher, I want to view attendance reports so I can track patterns.

**Acceptance Criteria:**
- [x] Reports tab has three sub-tabs: Today, Absent, Monthly
- [x] Today tab shows attendance summary when data exists (1 Present, 0 Absent, 0 Late)
- [x] Absent tab lists students marked absent today
- [x] No errors when viewing Reports
- [x] `flutter analyze` passes with no errors

**Verified:** Reports tab working correctly after attendance index creation

---

### US-007: Fix Dart Type Safety Errors
**Description:** As a developer, I need all Firestore data access to use proper type casting so the app compiles without errors and handles null/missing data gracefully.

**Acceptance Criteria:**
- [x] All `fromFirestore` factory methods use explicit type casting
- [x] Pattern: `(data['key'] as Type?) ?? defaultValue` for required fields
- [x] Pattern: `data['key'] as Type?` for optional fields
- [x] `flutter analyze` passes with 0 errors
- [x] App builds and runs correctly on emulator

**Fix Applied:**
- Root cause: Firestore returns `Map<String, dynamic>` where values are `dynamic` type
- The `??` operator with dynamic still returns dynamic, causing type mismatches
- Solution: Explicit cast before null-coalescing: `(data['key'] as String?) ?? ''`

**Files Fixed:**
- `lib/models/attendance.dart` - AttendanceRecord, StudentAttendance
- `lib/models/audit_log.dart` - AuditLog
- `lib/models/batch.dart` - Batch, ScheduleTime
- `lib/models/institute.dart` - Institute, InstituteSettings, NotificationTemplates
- `lib/models/student.dart` - Student
- `lib/models/teacher.dart` - Teacher, TeacherInvitation
- `lib/providers/report_providers.dart` - NotificationStatusEntry
- `lib/screens/students/student_list_screen.dart` - CSV import
- `test/widget_test.dart` - Updated to minimal smoke test

---

## Functional Requirements

- **FR-1:** All Firestore queries must have corresponding composite indexes
- **FR-2:** Time display methods must be called with parentheses `()`
- **FR-3:** Student queries filter by `isActive` and order by `name`
- **FR-4:** Attendance queries filter by date range for daily reports
- **FR-5:** All UI elements must show meaningful data, not raw code

## Non-Goals (Out of Scope)

- WhatsApp/SMS notification implementation (separate feature)
- iOS testing (Android-first)
- Performance optimization
- UI/UX improvements

## Technical Considerations

### Firestore Indexes Required

| Collection | Fields | Scope | Status |
|------------|--------|-------|--------|
| batches | isActive (Asc), name (Asc) | Collection | ✅ Enabled |
| students | isActive (Asc), name (Asc) | Collection | ✅ Enabled |
| students | batchId (Asc), name (Asc) | Collection | ✅ Enabled |
| teacherInvitations | isAccepted (Asc), phone (Asc), invitedAt (Desc) | Collection | ✅ Enabled |
| attendance | batchId (Asc), date (Asc) | Collection | ✅ Enabled |

### Files Modified

| File | Line(s) | Change |
|------|---------|--------|
| `lib/models/batch.dart` | 87 | Fixed method call syntax |
| `lib/models/attendance.dart` | 127-139, 195-207 | Type casting in fromFirestore |
| `lib/models/audit_log.dart` | 111-123 | Type casting in fromFirestore |
| `lib/models/batch.dart` | 28-41, 98-102 | Type casting in fromFirestore, fromMap |
| `lib/models/institute.dart` | 28-41, 96-101, 126-132 | Type casting in all fromFirestore/fromMap |
| `lib/models/student.dart` | 24-36 | Type casting in fromFirestore |
| `lib/models/teacher.dart` | 50-61, 135-147 | Type casting in fromFirestore |
| `lib/providers/report_providers.dart` | 63-72 | Type casting in stream map |
| `lib/screens/students/student_list_screen.dart` | 510-518, 576-582 | Type casting for CSV import |
| `test/widget_test.dart` | 1-14 | Replaced with minimal smoke test |

## Success Metrics

- All core features work without Firestore index errors
- Attendance can be marked and viewed in reports
- No closure/method reference display bugs
- App passes `flutter analyze` with no errors

## Open Questions

1. Is the attendance date field using consistent timezone handling?
2. Should we add error handling/retry for index building delays?
