import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ExtractService {
  // ✅ Make the base URL configurable.
  // In a real app, you might use a package like flutter_dotenv or build flavors
  // for different environments (dev, staging, prod).
  static const String _baseUrl = "http://10.28.3.238:8000"; // <-- REMINDER: Update IP if needed for your specific network!

  static Future<Map<String, dynamic>> uploadPDF(File file) async {
    var uri = Uri.parse("$_baseUrl/extract");
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final decoded = jsonDecode(body);
      return decoded;
    } else {
      print("Error ${response.statusCode}: $body");
      throw Exception("Failed to extract deed info. Server responded with ${response.statusCode}");
    }
  }

  // This method is correctly implemented for parsing, no changes needed here.
  static Map<String, dynamic> parseExtractedDetails(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (e) {
      print("JSON decode error: $e");
      return {
        "Details": {
          "Error": "Invalid response format or empty response."
        }
      };
    }
  }
}
