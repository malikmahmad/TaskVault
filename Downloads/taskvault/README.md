# TaskVault — Personal Task & Productivity Manager

> **Task 2 — Cross-Platform Utility Application with Encrypted Local Storage**
> Progress App Development Internship

TaskVault is an **offline-first, fully encrypted** Flutter task-manager that
runs on Android, iOS, and every other Flutter target without any backend,
cloud service, or network dependency.  Every feature works with the device's
internet connection switched off.

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Features](#2-features)
3. [Technology Stack](#3-technology-stack)
4. [Architecture](#4-architecture)
5. [CRUD Implementation](#5-crud-implementation)
6. [Local Storage & Encryption](#6-local-storage--encryption)
7. [State Management](#7-state-management)
8. [Responsive UI](#8-responsive-ui)
9. [Setup & Run](#9-setup--run)
10. [Running Tests](#10-running-tests)
11. [Project Structure](#11-project-structure)
12. [Future Improvements](#13-future-improvements)

---

## 1. Problem Statement

People need a fast, private way to manage day-to-day tasks (work, study,
personal, shopping) without handing data to a cloud service.  TaskVault solves
this with full CRUD task management backed by an **AES-256 encrypted local
database**, so data never leaves the device and is intact across app restarts.

---

## 2. Features

### Core CRUD
| Operation | Where it happens |
|-----------|-----------------|
| **Create** | Add Task screen — title, description, category, priority, due date/time |
| **Read** | Home screen — live stats dashboard + searchable, filterable, sortable list; Task Details screen for the full record |
| **Update** | Edit Task screen (pre-filled); one-tap complete/uncomplete toggle on every card and the details screen |
| **Delete** | Swipe-to-delete on the home list **or** the delete button on the details screen — both require a confirmation dialog |

### Search, Filter & Sort
- **Live search** across title, description, and category
- **Filters**: All · Pending · Completed · High Priority · by Category
- **Sort**: Newest first · Oldest first · Due date · Priority

### UX
- Dark / Light / System theme toggle (Settings → Appearance)
- Responsive stats grid — adapts column count to available width
- Polished loading, empty, and error states throughout
- All destructive actions are confirmation-gated
- Floating snack-bar feedback on every CRUD operation

---

## 3. Technology Stack

| Concern | Choice |
|---------|--------|
| Framework | Flutter / Dart ≥ 3.3 (null-safe, Material 3) |
| Local database | **Hive** (`hive` 2.2, `hive_flutter` 1.1) |
| Encryption key vault | **`flutter_secure_storage`** 9.x — Keychain (iOS) / Keystore (Android) |
| State management | **`provider`** 6.x (`ChangeNotifier`) |
| Unique IDs | `uuid` 4.x (v4 random UUIDs) |
| Date formatting | `intl` 0.19 |
| UI | Material 3 (`useMaterial3: true`) |

No Firebase · No Supabase · No REST API · No analytics SDK.

---

## 4. Architecture

```
┌─────────────────────────────────────┐
│  UI layer (screens / widgets)       │  MaterialApp, Scaffold, Consumer
├─────────────────────────────────────┤
│  TaskProvider  (ChangeNotifier)     │  CRUD, search, filter, sort,
│                                     │  loading/error state, theme mode
├─────────────────────────────────────┤
│  TaskRepository                     │  maps "task operations" onto
│                                     │  storage calls; generates UUIDs
├─────────────────────────────────────┤
│  StorageService                     │  owns Hive lifecycle: init,
│                                     │  encryption key, box CRUD
├─────────────────────────────────────┤
│  Hive  Box<Task>  (AES-256)         │  binary, encrypted on-disk store
└─────────────────────────────────────┘
```

**Design rules enforced throughout:**
- Widgets call only `TaskProvider` methods — never the repository or storage
  service directly.
- The provider's in-memory `_tasks` list is a *cache*; it is re-fetched from
  Hive after every mutation, so the in-memory state is always consistent with
  what is on disk.
- `StorageException` is the only error type that crosses layer boundaries —
  the UI never sees a raw Hive exception or stack trace.

---

## 5. CRUD Implementation

### Create
`AddTaskScreen` collects title (required, ≤ 100 chars), description (optional,
≤ 500 chars), category, priority, and an optional due date + time via native
pickers.  On submit, `TaskProvider.addTask` calls
`TaskRepository.createTask`, which stamps a UUID v4, writes the `Task` to
the encrypted Hive box, and triggers a provider rebuild.

### Read
The home screen is driven entirely by `TaskProvider.tasks` — a computed,
filtered, sorted view over the full task list.  The stats row
(`TaskStats`) shows totals derived from `TaskProvider.totalCount`,
`pendingCount`, `completedCount`, and `highPriorityCount`.
`TaskDetailsScreen` looks up a task by id from `TaskProvider.allTasks`
(unfiltered) so it stays visible even when a search is active.

### Update
`EditTaskScreen` is pre-populated with the task's current values via
`TaskForm`'s `initial*` parameters.  Submitting calls
`TaskProvider.editTask`, which delegates to `TaskRepository.updateTask`.
`updateTask` uses `Task.copyWith` to create a new immutable snapshot,
bumps `updatedAt`, and persists it via `StorageService.put` (Hive uses the
task id as the box key, so this is an upsert).  The complete/uncomplete
toggle is a separate method (`toggleCompleted`) that flips `isCompleted`
without touching other fields.

### Delete
`TaskProvider.deleteTask` calls `TaskRepository.deleteTask` →
`StorageService.delete` → `Hive.Box.delete(id)`.  The task is removed from
the in-memory cache on the same call.  A swipe-to-delete gesture on the home
list and the delete icon on the details screen both show a confirmation
`AlertDialog` before the provider method is called.

---

## 6. Local Storage & Encryption

### Hive
Data is stored in a single `Box<Task>` named `tasks_box_v1`.  Hive serialises
tasks using a **hand-written `TypeAdapter`** (`TaskAdapter`, typeId 0), which
avoids the `build_runner` code-generation step while still giving fully typed,
compact binary serialisation.  The box key for each entry is the task's UUID
string.

### AES-256 encryption
The box is opened with `HiveAesCipher`, which wraps AES-256-CBC with an
HMAC-SHA-256 MAC — every byte on disk is authenticated and encrypted.

```dart
_box = await Hive.openBox<Task>(
  _boxName,
  encryptionCipher: HiveAesCipher(key),   // key is List<int>(32)
);
```

### Key management
1. On first launch, `StorageService._getOrCreateEncryptionKey()` calls
   `Hive.generateSecureKey()` to produce 32 cryptographically random bytes.
2. The key is base64url-encoded and written to
   `flutter_secure_storage` under the key `taskvault_hive_encryption_key`.
   - **iOS**: stored in the device Keychain.
   - **Android**: stored in `EncryptedSharedPreferences`, itself backed by
     the Android Keystore.
3. On every subsequent launch the key is read back from secure storage and
   passed to `HiveAesCipher`.  The plain bytes are never written to disk,
   never logged, and never appear in source control.

If the secure storage entry is lost (e.g. device factory reset), a new key
is generated and the old encrypted box is effectively unreadable — which is
the correct security behaviour for local-only encrypted data.

---

## 7. State Management

`TaskProvider extends ChangeNotifier` is the single source of truth for:

| State | Description |
|-------|-------------|
| `status` | `ViewStatus.loading / ready / error` — drives the home screen skeleton |
| `tasks` | Computed filtered + sorted view; widgets rebuild on change |
| `allTasks` | Unfiltered; used by detail screen to survive active search |
| `totalCount` / `pendingCount` / `completedCount` / `highPriorityCount` | Derived stats |
| `searchQuery` / `filter` / `categoryFilter` / `sort` | Current UI state |
| `themeMode` | `ThemeMode.system / light / dark` — forwarded to `MaterialApp` |

All mutations go through `_runGuarded`, which catches `StorageException` into
a transient `errorMessage` (shown as a snack-bar) without crashing the UI
into the full-screen error state.

---

## 8. Responsive UI

- **`TaskStats`** uses `LayoutBuilder` to calculate the optimal column count
  (`(availableWidth / 90).clamp(2, 4)`) so the stat grid looks correct on
  watches, phones, and tablets without hardcoding breakpoints.
- **`TaskForm`** uses a `ListView` so all fields are reachable when the soft
  keyboard is open on small screens.
- **`HomeScreen`** uses a `CustomScrollView` with `SliverList` so the stats,
  search bar, filter chips, and task list all scroll together naturally.
- The app ships a Material 3 `darkTheme` alongside the light theme; the active
  one is picked by `ThemeMode` (user-selectable in Settings → Appearance).

---

## 9. Setup & Run

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) — **stable**
  channel, Dart ≥ 3.3
- A connected device or running emulator (Android / iOS / desktop)

### Steps

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on your connected device / emulator
flutter run

# 3. (Optional) Build a release APK
flutter build apk --release
```

No API keys, environment variables, or network access are required.

---

## 10. Running Tests

```bash
flutter test
```

| Test file | What it covers |
|-----------|---------------|
| `test/models/task_test.dart` | Default values, `copyWith`, `toMap`/`fromMap` round-trip, null due-date |
| `test/repositories/task_repository_test.dart` | Create / read / update / delete / clearAll; persistence across box close + re-open with the same encrypted key |
| `test/providers/task_provider_test.dart` | All CRUD methods, search, filters (pending / completed / high-priority / category), sort (priority, due date) |
| `test/utils/validators_test.dart` | Title required / length limits, description limits, due-date sanity |

Tests run in a temp directory with a fixed 32-byte test key — no real
platform channels (Keychain / Keystore) are exercised, so they work on any
CI machine without a device attached.

---

## 11. Project Structure

```
taskvault/
├── lib/
│   ├── main.dart                         # App entry point (async init)
│   ├── models/
│   │   └── task.dart                     # Task entity + Hive TypeAdapter
│   ├── providers/
│   │   └── task_provider.dart            # ChangeNotifier: CRUD, filters, theme
│   ├── repositories/
│   │   └── task_repository.dart          # Business logic, UUID generation
│   ├── services/
│   │   └── storage_service.dart          # Hive init, AES key, box operations
│   ├── screens/
│   │   ├── home_screen.dart              # Dashboard, list, swipe-to-delete
│   │   ├── add_task_screen.dart          # Create form
│   │   ├── edit_task_screen.dart         # Update form
│   │   ├── task_details_screen.dart      # Full task view + delete
│   │   └── settings_screen.dart         # Theme toggle, storage info, clear all
│   ├── widgets/
│   │   ├── task_card.dart               # List item with priority/category pills
│   │   ├── task_form.dart               # Shared create/edit form
│   │   ├── task_stats.dart              # Responsive stats grid
│   │   ├── task_search_bar.dart         # Search field with clear button
│   │   └── empty_state.dart             # Empty / error placeholder
│   ├── theme/
│   │   └── app_theme.dart               # Material 3 light + dark themes
│   └── utils/
│       ├── constants.dart               # App-wide string constants + enums
│       └── validators.dart              # Pure input validation functions
└── test/
    ├── models/task_test.dart
    ├── repositories/task_repository_test.dart
    ├── providers/task_provider_test.dart
    └── utils/validators_test.dart
```

---

## 12. Future Improvements

- Biometric lock before opening the app (on top of at-rest encryption).
- Recurring tasks and local push-notification reminders.
- Drag-to-reorder within a category.
- Export / import tasks to an encrypted local backup file.
- Tablet-optimised two-pane (master–detail) layout.
- Persist the selected theme mode across app restarts (using a plain Hive box
  or `SharedPreferences`).

---

> **TaskVault is 100 % offline-first — no cloud services, no backend, no
> analytics, no network calls of any kind.**
