import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadService {
  final SupabaseClient _supabase;

  UploadService(this._supabase);

  /// Pick an Excel file from the device
  Future<File?> pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Validate file size (max 10MB)
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('File size exceeds 10MB limit');
        }
        
        return file;
      }
      
      return null; // User canceled
    } catch (e) {
      throw Exception('Error picking file: $e');
    }
  }

  /// Upload file to Supabase Storage for a specific factory
  Future<String> uploadFileToFactory(String factoryDriveFolderId, File file) async {
    try {
      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalName = file.path.split('/').last;
      final fileName = '${timestamp}_$originalName';
      
      // Upload to factory's folder in storage
      final path = '$factoryDriveFolderId/$fileName';
      
      await _supabase.storage
          .from('factories')
          .upload(path, file);
      
      return fileName;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Complete upload flow: pick file and upload
  Future<String?> pickAndUploadFile(String factoryDriveFolderId) async {
    try {
      // Step 1: Pick file
      final file = await pickExcelFile();
      if (file == null) {
        return null; // User canceled
      }

      // Step 2: Upload file
      final fileName = await uploadFileToFactory(factoryDriveFolderId, file);
      
      return fileName;
    } catch (e) {
      rethrow;
    }
  }
}
