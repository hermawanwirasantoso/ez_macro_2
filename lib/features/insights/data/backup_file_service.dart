import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saves backup text to a file the user chooses and reads one back.
///
/// Kept behind an interface so widget tests can stand in for the platform
/// file dialogs.
abstract class BackupFileService {
  const BackupFileService();

  /// Asks where to save [contents] as [fileName]. Returns false when the user
  /// cancels the dialog.
  Future<bool> saveText({
    required String fileName,
    required String contents,
    required String mimeType,
  });

  /// Lets the user choose a file and returns its text, or null when they
  /// cancel.
  Future<String?> pickText();
}

/// Uses the system save and open dialogs (the Storage Access Framework on
/// Android, so no storage permission is needed).
class PlatformBackupFileService extends BackupFileService {
  const PlatformBackupFileService();

  @override
  Future<bool> saveText({
    required String fileName,
    required String contents,
    required String mimeType,
  }) async {
    final int dot = fileName.lastIndexOf('.');
    final Uri? saved = await FilePicker.saveFile(
      dialogTitle: 'Save backup',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(contents)),
      mimeType: mimeType,
      type: dot == -1 ? FileType.any : FileType.custom,
      allowedExtensions: dot == -1 ? null : <String>[fileName.substring(dot + 1)],
    );
    return saved != null;
  }

  @override
  Future<String?> pickText() async {
    // Any file type: Android file providers often report .json files as
    // application/octet-stream, which a json-only filter would hide. The
    // contents are validated after reading.
    final PlatformFile? file = await FilePicker.pickFile(dialogTitle: 'Choose a backup file');
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }
}
