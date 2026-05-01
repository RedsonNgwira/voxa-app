import 'dart:convert';
import 'dart:io';
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
  ///
  /// IMPORTANT: Only `public_id` and `timestamp` are included in the signature.
  /// Do NOT send any extra form fields (like `resource_type`) — Cloudinary will
  /// reject the request if unsigned parameters are present.
  static Future<Map<String, String>> uploadAudio(
    String filePath,
    GraphQLClient client, {
    int maxRetries = 2,
  }) async {
    final publicId = 'voxa/posts/${DateTime.now().millisecondsSinceEpoch}';

    // Step 1: Get signed params from backend
    final sigResult = await client.query(QueryOptions(
      document: gql(kCloudinarySignature),
      variables: {'publicId': publicId},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (sigResult.hasException) {
      final gqlErrors = sigResult.exception?.graphqlErrors
          .map((e) => e.message)
          .join(', ');
      final linkError = sigResult.exception?.linkException?.toString();
      throw CloudinaryUploadException(
        'Failed to get upload signature: ${gqlErrors ?? linkError ?? "Unknown error"}',
      );
    }

    if (sigResult.data == null || sigResult.data!['cloudinarySignature'] == null) {
      throw const CloudinaryUploadException(
        'Server returned empty signature. Check Cloudinary configuration.',
      );
    }

    final sig = sigResult.data!['cloudinarySignature'] as Map<String, dynamic>;
    final cloudName = sig['cloudName'] as String;
    final apiKey = sig['apiKey'] as String;
    final signature = sig['signature'] as String;
    final timestamp = sig['timestamp'] as int;

    if (cloudName.isEmpty || apiKey.isEmpty || signature.isEmpty) {
      throw const CloudinaryUploadException(
        'Invalid Cloudinary credentials. Contact support.',
      );
    }

    // Verify the file exists and is readable
    final file = File(filePath);
    if (!await file.exists()) {
      throw const CloudinaryUploadException('Recording file not found.');
    }
    final fileSize = await file.length();
    if (fileSize == 0) {
      throw const CloudinaryUploadException('Recording file is empty.');
    }

    // Step 2: Upload directly to Cloudinary with signature
    // resource_type is in the URL path (/video/upload), NOT as a form field.
    // Only signed params (public_id, timestamp) go as form fields.
    Exception? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload'),
        );

        // Only include parameters that are part of the signature
        request.fields['public_id'] = publicId;
        request.fields['api_key'] = apiKey;
        request.fields['timestamp'] = timestamp.toString();
        request.fields['signature'] = signature;
        // DO NOT add resource_type as a form field — it's unsigned and causes rejection

        request.files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: filePath.split('/').last,
        ));

        final response = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw const CloudinaryUploadException('Upload timed out. Check your connection.');
          },
        );

        final body = await response.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        if (response.statusCode == 200) {
          return {
            'url': json['secure_url'] as String,
            'publicId': json['public_id'] as String,
          };
        }

        final errorMsg = json['error']?['message'] as String? ?? 'Unknown error';
        lastError = CloudinaryUploadException('Upload failed: $errorMsg');

        // Don't retry on auth errors
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw lastError;
        }
      } catch (e) {
        if (e is CloudinaryUploadException) {
          lastError = e;
          if (attempt == maxRetries) rethrow;
        } else {
          lastError = CloudinaryUploadException('Upload error: $e');
          if (attempt == maxRetries) throw lastError;
        }
      }

      // Wait before retry with exponential backoff
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }

    throw lastError ?? const CloudinaryUploadException('Upload failed after retries.');
  }
}

class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}
