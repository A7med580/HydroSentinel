import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/failures.dart';

class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  /// Lists folders (factories) inside the user's folder
  /// Path: user_{email_prefix}/
  Future<List<FileObject>> listFactories(String email) async {
    try {
      final emailPrefix = email.split('@')[0];
      final userPath = 'user_$emailPrefix';
      print('DEBUG: [Root Check] Listing ALL items in bucket root...');
      try {
        final rootItems = await _client.storage.from('factories').list();
        print('DEBUG: [Root Check] Found ${rootItems.length} items at root:');
        for (var i in rootItems) {
           print('DEBUG: - ${i.name} (id: ${i.id}, metadata: ${i.metadata})');
        }
      } catch(e) {
        print('DEBUG: [Root Check] Failed: $e');
      }

      print('DEBUG: Listing factories for path: $userPath');
      final List<FileObject> objects = await _client.storage.from('factories').list(path: userPath);
      print('DEBUG: Found ${objects.length} objects in $userPath');
      for (var o in objects) {
        print('DEBUG: Object found: ${o.name}, isFolder: ${o.metadata == null}');
      }
      
      // Filter primarily for folders (factories)
      
      // Filter primarily for folders (factories)
      // Supabase storage folders might not "exist" as objects unless they contain files or are explicitly created markers.
      // But usually 'list' works if structure exists.
      return objects;
    } catch (e) {
      throw ServerFailure('Failed to list factories from storage: $e');
    }
  }

  /// Lists Excel files inside a specific factory folder
  Future<List<FileObject>> listFactoryFiles(String email, String factoryName) async {
    try {
      final emailPrefix = email.split('@')[0];
      final path = 'user_$emailPrefix/$factoryName';

      final List<FileObject> objects = await _client.storage.from('factories').list(path: path);
      
      // Filter for .xlsx files
      return objects.where((file) {
        return file.name.endsWith('.xlsx');
      }).toList();
    } catch (e) {
      throw ServerFailure('Failed to list factory files: $e');
    }
  }

  /// Downloads file bytes
  Future<List<int>> downloadFile(String email, String factoryName, String fileName) async {
    try {
      final emailPrefix = email.split('@')[0];
      final path = 'user_$emailPrefix/$factoryName/$fileName';

      final bytes = await _client.storage.from('factories').download(path);
      return bytes;
    } catch (e) {
      throw ServerFailure('Failed to download file: $e');
    }
  }

  /// Uploads a file to a factory folder
  Future<void> uploadFile(String email, String factoryName, String fileName, List<int> bytes) async {
    try {
      final emailPrefix = email.split('@')[0];
      final path = 'user_$emailPrefix/$factoryName/$fileName';

      await _client.storage.from('factories').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true),
      );
      print('DEBUG: Uploaded file to $path');
    } catch (e) {
      throw ServerFailure('Failed to upload file: $e');
    }
  }

  /// Deletes a file from a factory folder
  Future<void> deleteFile(String email, String factoryName, String fileName) async {
    try {
      final emailPrefix = email.split('@')[0];
      final path = 'user_$emailPrefix/$factoryName/$fileName';

      await _client.storage.from('factories').remove([path]);
      print('DEBUG: Deleted file at $path');
    } catch (e) {
      throw ServerFailure('Failed to delete file: $e');
    }
  }
}
