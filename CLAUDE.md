# CLAUDE.md - TutorNotification Project Guide

## Project Overview

TutorNotification (Missed Class Notifier) is a Flutter mobile app for coaching centres to mark student attendance and notify parents via WhatsApp/SMS.

## Tech Stack

- **Frontend:** Flutter 3.x (Dart)
- **Backend:** Firebase (Firestore, Cloud Functions, Auth)
- **Notifications:** WhatsApp Business API + Twilio SMS (planned)
- **State Management:** Riverpod

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models (Batch, Student, Attendance, etc.)
├── services/              # Firestore service, notification service
├── providers/             # Riverpod providers
└── screens/               # UI screens (Home, Batches, Attendance, Reports, Settings)

functions/                 # Firebase Cloud Functions (Node.js)
tasks/                     # PRD and planning documents
scripts/ralph/             # Ralph automation scripts
```

## Common Commands

```bash
# Run the app
flutter run

# Build APK
flutter build apk --debug

# Run analysis
flutter analyze

# Run tests
flutter test

# Deploy Cloud Functions
cd functions && npm run deploy

# Install to emulator
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Firebase Configuration

- **Project:** tutornotification
- **Test Phone:** +91 9999999999 (OTP: 123456)
- **Firestore Indexes:** See Firebase Console for composite indexes

## Development Workflow - PRD First, Then Code

**IMPORTANT**: Before starting any significant feature work, ALWAYS create a PRD and ralph stories first. This ensures:
- Clear requirements before coding
- Trackable progress through stories
- Consistent acceptance criteria
- Autonomous execution capability

### Step 1: Create PRD with /prd Skill

Use the `/prd` skill to create a detailed Product Requirements Document:

```bash
/prd Add parent notification preferences feature
```

This creates `tasks/prd-[feature].md` with:
- Introduction and goals
- User stories with acceptance criteria
- Functional requirements
- Technical considerations
- Success metrics

### Step 2: Convert to Ralph Stories

After PRD approval, create `scripts/ralph/prd.json` with this structure:

```json
{
  "project": "ProjectName",
  "branchName": "ralph/feature-name",
  "description": "Feature description",
  "executionConfig": {
    "batchingEnabled": true,
    "batchingStrategy": "context-aware"
  },
  "storyBatches": [
    {
      "batchId": "B1-setup",
      "name": "Batch Name",
      "stories": ["US-001", "US-002"],
      "description": "Batch description"
    }
  ],
  "userStories": [
    {
      "id": "US-001",
      "title": "Story Title",
      "description": "As a [user], I want [feature] so that [benefit].",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "flutter analyze passes with no errors"
      ],
      "priority": 1,
      "passes": false,
      "notes": "Implementation hints, dependencies"
    }
  ]
}
```

### Step 3: Execute with Ralph

Run the ralph automation script:

```bash
cd scripts/ralph
./ralph-claude.sh [max_iterations]
```

Ralph will:
1. Read `prd.json` to find next incomplete story (`passes: false`)
2. Execute the story following `prompt.md` instructions
3. Mark story complete (`passes: true`) when all criteria met
4. Continue until all stories complete or max iterations reached

### Ralph Files Structure

```
scripts/ralph/
├── ralph-claude.sh    # Main execution script
├── prompt.md          # Instructions for Claude during execution
├── prd.json           # Current project stories
├── progress.txt       # Running log of completed work
├── logs/              # Execution transcripts
└── archive/           # Previous completed runs
```

### Quick Reference

| Task | Command/Action |
|------|----------------|
| Create new PRD | `/prd [feature description]` |
| Convert PRD to stories | Manually create `prd.json` or use `/ralph` |
| Run autonomous execution | `./scripts/ralph/ralph-claude.sh 10` |
| Check progress | Read `scripts/ralph/progress.txt` |
| View logs | Check `scripts/ralph/logs/` |

### Story Acceptance Criteria Rules

Every story MUST include:
- Specific, testable requirements
- `flutter analyze passes with no errors` (for Dart code)
- `npm run typecheck passes` (for Cloud Functions)
- Build succeeds without errors

### When to Use This Workflow

✅ **Use PRD + Ralph for:**
- New features with multiple components
- Bug fix batches (like testing fixes)
- Refactoring efforts
- Any work spanning multiple files

❌ **Skip for:**
- Single-line fixes
- Quick typo corrections
- Exploratory research

## Testing Guidelines

### Manual Testing on Emulator
1. Start Android emulator
2. Build and install: `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`
3. Use test phone number for login
4. Test each feature systematically

### Key Test Flows
1. **Authentication:** Phone OTP login with test number
2. **Batch Management:** Create, edit, delete batches
3. **Student Management:** Add, edit, remove students, CSV import
4. **Attendance:** Mark individual/bulk, submit, edit within window
5. **Reports:** Daily summary, absent list, student history
6. **Notifications:** Verify Cloud Function triggers (check Firebase logs)

## Known Issues / TODOs

- [ ] WhatsApp Business API integration pending (using test stubs)
- [ ] iOS build not configured yet
- [ ] Multi-language support not implemented

## Firestore Indexes Required

The following composite indexes are needed:

| Collection | Fields | Scope | Status |
|------------|--------|-------|--------|
| batches | isActive (Asc), name (Asc) | Collection | Enabled |
| students | isActive (Asc), name (Asc) | Collection | Enabled |
| students | batchId (Asc), name (Asc) | Collection | Enabled |
| teacherInvitations | isAccepted (Asc), phone (Asc), invitedAt (Desc) | Collection | Enabled |
| attendance | batchId (Asc), date (Asc) | Collection | Enabled |

## Code Style

- Use Riverpod for state management
- Follow Flutter/Dart style guidelines
- Run `flutter analyze` before committing
- All acceptance criteria must include `flutter analyze passes` or `npm run typecheck passes`
