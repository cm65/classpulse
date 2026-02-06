# Ralph Execution Instructions

You are executing tasks autonomously for the TutorNotification project. Follow these instructions carefully.

## Your Role

You are an autonomous development agent working through user stories defined in `prd.json`. Your job is to:
1. Implement the next incomplete story (where `passes: false`)
2. Verify all acceptance criteria are met
3. Update `prd.json` to mark the story as complete (`passes: true`)
4. Document progress in `progress.txt`

## Files to Read

1. **prd.json** - Contains all user stories with:
   - `id` - Story identifier (e.g., "US-001")
   - `title` - Brief description
   - `description` - User story format
   - `acceptanceCriteria` - List of requirements to satisfy
   - `priority` - Lower number = higher priority
   - `passes` - `false` = incomplete, `true` = complete
   - `notes` - Implementation hints and dependencies

2. **progress.txt** - Running log of your work. Append to this file:
   - What you learned about the codebase
   - Patterns you discovered
   - Decisions you made and why
   - Any blockers or issues

## Execution Process

### Step 1: Identify Next Story
Read `prd.json` and find the story with:
- `passes: false`
- Lowest `priority` number

### Step 2: Check Dependencies
Review the story's `notes` field for dependencies (e.g., "Depends on US-001").
If dependencies are not complete (`passes: false`), work on the dependency first.

### Step 3: Implement the Story
For each acceptance criterion:
1. Understand what's required
2. Find relevant existing code
3. Implement or modify code
4. Test the implementation

### Step 4: Verify Acceptance Criteria
Every story MUST satisfy:
- All listed acceptance criteria
- `flutter analyze` passes with no errors (or `npm run typecheck` for functions)
- App builds successfully

### Step 5: Update prd.json
When the story is complete:
1. Set `passes: true` for the story
2. Add implementation notes to the `notes` field

### Step 6: Update progress.txt
Append a summary:
```
## [Story ID] - [Story Title]
Completed: [timestamp]
Implementation:
- [What you did]
- [Files changed]
- [Key decisions]
```

## Code Quality Rules

1. **Type Safety**: All Firestore data access must use explicit type casting:
   ```dart
   // Correct
   name: (data['name'] as String?) ?? '',

   // Wrong - causes type errors
   name: data['name'] ?? '',
   ```

2. **Analysis**: Run `flutter analyze` after every change. Fix all errors before continuing.

3. **Testing**: Build and test on emulator when possible:
   ```bash
   flutter build apk --debug
   ~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

## Firestore Patterns

### Model fromFirestore Pattern
```dart
factory Model.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Model(
    id: doc.id,
    stringField: (data['stringField'] as String?) ?? '',
    intField: (data['intField'] as int?) ?? 0,
    boolField: (data['boolField'] as bool?) ?? false,
    optionalField: data['optionalField'] as String?,
    timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    nestedMap: (data['nested'] as Map<String, dynamic>?) ?? {},
    list: List<String>.from((data['list'] as List<dynamic>?) ?? []),
  );
}
```

### Composite Indexes
When adding queries that combine equality + range filters, create a Firestore index:
- Go to Firebase Console > Firestore > Indexes
- Create composite index with the required fields

## Completion Signal

When ALL stories in prd.json have `passes: true`, output:
```
COMPLETE - All stories finished successfully!
```

## Error Handling

If you encounter a blocker:
1. Document it in progress.txt
2. Try an alternative approach
3. If truly blocked, leave the story with `passes: false` and add notes explaining the issue
