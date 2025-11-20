import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'service_api.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? filePath;
  String? predictedDisease;
  double? confidence;
  Map<String, dynamic>? diseaseData;

  // Pilih dari galeri
  pickImageGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;
    setState(() {
      filePath = File(image.path);
      predictedDisease = null;
      confidence = null;
      diseaseData = null;
    });
  }

  // Ambil foto
  takePhoto() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      // Minta izin jika belum diberikan
      status = await Permission.camera.request();

      if (!status.isGranted) {
        // Jika tetap ditolak, beri pesan error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Izin kamera ditolak! Berikan izin pada pengaturan."),
          ),
        );
        return;
      }
    }
    
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo == null) return;
    setState(() {
      filePath = File(photo.path);
      predictedDisease = null;
      confidence = null;
      diseaseData = null;
    });
  }

  // Menghapus gambar
  void deleteImage() {
    setState(() {
      filePath = null;
      predictedDisease = null;
      confidence = null;
      diseaseData = null;
    });
  }

  // Klasifikasi ke API Flask
  Future<void> classifyLeaf() async {
    if (filePath == null) return;

    // show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      ),
    );

    try {
      final result = await ApiService.predict(filePath!);

      Navigator.pop(context);

      double conf = 0.0;
      if (result["confidence"] != null) {
        conf = result["confidence"].toDouble();
      }

      if (conf < 0.50) {
        setState(() {
          predictedDisease = "⚠️ Gambar Tidak Dikenali";
          confidence = conf;
          diseaseData = {
            "description": "Pastikan gambar adalah daun padi yang jelas.",
            "prevention": "-",
            "treatment": "-"
          };
        });
        return;
      }

      final label = result["label"]?.toString().toLowerCase() ?? "";
      if (label.contains("tidak") || label.contains("unknown")) {
        setState(() {
          predictedDisease = "⚠️ Gambar Tidak Dikenali";
          confidence = conf;
          diseaseData = {
            "description": "Gambar tidak sesuai dataset daun padi.",
            "prevention": "-",
            "treatment": "-"
          };
        });
        return;
      }

      setState(() {
        predictedDisease = result["label"];
        confidence = conf;
        diseaseData = {
          "description": result["description"],
          "prevention": result["prevention"],
          "treatment": result["treatment"]
        };
      });
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal menghubungi server: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Rice Leaf Disease Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // CARD GAMBAR
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 350,
                          width: 350,
                          color: Colors.grey[100],
                          child: filePath == null
                              ? const Image(
                                  image: AssetImage('assets/add-image.png'),
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  filePath!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      if (filePath != null)
                        IconButton(
                          onPressed: deleteImage,
                          icon: const Icon(Icons.delete_forever),
                          color: Colors.red,
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // Tombol ambil gambar
                Wrap(
                  spacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Ambil Foto"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: pickImageGallery,
                      icon: const Icon(Icons.photo),
                      label: const Text("Pilih dari Galeri"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Tombol klasifikasi
                if (filePath != null)
                  ElevatedButton(
                    onPressed: classifyLeaf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 10,
                    ),
                    child: const Text(
                      'Deteksi Penyakit',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),

                const SizedBox(height: 25),

                // HASIL PREDIKSI
                if (predictedDisease != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4AF37)),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Hasil Deteksi",
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          predictedDisease!,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Confidence: ${confidence?.toStringAsFixed(3) ?? 'N/A'}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        if (diseaseData != null) ...[
                          const Text(
                            "Deskripsi:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            diseaseData!["description"] ?? "-",
                            textAlign: TextAlign.justify,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Pencegahan:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            diseaseData!["prevention"] ?? "-",
                            textAlign: TextAlign.justify,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Pengobatan:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            diseaseData!["treatment"] ?? "-",
                            textAlign: TextAlign.justify,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ]
                      ],
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
