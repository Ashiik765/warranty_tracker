import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Notifications removed — NotificationService no longer used

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // -------------------- Controllers --------------------
  final TextEditingController productController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();

  // -------------------- State variables --------------------
  File? image;
  String? extractedText;
  String? category;
  DateTime? selectedExpiry;

  bool isScanning = false;
  bool ocrSuccess = false;
  bool noDetailsFound = false;

  final List<String> categories = [
    'Electronics',
    'Vehicle',
    'Home Appliances',
    'Others',
  ];

  // =================== SCAN IMAGE ======================
  Future<void> scanFromCamera() async {
    setState(() {
      isScanning = true;
      ocrSuccess = false;
      noDetailsFound = false;
      extractedText = null;
      productController.text = '';
      expiryController.text = '';
      selectedExpiry = null;
      category = null;
    });

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) {
        setState(() => isScanning = false);
        return;
      }

      image = File(picked.path);

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(image!);
      final recognizedText = await recognizer.processImage(inputImage);

      extractedText = recognizedText.text;
      parseTextForFields(extractedText!);

      await recognizer.close();
    } catch (e) {
      showError("OCR failed: $e");
    } finally {
      setState(() => isScanning = false);
    }
  }

  // =================== PARSE TEXT ======================
  void parseTextForFields(String text) {
    bool foundProduct = false;
    bool foundDate = false;

    final lines = text.split('\n');

    for (var line in lines) {
      final l = line.toLowerCase().trim();

      // Product detection
      if (!foundProduct && (l.contains("name") || l.contains("product"))) {
        if (line.contains(":")) {
          productController.text = line.split(":").last.trim();
        } else {
          productController.text = line.trim();
        }
        foundProduct = true;
      }

      // Expiry detection
      if (!foundDate && (l.contains("exp") || l.contains("expiry"))) {
        final match1 = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(line);
        final match2 = RegExp(r'\d{2}/\d{2}/\d{4}').firstMatch(line);

        if (match1 != null) {
          expiryController.text = match1.group(0)!;
          selectedExpiry = DateTime.parse(expiryController.text);
          foundDate = true;
        } else if (match2 != null) {
          final parts = match2.group(0)!.split('/');
          expiryController.text = "${parts[2]}-${parts[1]}-${parts[0]}";
          selectedExpiry = DateTime.parse(expiryController.text);
          foundDate = true;
        }
      }
    }

    // Fallback: pick first meaningful line for product
    if (!foundProduct) {
      for (var line in lines) {
        if (line.trim().length > 3 &&
            !RegExp(r'^[\d\W]+$').hasMatch(line.trim())) {
          productController.text = line.trim();
          foundProduct = true;
          break;
        }
      }
    }

    // Fallback for date
    if (!foundDate) {
      final match1 = RegExp(r'\b(20\d{2}-\d{2}-\d{2})\b').firstMatch(text);
      final match2 = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b').firstMatch(text);

      if (match1 != null) {
        expiryController.text = match1.group(1)!;
        selectedExpiry = DateTime.parse(expiryController.text);
        foundDate = true;
      } else if (match2 != null) {
        final parts = match2.group(1)!.split('/');
        expiryController.text = "${parts[2]}-${parts[1]}-${parts[0]}";
        selectedExpiry = DateTime.parse(expiryController.text);
        foundDate = true;
      }
    }

    setState(() {
      ocrSuccess = foundProduct && foundDate;
      noDetailsFound = !ocrSuccess;
    });
  }

  // =================== PICK EXPIRY DATE ======================
  void pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedExpiry ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      selectedExpiry = picked;
      expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  // =================== SAVE TO FIREBASE + NOTIFICATIONS ======================
  Future<void> saveToFirebase() async {
    if (productController.text.isEmpty ||
        expiryController.text.isEmpty ||
        category == null) {
      showError("Please complete all fields");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showError("User not logged in");
      return;
    }

    try {
      // ---- Save Record ----
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('receipts')
          .add({
        'productName': productController.text.trim(),
        'expiryDate': expiryController.text.trim(),
        'category': category,
        'uploadType': 'Scanned',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notifications removed — scheduling disabled

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Receipt saved successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      showError("Save failed: $e");
    }
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =================== UI ======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Receipt"),
        centerTitle: true,
        backgroundColor: const Color(0xFF395EB6),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: scanFromCamera,
        backgroundColor: const Color(0xFF395EB6),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null)
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image!, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            if (isScanning)
              Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text("Scanning receipt..."),
                ],
              ),
            const SizedBox(height: 16),
            if (extractedText != null && ocrSuccess)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Text(extractedText!, style: const TextStyle(fontSize: 13)),
              ),
            if (!ocrSuccess && noDetailsFound)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "No details detected. Fill manually.",
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: productController,
              decoration: const InputDecoration(
                labelText: "Product Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: pickExpiryDate,
              child: AbsorbPointer(
                child: TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                    labelText: "Expiry Date",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: saveToFirebase,
              icon: const Icon(Icons.save),
              label: const Text("Save Receipt"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF395EB6),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
