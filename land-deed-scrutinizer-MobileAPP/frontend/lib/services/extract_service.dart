import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;


class ExtractService {
  static Future<Map<String, dynamic>> uploadPDF(File file) async {
    var uri = Uri.parse("http://192.168.0.104:8000/extract"); // ← For Android emulator
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final decoded = jsonDecode(body);
      return decoded; // ✅ returning a Map
    } else {
      print("Error ${response.statusCode}: $body");
      throw Exception("Failed to extract deed info");
    }
  }
}
