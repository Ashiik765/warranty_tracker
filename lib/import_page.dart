import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart'; // <-- Make sure this exists and is properly configured

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  File? _selectedFile;
  DateTime? _selectedExpiry;
  String? _selectedCategory;
  bool _isProcessing = false;

  final TextEditingController productController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();

  final List<String> categories = [
    'Electronics',
    'Vehicle',
    'Home Appliances',
    'Others',
  ];

  // =================== PICK FILE ======================
  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _isProcessing = true;
      });
      await processFile(_selectedFile!);
    }
  }

  // =================== PROCESS FILE ======================
  Future<void> processFile(File file) async {
    setState(() {
      _isProcessing = true;
      productController.text = '';
      expiryController.text = '';
      _selectedExpiry = null;
      _selectedCategory = null;
    });

    try {
      String extractedText = '';

      if (file.path.endsWith('.pdf')) {
        extractedText = '';
      } else {
        try {
          final inputImage = InputImage.fromFile(file);
          final textRecognizer =
              TextRecognizer(script: TextRecognitionScript.latin);
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          extractedText = recognizedText.text;
          await textRecognizer.close();
        } catch (e) {
          print('Text recognition error: $e');
          extractedText = '';
        }
      }

      // Parse text for product and expiry date (same as scan_page)
      parseTextForFields(extractedText);
    } catch (e) {
      print('Error processing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e. Please fill manually.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =================== PARSE TEXT (Same as scan_page) ======================
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
          _selectedExpiry = DateTime.parse(expiryController.text);
          foundDate = true;
        } else if (match2 != null) {
          final parts = match2.group(0)!.split('/');
          expiryController.text = "${parts[2]}-${parts[1]}-${parts[0]}";
          _selectedExpiry = DateTime.parse(expiryController.text);
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
        _selectedExpiry = DateTime.parse(expiryController.text);
        foundDate = true;
      } else if (match2 != null) {
        final parts = match2.group(1)!.split('/');
        expiryController.text = "${parts[2]}-${parts[1]}-${parts[0]}";
        _selectedExpiry = DateTime.parse(expiryController.text);
        foundDate = true;
      }
    }

    setState(() {});
  }

  // =================== SAVE TO FIREBASE + NOTIFICATIONS ======================
  Future<void> saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (productController.text.isEmpty ||
        expiryController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields!')),
      );
      return;
    }

    final receiptRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('receipts')
        .doc();

    await receiptRef.set({
      'productName': productController.text.trim(),
      'expiryDate': expiryController.text.trim(),
      'category': _selectedCategory,
      'uploadType': 'Imported',
      'timestamp': Timestamp.now(),
    });

    // =================== Schedule Notifications ======================
    if (_selectedExpiry != null) {
      final reminder10 = _selectedExpiry!.subtract(const Duration(days: 10));
      final reminder1 = _selectedExpiry!.subtract(const Duration(days: 1));

      NotificationService.scheduleNotification(
        id: receiptRef.id.hashCode,
        title: "Warranty Expiring Soon",
        body: "${productController.text} warranty expires in 10 days.",
        scheduledTime: reminder10,
      );

      NotificationService.scheduleNotification(
        id: receiptRef.id.hashCode + 1,
        title: "Warranty Expiring Tomorrow",
        body: "${productController.text} warranty expires tomorrow!",
        scheduledTime: reminder1,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt saved successfully!')),
    );

    Navigator.pop(context); // Back to home
  }

  // =================== PICK EXPIRY DATE ======================
  void pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiry ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      _selectedExpiry = picked;
      expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Warranty')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: pickFile,
            child: const Text('Pick PDF or Image'),
          ),
          if (_selectedFile != null)
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _selectedFile!.path.endsWith('.pdf')
                            ? SfPdfViewer.file(_selectedFile!)
                            : Image.file(_selectedFile!),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: productController,
                                decoration: const InputDecoration(
                                    labelText: 'Product Name'),
                              ),
                              GestureDetector(
                                onTap: pickExpiryDate,
                                child: AbsorbPointer(
                                  child: TextField(
                                    controller: expiryController,
                                    decoration: const InputDecoration(
                                        labelText: 'Expiry Date'),
                                  ),
                                ),
                              ),
                              DropdownButton<String>(
                                value: _selectedCategory,
                                items: categories
                                    .map((cat) => DropdownMenuItem(
                                        value: cat, child: Text(cat)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategory = value;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: saveToFirebase,
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
