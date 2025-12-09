import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:intl/intl.dart';
// Notifications removed — NotificationService is not used

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
        extractedText = ''; // PDF OCR can be added here if needed
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

      // Parse text for product and expiry date
      parseTextForFields(extractedText);
    } catch (e) {
      print('Error processing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e. Please fill manually.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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

    // Fallback for product
    if (!foundProduct) {
      for (var line in lines) {
        if (line.trim().length > 3 &&
            !RegExp(r'^[\d\W]+$').hasMatch(line.trim())) {
          productController.text = line.trim();
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
      } else if (match2 != null) {
        final parts = match2.group(1)!.split('/');
        expiryController.text = "${parts[2]}-${parts[1]}-${parts[0]}";
        _selectedExpiry = DateTime.parse(expiryController.text);
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

    // Notifications removed — scheduling disabled

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt saved successfully!')),
    );

    Navigator.pop(context);
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.electrical_services;
      case 'vehicle':
        return Icons.directions_car;
      case 'home appliances':
        return Icons.kitchen;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 700; // adjust breakpoint as needed

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Import Warranty'),
        backgroundColor: const Color(0xFF1D4AB4),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isWideScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =================== Left: File Preview ======================
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: pickFile,
                              child: Container(
                                height: 250,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: const Color(0xFF1D4AB4), width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _selectedFile != null
                                    ? (_selectedFile!.path.endsWith('.pdf')
                                        ? SfPdfViewer.file(_selectedFile!)
                                        : ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.file(
                                              _selectedFile!,
                                              fit: BoxFit.cover,
                                            ),
                                          ))
                                    : Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.upload_file,
                                                color: Color(0xFF1D4AB4),
                                                size: 36),
                                            SizedBox(width: 12),
                                            Text(
                                              "Tap to select Image or PDF",
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // =================== Right: Form Fields ======================
                      Expanded(
                        flex: 1,
                        child: _buildFormContainer(),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      GestureDetector(
                        onTap: pickFile,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: const Color(0xFF1D4AB4), width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _selectedFile != null
                              ? (_selectedFile!.path.endsWith('.pdf')
                                  ? SfPdfViewer.file(_selectedFile!)
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _selectedFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    ))
                              : Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.upload_file,
                                          color: Color(0xFF1D4AB4), size: 36),
                                      SizedBox(width: 12),
                                      Text(
                                        "Tap to select Image or PDF",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFormContainer(),
                    ],
                  ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Warranty Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4AB4),
            ),
          ),
          const SizedBox(height: 16),

          // Product Name
          TextField(
            controller: productController,
            decoration: InputDecoration(
              labelText: 'Product Name',
              prefixIcon:
                  const Icon(Icons.shopping_bag, color: Color(0xFF1D4AB4)),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Expiry Date
          GestureDetector(
            onTap: pickExpiryDate,
            child: AbsorbPointer(
              child: TextField(
                controller: expiryController,
                decoration: InputDecoration(
                  labelText: 'Expiry Date',
                  prefixIcon: const Icon(Icons.calendar_today,
                      color: Color(0xFF1D4AB4)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Category Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('Select Category'),
              items: categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(_getCategoryIcon(cat),
                                color: const Color(0xFF1D4AB4), size: 20),
                            const SizedBox(width: 8),
                            Text(cat),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          ElevatedButton.icon(
            onPressed: saveToFirebase,
            icon: const Icon(Icons.save, size: 20),
            label: const Text('Save Warranty'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4AB4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
