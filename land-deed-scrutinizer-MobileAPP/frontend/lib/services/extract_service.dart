import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ExtractService {
  static Future<Map<String, dynamic>> uploadPDF(File file) async {
    var uri = Uri.parse("http://192.168.0.105:8000/extract"); // ← Update IP if needed
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final decoded = jsonDecode(body);
      return decoded;
    } else {
      print("Error ${response.statusCode}: $body");
      throw Exception("Failed to extract deed info");
    }
  }

  // ✅ Add this method below uploadPDF
  static Map<String, dynamic> parseExtractedDetails(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (e) {
      print("JSON decode error: $e");
      return {
        "Details": {
          "Error": "Invalid response format"
        }
      };
    }
  }
}
