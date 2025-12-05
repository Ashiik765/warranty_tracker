import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? productName;
  String? expiryDate;
  String? category;

  DateTime? selectedExpiry;
  File? image;

  bool ocrSuccess = false;

  final List<String> categories = [
    'Electronics',
    'Vehicle',
    'Home Appliances',
    'Others',
  ];

  // =================== SCAN FROM CAMERA ======================
  Future<void> scanFromCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (picked == null) return;

    image = File(picked.path);
    ocrSuccess = false;
    productName = null;
    expiryDate = null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFile(image!);
      final textData = await recognizer.processImage(inputImage);

      for (final block in textData.blocks) {
        final text = block.text.toLowerCase();

        // --- Detect product name ---
        if ((text.contains("name") || text.contains("product")) &&
            productName == null) {
          if (block.text.contains(":")) {
            productName = block.text.split(":").last.trim();
          }
        }

        // --- Detect expiry date ---
        if ((text.contains("exp") || text.contains("expiry")) &&
            expiryDate == null) {
          final match1 = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(text);
          final match2 = RegExp(r'\d{2}/\d{2}/\d{4}').firstMatch(text);

          if (match1 != null) {
            expiryDate = match1.group(0);
          } else if (match2 != null) {
            final parts = match2.group(0)!.split("/");
            expiryDate = "${parts[2]}-${parts[1]}-${parts[0]}";
          }
        }
      }
    } catch (e) {
      print("OCR ERROR: $e");
    } finally {
      recognizer.close(); // 🔥 IMPORTANT — Prevent memory leak
    }

    if (productName != null || expiryDate != null) {
      ocrSuccess = true;
    }

    setState(() {});
  }

  // =================== PICK EXPIRY MANUALLY ======================
  void pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      selectedExpiry = picked;
      expiryDate = picked.toIso8601String().split('T').first;
      setState(() {});
    }
  }

  // =================== SAVE TO FIREBASE ======================
  Future<void> saveToFirebase() async {
    if (productName == null || expiryDate == null || category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('receipts') // Correct collection
        .add({
      'productName': productName,
      'expiryDate': expiryDate,
      'category': category,
      'uploadType': 'Scanned',
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Receipt saved successfully")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Receipt"),
        centerTitle: true,
        backgroundColor: const Color(0xFF395EB6),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF395EB6),
        onPressed: scanFromCamera,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // SHOW IMAGE
            if (image != null)
              Image.file(image!, height: 200, fit: BoxFit.cover),

            const SizedBox(height: 20),

            // =================== OCR SUCCESS ======================
            if (ocrSuccess) ...[
              if (productName != null)
                Text(
                  "Product: $productName",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              if (expiryDate != null)
                Text(
                  "Expiry: $expiryDate",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 20),
            ]

            // =================== OCR FAILED → MANUAL ======================
            else ...[
              const Text(
                "Could not read receipt. Enter details manually:",
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => productName = v,
                decoration: const InputDecoration(
                  labelText: "Product Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: pickExpiryDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    expiryDate ?? "Tap to pick expiry date",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // =================== CATEGORY DROPDOWN ======================
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: "Select Category",
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => category = v),
            ),

            const SizedBox(height: 30),

            // =================== SAVE BUTTON ======================
            ElevatedButton.icon(
              onPressed: saveToFirebase,
              icon: const Icon(Icons.save),
              label: const Text("Save Receipt"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF395EB6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
