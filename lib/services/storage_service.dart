import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../utils/constants.dart';

/// Thrown when the local store fails to initialise or perform an operation.
/// UI code catches this and shows a friendly message instead of a raw
/// exception / stack trace.
class StorageException implements Exception {
  StorageException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'StorageException: $message';
}

/// Owns all direct interaction with Hive and the encryption key.
///
/// Nothing outside this file (and the repository that wraps it) should ever
/// touch a [Box] directly — that keeps storage internals out of the UI and
/// makes it possible to swap the storage engine later without touching
/// screens or providers.
class StorageService {
  StorageService({
    FlutterSecureStorage? secureStorage,
    String boxName = AppConstants.taskBoxName,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _boxName = boxName;

  final FlutterSecureStorage _secureStorage;
  final String _boxName;
  Box<Task>? _box;

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Initialises Hive, retrieves (or generates) the AES encryption key from
  /// secure platform storage, and opens the encrypted task box.
  ///
  /// The key itself is never hardcoded and never stored inside the Hive box
  /// or anywhere in source control — it lives only in the OS-level secure
  /// storage (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on
  /// Android).
  ///
  /// [testDirectoryPath] and [testEncryptionKey] exist only so unit/widget
  /// tests can run Hive against a plain temp directory with a fixed key,
  /// without touching real platform channels (path_provider / secure
  /// storage). Production code never passes them.
  Future<void> init({
    String? testDirectoryPath,
    List<int>? testEncryptionKey,
  }) async {
    if (isInitialized) return;
    try {
      if (testDirectoryPath != null) {
        Hive.init(testDirectoryPath);
      } else {
        await Hive.initFlutter();
      }
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TaskAdapter());
      }

      final key = testEncryptionKey ?? await _getOrCreateEncryptionKey();
      _box = await Hive.openBox<Task>(
        _boxName,
        encryptionCipher: HiveAesCipher(key),
      );
    } catch (e) {
      throw StorageException(
        'Could not initialize local storage. Please restart the app.',
        e,
      );
    }
  }

  Future<List<int>> _getOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(
      key: AppConstants.secureKeyStorageKey,
    );
    if (existing != null) {
      return base64Url.decode(existing);
    }

    final newKey = Hive.generateSecureKey();
    await _secureStorage.write(
      key: AppConstants.secureKeyStorageKey,
      value: base64UrlEncode(newKey),
    );
    return newKey;
  }

  Box<Task> get _requireBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StorageException('Storage is not initialized.');
    }
    return box;
  }

  List<Task> getAll() {
    try {
      return _requireBox.values.toList(growable: false);
    } catch (e) {
      throw StorageException('Could not read tasks from local storage.', e);
    }
  }

  Future<void> put(Task task) async {
    try {
      await _requireBox.put(task.id, task);
    } catch (e) {
      throw StorageException('Could not save the task.', e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _requireBox.delete(id);
    } catch (e) {
      throw StorageException('Could not delete the task.', e);
    }
  }

  Future<void> clearAll() async {
    try {
      await _requireBox.clear();
    } catch (e) {
      throw StorageException('Could not clear local storage.', e);
    }
  }

  int get storedTaskCount => isInitialized ? _requireBox.length : 0;

  /// Closes the box. Exposed mainly for test teardown; production code
  /// keeps the box open for the app's lifetime.
  Future<void> close() async {
    if (isInitialized) {
      await _box!.close();
    }
    _box = null;
  }
}

/// Small helper exposed only for tests that want a random id without
/// pulling the uuid package into non-UI code paths.
String generateFallbackId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
