import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // static const String baseUrl = "http://10.0.2.2:5000";
  static const String baseUrl = "http://10.131.23.63:5000";
  // static const String baseUrl = "http://192.168.56.2:5000";

  static Future<Map<String, dynamic>> predict(File image) async {
    var uri = Uri.parse("$baseUrl/predict");

    var request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception("Gagal menghubungi API: ${response.statusCode}");
    }
  }
}
