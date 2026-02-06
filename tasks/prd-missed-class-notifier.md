# PRD: Missed Class Notifier

## Introduction

Missed Class Notifier is a mobile application (Android-first, iOS later) that enables coaching centres, tuition institutes, and extracurricular classes to digitally mark student attendance and automatically notify parents in real-time. The core value proposition is **trust**: parents immediately know if their child attended, missed, or left early—without requiring the child to carry a phone.

**Target Users:**
- **Institute Admin/Teacher**: Uses app on shared classroom device to mark attendance
- **Parent**: Receives instant notifications via WhatsApp/SMS (no app required for MVP)

**Key Differentiators:**
- No child-side app or device required
- Works offline with automatic sync
- WhatsApp-first notifications (instant, free for parents)
- Zero complexity for teachers (tap-based UI)

## Goals

- Enable teachers to mark attendance for a batch in under 60 seconds
- Deliver parent notifications within 30 seconds of attendance submission
- Support 100% offline attendance marking with automatic sync
- Achieve 95%+ notification delivery rate (WhatsApp + SMS fallback)
- Onboard an institute with 50+ students in under 10 minutes (CSV upload)
- Launch MVP in 4-6 weeks for validation with 3-5 pilot institutes

## User Stories

### Epic 1: Institute & Batch Management

#### US-001: Institute Registration
**Description:** As an institute admin, I want to register my coaching centre so I can start managing attendance digitally.

**Acceptance Criteria:**
- [ ] Registration form: Institute name, admin name, phone number, email
- [ ] OTP verification via SMS for phone number
- [ ] Create institute record in Firestore with unique ID
- [ ] Redirect to dashboard after successful registration
- [ ] `flutter analyze` passes with no errors

#### US-002: Create Batch/Class
**Description:** As an institute admin, I want to create batches (e.g., "Class 10 Maths - Morning") so I can organize students by class.

**Acceptance Criteria:**
- [ ] Form fields: Batch name, subject (optional), schedule (days of week), start time, end time
- [ ] Batch saved to Firestore under institute document
- [ ] Batch appears in dashboard batch list
- [ ] Support for multiple batches per institute
- [ ] `flutter analyze` passes with no errors

#### US-003: Add Student Manually
**Description:** As a teacher, I want to add a student to a batch by entering their name and parent phone number.

**Acceptance Criteria:**
- [ ] Form fields: Student name, parent phone (required), student ID (optional)
- [ ] Phone number validation (10-digit Indian mobile)
- [ ] Student saved to batch's student subcollection
- [ ] Duplicate phone number warning (same student in same batch)
- [ ] `flutter analyze` passes with no errors

#### US-004: Bulk Import Students via CSV
**Description:** As an institute admin, I want to upload a CSV/Excel file to add multiple students at once so I can onboard quickly.

**Acceptance Criteria:**
- [ ] Accept CSV file with columns: student_name, parent_phone, student_id (optional)
- [ ] Preview imported data before confirming
- [ ] Show validation errors (invalid phone numbers, missing names)
- [ ] Skip invalid rows, import valid ones
- [ ] Display import summary (X imported, Y skipped)
- [ ] `flutter analyze` passes with no errors

#### US-005: Edit/Remove Student
**Description:** As a teacher, I want to edit student details or remove a student who has left the batch.

**Acceptance Criteria:**
- [ ] Edit button on student list item
- [ ] Update student name, parent phone, or student ID
- [ ] Delete student with confirmation dialog
- [ ] Soft delete (mark inactive) to preserve attendance history
- [ ] `flutter analyze` passes with no errors

---

### Epic 2: Attendance Marking

#### US-006: View Today's Attendance Screen
**Description:** As a teacher, I want to see a list of all students in a batch so I can mark attendance quickly.

**Acceptance Criteria:**
- [ ] Select batch from dropdown or batch list
- [ ] Display all active students in large, tap-friendly cards
- [ ] Show student name prominently (large font for low-light classrooms)
- [ ] Default status: unmarked (gray)
- [ ] Date shown at top (auto-selects today)
- [ ] `flutter analyze` passes with no errors

#### US-007: Mark Individual Attendance
**Description:** As a teacher, I want to tap a student's name to cycle through attendance states (Present/Absent/Late).

**Acceptance Criteria:**
- [ ] Tap cycles: Unmarked → Present (green) → Absent (red) → Late (yellow) → Unmarked
- [ ] Large touch targets (minimum 48x48dp, preferably larger)
- [ ] Visual feedback: color change + icon (✓, ✗, ⏰)
- [ ] Haptic feedback on tap
- [ ] State saved locally immediately (offline-first)
- [ ] `flutter analyze` passes with no errors

#### US-008: Mark All Present / All Absent
**Description:** As a teacher, I want a quick action to mark everyone present (common case) so I only need to adjust exceptions.

**Acceptance Criteria:**
- [ ] "Mark All Present" button at top of attendance screen
- [ ] "Mark All Absent" button (for cancelled class scenario)
- [ ] Confirmation dialog before bulk action
- [ ] Can still individually adjust after bulk mark
- [ ] `flutter analyze` passes with no errors

#### US-009: Submit Attendance
**Description:** As a teacher, I want to submit attendance for a batch so notifications are sent to parents.

**Acceptance Criteria:**
- [ ] "Submit Attendance" button (prominent, bottom of screen)
- [ ] Confirmation dialog showing summary: X Present, Y Absent, Z Late
- [ ] Prevent submission if any student unmarked (with option to mark remaining absent)
- [ ] Save attendance record to Firestore with timestamp
- [ ] Trigger Cloud Function to send notifications
- [ ] Show success message with delivery status
- [ ] `flutter analyze` passes with no errors

#### US-010: Offline Attendance Marking
**Description:** As a teacher, I want attendance marking to work even without internet so I can use it in basements or rural areas.

**Acceptance Criteria:**
- [ ] All attendance marks saved to local Firestore cache immediately
- [ ] Visual indicator when offline (banner or icon)
- [ ] Queue attendance submission for when online
- [ ] Auto-sync when internet restored
- [ ] No data loss if app closed while offline
- [ ] Show "Pending sync" indicator for unsynced attendance
- [ ] `flutter analyze` passes with no errors

#### US-011: Edit Attendance Within Time Window
**Description:** As a teacher, I want to edit today's attendance within 2 hours of submission to fix mistakes.

**Acceptance Criteria:**
- [ ] Edit button on submitted attendance (only within 2-hour window)
- [ ] Load previously marked attendance for editing
- [ ] Track edit in audit log (original value, new value, timestamp, user)
- [ ] Re-send corrected notification to affected parents only
- [ ] Disable editing after time window expires
- [ ] `flutter analyze` passes with no errors

---

### Epic 3: Parent Notifications

#### US-012: Send WhatsApp Notification
**Description:** As a parent, I want to receive a WhatsApp message when my child's attendance is marked so I know immediately.

**Acceptance Criteria:**
- [ ] Cloud Function triggered on attendance submission
- [ ] Use WhatsApp Business API (via Twilio/Gupshup)
- [ ] Message template: "[Institute] Attendance for [Date]: [Student] was [PRESENT/ABSENT/LATE] for [Batch] at [Time]"
- [ ] Include institute name for context
- [ ] Log delivery status (sent, delivered, read, failed)
- [ ] `firebase deploy` succeeds for Cloud Functions

#### US-013: SMS Fallback Notification
**Description:** As a parent without WhatsApp, I want to receive an SMS so I still get notified.

**Acceptance Criteria:**
- [ ] If WhatsApp delivery fails after 60 seconds, send SMS
- [ ] Use Twilio SMS API
- [ ] Shorter message format for SMS character limits
- [ ] Log SMS delivery status
- [ ] Track costs per message for billing
- [ ] `firebase deploy` succeeds for Cloud Functions

#### US-014: Notification Delivery Confirmation
**Description:** As a teacher, I want to see if notifications were delivered so I know parents received them.

**Acceptance Criteria:**
- [ ] After submission, show delivery status per student
- [ ] Icons: ✓ Delivered (WhatsApp), ✓ Sent (SMS), ⚠️ Failed
- [ ] Retry button for failed notifications
- [ ] Store delivery status in attendance record
- [ ] `flutter analyze` passes with no errors

---

### Epic 4: Reports & History

#### US-015: View Daily Attendance Report
**Description:** As a teacher, I want to see today's attendance summary across all batches.

**Acceptance Criteria:**
- [ ] Dashboard shows: Total students, Present count, Absent count, Late count
- [ ] Per-batch breakdown
- [ ] Tap batch to see individual student statuses
- [ ] `flutter analyze` passes with no errors

#### US-016: View Absent Students List
**Description:** As an institute admin, I want to see a list of all absent students today so I can follow up.

**Acceptance Criteria:**
- [ ] Filter: Today's absences across all batches
- [ ] Show: Student name, batch, parent phone
- [ ] Option to manually call parent (tap to dial)
- [ ] `flutter analyze` passes with no errors

#### US-017: View Student Attendance History
**Description:** As a teacher, I want to see a student's attendance history to identify patterns.

**Acceptance Criteria:**
- [ ] Tap student to view history
- [ ] Calendar view with color-coded days (green/red/yellow)
- [ ] Monthly attendance percentage
- [ ] List view of recent attendance records
- [ ] `flutter analyze` passes with no errors

#### US-018: Monthly Attendance Summary
**Description:** As an institute admin, I want to generate a monthly attendance report for records.

**Acceptance Criteria:**
- [ ] Select month and batch
- [ ] Show: Total classes, attendance percentage per student
- [ ] Export as PDF or shareable image
- [ ] `flutter analyze` passes with no errors

---

### Epic 5: Authentication & Security

#### US-019: Phone OTP Login
**Description:** As a teacher, I want to log in using my phone number and OTP so I don't need to remember passwords.

**Acceptance Criteria:**
- [ ] Phone number input screen
- [ ] Send OTP via Firebase Auth
- [ ] OTP verification screen (6 digits)
- [ ] Auto-read OTP on Android (SMS Retriever API)
- [ ] Create/link user to institute on first login
- [ ] Persist session (stay logged in)
- [ ] `flutter analyze` passes with no errors

#### US-020: Multi-Teacher Support
**Description:** As an institute admin, I want to add multiple teachers who can mark attendance.

**Acceptance Criteria:**
- [ ] Invite teacher by phone number
- [ ] Teacher receives SMS with app link
- [ ] Teacher registers and links to institute
- [ ] Role-based access: Admin (full access) vs Teacher (attendance only)
- [ ] `flutter analyze` passes with no errors

#### US-021: Audit Log
**Description:** As an institute admin, I want to see who marked/edited attendance for accountability.

**Acceptance Criteria:**
- [ ] Log every attendance action: mark, submit, edit
- [ ] Store: timestamp, user ID, action type, old value, new value
- [ ] View audit log in admin settings
- [ ] Cannot delete audit logs
- [ ] `flutter analyze` passes with no errors

---

### Epic 6: Settings & Configuration

#### US-022: Edit Institute Profile
**Description:** As an institute admin, I want to update my institute's name and contact details.

**Acceptance Criteria:**
- [ ] Edit: Institute name, address, contact phone, logo (optional)
- [ ] Logo appears in notification messages (WhatsApp only)
- [ ] `flutter analyze` passes with no errors

#### US-023: Configure Notification Templates
**Description:** As an institute admin, I want to customize the notification message format.

**Acceptance Criteria:**
- [ ] Default templates for Present/Absent/Late
- [ ] Editable message with placeholders: {student}, {batch}, {date}, {time}, {status}
- [ ] Preview before saving
- [ ] Language selection (English, Hindi for MVP)
- [ ] `flutter analyze` passes with no errors

#### US-024: Set Attendance Edit Window
**Description:** As an institute admin, I want to configure how long teachers can edit attendance after submission.

**Acceptance Criteria:**
- [ ] Setting: Edit window duration (30 min / 1 hour / 2 hours / same day)
- [ ] Default: 2 hours
- [ ] Applies to all batches in institute
- [ ] `flutter analyze` passes with no errors

---

## Functional Requirements

- **FR-1:** App must work offline; attendance marks saved locally and synced when online
- **FR-2:** Attendance submission triggers Cloud Function within 5 seconds
- **FR-3:** WhatsApp notification sent within 30 seconds of submission (when online)
- **FR-4:** SMS fallback triggered if WhatsApp fails after 60 seconds
- **FR-5:** All phone numbers validated as 10-digit Indian mobile numbers
- **FR-6:** Attendance can only be edited within configurable time window
- **FR-7:** All attendance changes logged in immutable audit trail
- **FR-8:** CSV import supports UTF-8 encoding for Indian names
- **FR-9:** App UI minimum touch target: 48x48dp for accessibility
- **FR-10:** Session persists until explicit logout

## Non-Goals (Out of Scope for MVP)

- **No GPS/location tracking** - Privacy concern, not needed for core value
- **No biometric attendance** - Hardware dependency, adds complexity
- **No child-side app** - Core differentiator: child doesn't need phone
- **No fee management** - Separate problem, avoid scope creep
- **No parent app for MVP** - WhatsApp/SMS notifications sufficient
- **No class scheduling/timetable** - Just attendance for now
- **No iOS for MVP** - Android-first, iOS after validation
- **No multi-language UI for MVP** - English first, Hindi/regional later
- **No video/photo attendance proof** - Adds friction for teachers
- **No integration with school ERPs** - B2B complexity for later

## Technical Considerations

### Tech Stack
- **Mobile:** Flutter 3.x (Dart)
- **Backend:** Firebase (Firestore, Cloud Functions, Auth, Cloud Messaging)
- **Notifications:** WhatsApp Business API (Twilio/Gupshup) + Twilio SMS
- **State Management:** Riverpod or Provider
- **Offline:** Firestore offline persistence (built-in)

### Architecture
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│   Firestore     │────▶│ Cloud Functions │
│  (Teacher)      │     │   (Database)    │     │ (Notifications) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                    ┌───────────────────┼───────────────────┐
                                    ▼                   ▼                   ▼
                            ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
                            │  WhatsApp   │     │   Twilio    │     │    FCM      │
                            │  Business   │     │    SMS      │     │   (Push)    │
                            └─────────────┘     └─────────────┘     └─────────────┘
```

### Firestore Schema
```
institutes/{instituteId}
  - name, address, phone, createdAt, settings
  - /batches/{batchId}
      - name, subject, schedule, startTime, endTime
      - /students/{studentId}
          - name, parentPhone, studentId, isActive
  - /attendance/{attendanceId}
      - batchId, date, submittedAt, submittedBy
      - /records/{studentId}
          - status (present/absent/late), notificationStatus
  - /auditLog/{logId}
      - action, userId, timestamp, details
  - /teachers/{teacherId}
      - name, phone, role (admin/teacher)
```

### Notification Flow
1. Teacher submits attendance → Firestore write
2. Cloud Function triggered on attendance document create
3. For each absent/late student:
   - Attempt WhatsApp via Business API
   - If fails after 60s, send SMS via Twilio
4. Update notification status in attendance record
5. App polls/listens for status updates

### Cost Estimates (MVP)
- **WhatsApp Business API:** ~₹0.50-1.00 per message
- **Twilio SMS:** ~₹0.20-0.30 per SMS
- **Firebase:** Free tier sufficient for MVP (50K reads/day, 20K writes/day)
- **Estimated cost per institute:** ₹500-1500/month depending on batch sizes

## Design Considerations

### UI Principles
- **Large touch targets:** Minimum 56dp height for buttons
- **High contrast:** Dark text on light backgrounds
- **Clear status colors:** Green (present), Red (absent), Yellow (late), Gray (unmarked)
- **Minimal text:** Icons + colors for status, names prominent
- **One-hand operation:** Key actions reachable with thumb

### Key Screens
1. **Login:** Phone number → OTP → Dashboard
2. **Dashboard:** Today's summary + batch list
3. **Batch Detail:** Student list + attendance marking
4. **Attendance Screen:** Large student cards with tap-to-mark
5. **Reports:** Daily summary, absent list, student history
6. **Settings:** Institute profile, notification templates, teachers

## Success Metrics

- **Teacher adoption:** 80% of attendance marked digitally within 2 weeks of onboarding
- **Marking speed:** Average time to mark batch attendance < 60 seconds
- **Notification delivery:** 95%+ messages delivered (WhatsApp + SMS combined)
- **Parent satisfaction:** <5% complaints about missed notifications
- **Retention:** 70% of pilot institutes continue after 1-month trial
- **Reliability:** 99.5% uptime, <1% data sync failures

## Monetization (B2B)

### Pricing Model
- **Per-batch pricing:** ₹299-499/month per batch
- **Institute unlimited:** ₹1999-2999/month for unlimited batches
- **Annual discount:** 2 months free on annual plan

### Free Trial
- 14-day free trial with full features
- No credit card required
- Limited to 2 batches during trial

## Open Questions

1. **WhatsApp Business API approval:** Timeline for business verification? Backup plan if rejected?
2. **Regional language support:** Which languages after Hindi? Tamil, Telugu, Marathi?
3. **Parent app phase 2:** When to build? What features beyond history view?
4. **Bulk notification limits:** WhatsApp rate limits? Need queuing system?
5. **Data retention:** How long to keep attendance history? GDPR-like compliance needed?

## Appendix: Notification Message Templates

### Present (WhatsApp)
```
✅ [Institute Name]
[Student Name] attended [Batch Name]
📅 [Date] at [Time]

Thank you!
```

### Absent (WhatsApp)
```
❌ [Institute Name]
[Student Name] was ABSENT from [Batch Name]
📅 [Date]

Please contact the institute if this is unexpected.
```

### Late (WhatsApp)
```
⏰ [Institute Name]
[Student Name] was LATE to [Batch Name]
📅 [Date] - Arrived at [Time]
```

### SMS (Shorter)
```
[Institute]: [Student] was [PRESENT/ABSENT/LATE] for [Batch] on [Date]. -[Institute Name]
```
