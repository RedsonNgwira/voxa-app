import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:graphql_flutter/graphql_flutter.dart';

const String kCloudinarySignature = r'''
query CloudinarySignature($publicId: String!) {
  cloudinarySignature(publicId: $publicId) {
    signature timestamp apiKey cloudName publicId
  }
}
''';

class CloudinaryService {
  /// Upload audio file to Cloudinary using a signed URL from the backend.
  /// Returns {url, publicId}
  static Future<Map<String, String>> uploadAudio(
    String filePath,
    GraphQLClient client,
  ) async {
    final publicId = 'voxa/posts/${DateTime.now().millisecondsSinceEpoch}';

    // Get signed params from backend
    final sigResult = await client.query(QueryOptions(
      document: gql(kCloudinarySignature),
      variables: {'publicId': publicId},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (sigResult.hasException) throw Exception('Failed to get upload signature');

    final sig = sigResult.data!['cloudinarySignature'] as Map<String, dynamic>;
    final cloudName = sig['cloudName'] as String;
    final apiKey = sig['apiKey'] as String;
    final signature = sig['signature'] as String;
    final timestamp = sig['timestamp'] as int;

    // Upload directly to Cloudinary with signature
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload'),
    );

    request.fields['public_id'] = publicId;
    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp.toString();
    request.fields['signature'] = signature;
    request.fields['resource_type'] = 'video';

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

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
