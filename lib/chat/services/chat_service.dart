import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/chat_message.dart';

class ChatService {
  static const _baseUrl = 'http://shopapi.vaxilifecorp.com';

  static Future<List<ChatMessage>> fetchMessages(String clinicUsername) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/chat/messages/${Uri.encodeComponent(clinicUsername)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> sendMessage(
    String clinicUsername,
    String message, {
    String? attachmentUrl,
    String? attachmentFileName,
    String? attachmentContentType,
    int? attachmentSize,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/chat/send');
      final body = <String, dynamic>{
        'clinicusername': clinicUsername,
        'message': message,
      };
      if (attachmentUrl != null) {
        body['attachmenturl'] = attachmentUrl;
        body['attachmentfilename'] = attachmentFileName;
        body['attachmentcontenttype'] = attachmentContentType;
        body['attachmentsize'] = attachmentSize;
      }
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Soft delete only — the server keeps the row (and file) and only ever
  // deletes a message that belongs to this clinicUsername and was sent by
  // 'clinic' (never a staff reply), matching what the delete icon is shown
  // on in the UI.
  static Future<bool> deleteMessage(String clinicUsername, int messageId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/chat/delete');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'clinicusername': clinicUsername, 'messageid': messageId}),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Uploads a picked photo/document to vaximobileapi's chat upload folder and
  // returns the metadata needed to attach it to a message (url + filename +
  // contentType + size), or null if the upload failed.
  static Future<ChatAttachmentUpload?> uploadAttachment(File file) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/chat/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType.parse(_guessContentType(file.path)),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      return ChatAttachmentUpload(
        url: data['url']?.toString() ?? '',
        fileName: data['fileName']?.toString() ?? file.path.split('/').last,
        contentType: data['contentType']?.toString() ?? 'application/octet-stream',
        size: int.tryParse(data['size']?.toString() ?? '') ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static String _guessContentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}

class ChatAttachmentUpload {
  const ChatAttachmentUpload({
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.size,
  });

  final String url;
  final String fileName;
  final String contentType;
  final int size;

  bool get isImage => contentType.startsWith('image/');
}
