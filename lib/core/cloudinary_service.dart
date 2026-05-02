import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const _cloudName = 'dfj1kbkaa';
const _uploadPreset = 'voxa_posts';

class CloudinaryService {
  static Future<Map<String, String>> uploadAudio(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw const CloudinaryUploadException('Recording file not found.');
    }
    if (await file.length() == 0) {
      throw const CloudinaryUploadException('Recording file is empty.');
    }

    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', filePath,
          filename: filePath.split('/').last));

    final response = await request.send().timeout(
      const Duration(seconds: 90),
      onTimeout: () =>
          throw const CloudinaryUploadException('Upload timed out.'),
    );

    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return {
        'url': json['secure_url'] as String,
        'publicId': json['public_id'] as String,
      };
    }

    final error = json['error']?['message'] as String? ?? body;
    throw CloudinaryUploadException('Upload failed: $error');
  }
}

class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}
