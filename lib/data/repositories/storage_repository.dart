import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// StorageRepository — Firebase Storage upload / delete helpers (D-01, D-04)
// Used by chat (image attachments) and profile (avatar uploads).
// ---------------------------------------------------------------------------

class StorageRepository {
  StorageRepository({required FirebaseStorage storage})
      : _storage = storage;

  final FirebaseStorage _storage;

  // -------------------------------------------------------------------------
  // uploadImage — uploads a local file to uploads/{uid}/{ts}_{suffix}.
  // Path matches storage.rules `uploads/{uid}/{allPaths=**}` allow rule.
  // Returns the HTTPS download URL after upload completes.
  // -------------------------------------------------------------------------

  Future<String> uploadImage({
    required String uid,
    required File file,
    required String suffix,
    String contentType = 'image/jpeg',
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'uploads/$uid/${ts}_$suffix';
    final ref = _storage.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  // -------------------------------------------------------------------------
  // deleteByPath — best-effort delete; swallows not-found errors.
  // -------------------------------------------------------------------------

  Future<void> deleteByPath(String fullPath) async {
    try {
      await _storage.ref(fullPath).delete();
    } catch (_) {
      // Best-effort — not-found or permission errors are non-fatal.
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(storage: ref.read(firebaseStorageProvider));
});
