import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const _cloudName = 'dfj1kbkaa'; // from Voxa production config
  static const _uploadPreset = 'voxa_unsigned'; // unsigned preset for direct upload

  /// Upload audio file to Cloudinary, returns {url, publicId}
  static Future<Map<String, String>> uploadAudio(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload'),
    );

    request.fields['upload_preset'] = _uploadPreset;
    request.fields['resource_type'] = 'video';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'voxa_${DateTime.now().millisecondsSinceEpoch}.m4a',
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${json['error']?['message']}');
    }

    return {
      'url': json['secure_url'] as String,
      'publicId': json['public_id'] as String,
    };
  }
}
