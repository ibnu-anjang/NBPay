import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'cloudinary_picker_stub.dart'
    if (dart.library.html) 'cloudinary_picker_web.dart';

class CloudinaryService {
  static const String cloudName = 'lhtje87m';
  static const String uploadPreset = 'NBPayOFC';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  static final _picker = ImagePicker();

  /// Opens gallery/file selector and uploads chosen image to Cloudinary.
  /// Returns the secure HTTPS URL, or null if cancelled by user.
  static Future<String?> pickAndUploadImage({
    String folder = 'nbpay',
    int maxWidth = 1200,
    int maxHeight = 1200,
    int imageQuality = 85,
  }) async {
    if (kIsWeb) {
      final bytes = await pickImageBytesPlatform();
      if (bytes == null || bytes.isEmpty) return null;
      return await uploadImageBytes(
        bytes,
        fileName: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        folder: folder,
      );
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (file == null) return null;

      final bytes = await file.readAsBytes();
      return await uploadImageBytes(bytes, fileName: file.name, folder: folder);
    } catch (_) {
      final bytes = await pickImageBytesPlatform();
      if (bytes == null || bytes.isEmpty) return null;
      return await uploadImageBytes(
        bytes,
        fileName: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        folder: folder,
      );
    }
  }

  /// Uploads raw image bytes to Cloudinary with unsigned preset.
  static Future<String> uploadImageBytes(
    Uint8List bytes, {
    String fileName = 'image.jpg',
    String folder = 'nbpay',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = folder;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = json.decode(response.body);
      final String? secureUrl = data['secure_url'];
      if (secureUrl != null && secureUrl.isNotEmpty) {
        return secureUrl;
      }
      throw Exception('Cloudinary response missing secure_url');
    } else {
      String errMsg = 'Gagal upload gambar (${response.statusCode})';
      try {
        final errData = json.decode(response.body);
        if (errData['error']?['message'] != null) {
          errMsg = errData['error']['message'];
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }
}
