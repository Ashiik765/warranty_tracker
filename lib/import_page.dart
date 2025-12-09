import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:intl/intl.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  // Selected file object (image or PDF)
  File? _selectedFile;

  // Parsed expiry date (if found)
  DateTime? _selectedExpiry;

  // Selected category from dropdown
  String? _selectedCategory;

  // UI state: whether OCR/processing is happening
  bool _isProcessing = false;

  // Controllers for text fields
  final TextEditingController productController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();

  // Categories for dropdown
  final List<String> categories = [
    'Electronics',
    'Vehicle',
    'Home Appliances',
    'Others',
  ];

  // Error message shown inside form if OCR fails or PDF (no OCR)
  String? _errorText;

  // =================== PICK FILE ======================
  Future<void> pickFile() async {
    // Open file picker allowing images and pdf
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    // If user picked a file and path is available
    if (result != null && result.files.single.path != null) {
      // Reset UI and set selected file
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _isProcessing = true;
        _errorText = null;
        productController.text = '';
        expiryController.text = '';
        _selectedExpiry = null;
        _selectedCategory = null;
      });

      // Process file (OCR for images, no OCR for PDFs)
      await processFile(_selectedFile!);
    }
  }

  // =================== PROCESS FILE ======================
  // For images: run ML Kit OCR
  // For PDFs: no OCR (we display a message asking user to fill)
  Future<void> processFile(File file) async {
    try {
      String extractedText = '';

      // If the file is a PDF, we won't attempt OCR in this "simple" implementation.
      if (file.path.toLowerCase().endsWith('.pdf')) {
        // Show message inside form telling user OCR not supported for PDFs here
        setState(() {
          _errorText =
              'PDF detected — OCR for PDFs is not supported in this mode. Please fill fields manually or use an image.';
        });

        // ensure controllers cleared (user will type)
        productController.clear();
        expiryController.clear();
      } else {
        // It's an image — attempt OCR using ML Kit
        try {
          // Create InputImage from file for ML Kit
          final inputImage = InputImage.fromFile(file);

          // Initialize a latin script text recognizer
          final textRecognizer =
              TextRecognizer(script: TextRecognitionScript.latin);

          // Process the image and get recognized text
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);

          // Extracted raw text
          extractedText = recognizedText.text;

          // Close the recognizer to release resources
          await textRecognizer.close();

          // If OCR result is empty, show error message inside form
          if (extractedText.trim().isEmpty) {
            setState(() {
              _errorText =
                  'No readable text found in image. Please type details manually.';
            });
          } else {
            // Clear previous error if any
            setState(() {
              _errorText = null;
            });

            // Parse text and fill fields
            parseTextForFields(extractedText);
          }
        } catch (e) {
          // OCR crashed or failed — show friendly message and allow manual input
          print('Image OCR error: $e');
          setState(() {
            _errorText =
                'Failed to extract text from image. Please type details manually.';
          });
        }
      }
    } catch (e) {
      // Unexpected error — show message
      print('Processing error: $e');
      setState(() {
        _errorText = 'Error processing file. Please fill manually.';
      });
    } finally {
      // Stop processing indicator
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // =================== PARSE TEXT ======================
  // Very similar parsing logic as you had; tries to find product name and expiry
  void parseTextForFields(String text) {
    bool foundProduct = false;
    bool foundDate = false;

    final lines = text.split('\n');

    for (var line in lines) {
      final l = line.toLowerCase().trim();

      // Product detection — looks for keywords "name" or "product"
      if (!foundProduct && (l.contains("name") || l.contains("product"))) {
        if (line.contains(":")) {
          productController.text = line.split(":").last.trim();
        } else {
          productController.text = line.trim();
        }
        foundProduct = true;
      }

      // Expiry detection — looks for common date formats near keywords
      if (!foundDate && (l.contains("exp") || l.contains("expiry"))) {
        final match1 = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(line);
        final match2 = RegExp(r'\d{2}/\d{2}/\d{4}').firstMatch(line);

        if (match1 != null) {
          expiryController.text = match1.group(0)!;
          _selectedExpiry = DateTime.tryParse(expiryController.text);
          foundDate = true;
        } else if (match2 != null) {
          final parts = match2.group(0)!.split('/');
          expiryController.text = "${parts[2]}-${parts[1]}-${parts[0]}";
          _selectedExpiry = DateTime.tryParse(expiryController.text);
          foundDate = true;
        }
      }
    }

    // Fallback for product: pick first meaningful line
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

    // Fallback for date: find any common date pattern in whole text
    if (!foundDate) {
      final match1 = RegExp(r'\b(20\d{2}-\d{2}-\d{2})\b').firstMatch(text);
      final match2 = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b').firstMatch(text);

      if (match1 != null) {
        expiryController.text = match1.group(1)!;
        _selectedExpiry = DateTime.tryParse(expiryController.text);
      } else if (match2 != null) {
        final parts = match2.group(1)!.split('/');
        expiryController.text = "${parts[2]}-${parts[1]}-${parts[0]}";
        _selectedExpiry = DateTime.tryParse(expiryController.text);
      }
    }

    // Update UI with parsed values
    if (mounted) setState(() {});
  }

  // =================== SAVE TO FIREBASE ======================
  Future<void> saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If user is not logged in, show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in. Please login.')),
      );
      return;
    }

    // Validate required fields
    if (productController.text.isEmpty ||
        expiryController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields!')),
      );
      return;
    }

    try {
      // Create a new document in user's receipts collection
      final receiptRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('receipts')
          .doc();

      // Save metadata (you can expand to upload file to storage if you want)
      await receiptRef.set({
        'productName': productController.text.trim(),
        'expiryDate': expiryController.text.trim(),
        'category': _selectedCategory,
        'uploadType': _selectedFile != null
            ? (_selectedFile!.path.toLowerCase().endsWith('.pdf')
                ? 'Imported-PDF'
                : 'Imported-Image')
            : 'Manual',
        'timestamp': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt saved successfully!')),
      );

      // Return to previous screen
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Firestore save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Try again.')),
      );
    }
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
      if (mounted) setState(() {});
    }
  }

  // Helper icon mapping
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

  // =================== UI BUILD ======================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 700; // breakpoint for responsive layout

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
                      // Left: file preview (PDF viewer or image)
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: pickFile,
                              child: Container(
                                height: 260,
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
                                // Show PDF viewer if pdf chosen; otherwise show image or placeholder
                                child: _selectedFile != null
                                    ? (_selectedFile!.path
                                            .toLowerCase()
                                            .endsWith('.pdf')
                                        ? // Display PDF inline using Syncfusion widget
                                        SfPdfViewer.file(_selectedFile!)
                                        : // Display image preview
                                        ClipRRect(
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
                            const SizedBox(height: 12),
                            // Show selected filename below the box for clarity
                            if (_selectedFile != null)
                              Text(
                                _selectedFile!.path.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right: form container
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
                              ? (_selectedFile!.path
                                      .toLowerCase()
                                      .endsWith('.pdf')
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
                      const SizedBox(height: 12),
                      if (_selectedFile != null)
                        Text(
                          _selectedFile!.path.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 16),
                      _buildFormContainer(),
                    ],
                  ),
          ),

          // Processing overlay
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

  // Build the form card (separated for clarity)
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
          const SizedBox(height: 12),

          // Product Name field
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

          // Expiry Date field (tap to pick)
          GestureDetector(
            onTap: pickExpiryDate,
            child: AbsorbPointer(
              child: TextField(
                controller: expiryController,
                decoration: InputDecoration(
                  labelText: 'Expiry Date',
                  prefixIcon:
                      const Icon(Icons.calendar_today, color: Color(0xFF1D4AB4)),
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

          // Category dropdown
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
          const SizedBox(height: 16),

          // Error text shown inside the form (e.g., OCR failed or PDF warning)
          if (_errorText != null)
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),

          const SizedBox(height: 12),

          // Save button
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
