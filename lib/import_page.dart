import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart'; // <-- Make sure this file exists

class ImportPage extends StatefulWidget {
  const ImportPage({Key? key}) : super(key: key);

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  File? selectedFile;
  String? extractedText;
  String? productName;
  String? expiryDate;
  String? category;
  DateTime? selectedExpiry;

  bool ocrSuccess = false;
  bool isProcessing = false;
  bool noDetailsFound = false;

  late TextEditingController productController;
  late TextEditingController expiryController;

  final List<String> categories = [
    'Electronics',
    'Vehicle',
    'Home Appliances',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    productController = TextEditingController();
    expiryController = TextEditingController();
  }

  @override
  void dispose() {
    productController.dispose();
    expiryController.dispose();
    super.dispose();
  }

  // =================== PICK FILE ======================
  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        setState(() {
          selectedFile = file;
          extractedText = null;
          productName = null;
          expiryDate = null;
          selectedExpiry = null;
          category = null;
          ocrSuccess = false;
          noDetailsFound = false;
          isProcessing = true;
        });

        print("File picked: ${file.path}");
        await processFile(file);

        setState(() {
          isProcessing = false;
        });
      }
    } catch (e) {
      showError("File pick error: $e");
    }
  }

  // =================== PROCESS FILE ======================
  Future<void> processFile(File file) async {
    try {
      if (file.path.toLowerCase().endsWith('.pdf')) {
        await extractTextFromPdf(file);
      } else {
        await extractTextFromImage(file);
      }
      print("File processed successfully");
    } catch (e, st) {
      print("Error in processing file: $e\n$st");
      showError("Processing failed: $e");
    }
  }

  // =================== EXTRACT PDF TEXT ======================
  Future<void> extractTextFromPdf(File file) async {
    try {
      print("Extracting PDF...");
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();

      print("PDF text extracted: $text");

      if (mounted) {
        setState(() {
          extractedText = text;
          parseTextForFields(text);
        });
      }
    } catch (e) {
      showError("PDF extraction failed: $e");
    }
  }

  // =================== EXTRACT IMAGE TEXT ======================
  Future<void> extractTextFromImage(File file) async {
    TextRecognizer? recognizer;
    try {
      print("Starting OCR...");
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await recognizer.processImage(inputImage);

      print("OCR result: ${recognizedText.text}");

      if (mounted) {
        setState(() {
          extractedText = recognizedText.text;
          parseTextForFields(recognizedText.text);
        });
      }
    } catch (e) {
      showError("Image OCR failed: $e");
    } finally {
      await recognizer?.close();
    }
  }

  // =================== PARSE TEXT ======================
  void parseTextForFields(String text) {
    bool foundProduct = false;
    bool foundDate = false;

    final lines = text.split('\n');

    for (var line in lines) {
      final l = line.trim().toLowerCase();

      // Detect product name
      if (!foundProduct && (l.contains("name") || l.contains("product"))) {
        if (line.contains(":")) {
          productName = line.split(":").last.trim();
        } else {
          productName = line.trim();
        }
        foundProduct = true;
      }

      // Detect expiry date
      if (!foundDate && (l.contains("exp") || l.contains("expiry"))) {
        final match1 = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(line);
        final match2 = RegExp(r'\d{2}/\d{2}/\d{4}').firstMatch(line);

        if (match1 != null) {
          expiryDate = match1.group(0);
          selectedExpiry = DateTime.parse(expiryDate!);
          foundDate = true;
        } else if (match2 != null) {
          final parts = match2.group(0)!.split('/');
          expiryDate = "${parts[2]}-${parts[1]}-${parts[0]}";
          selectedExpiry = DateTime.parse(expiryDate!);
          foundDate = true;
        }
      }
    }

    // Fallback: first non-numeric line as product
    if (!foundProduct) {
      for (var line in lines) {
        final l = line.trim();
        if (l.length > 3 && !RegExp(r'^[\d\W]+$').hasMatch(l)) {
          productName = l;
          foundProduct = true;
          break;
        }
      }
    }

    // Fallback: detect any date format
    if (!foundDate) {
      final dateRegex1 = RegExp(r'\b(20\d{2}-\d{2}-\d{2})\b');
      final dateRegex2 = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b');

      final match1 = dateRegex1.firstMatch(text);
      final match2 = dateRegex2.firstMatch(text);

      if (match1 != null) {
        expiryDate = match1.group(1);
        selectedExpiry = DateTime.parse(expiryDate!);
        foundDate = true;
      } else if (match2 != null) {
        final parts = match2.group(1)!.split('/');
        expiryDate = "${parts[2]}-${parts[1]}-${parts[0]}";
        selectedExpiry = DateTime.parse(expiryDate!);
        foundDate = true;
      }
    }

    // Update controllers
    productController.text = productName ?? "";
    expiryController.text = expiryDate ?? "";

    setState(() {
      ocrSuccess = foundProduct || foundDate;
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
      expiryDate = DateFormat('yyyy-MM-dd').format(picked);
      expiryController.text = expiryDate!;
      setState(() {});
    }
  }

  // =================== SAVE TO FIREBASE + TEST NOTIFICATIONS ======================
  Future<void> saveToFirebase() async {
    if ((productName == null || expiryDate == null) || category == null) {
      showError("Please complete all fields");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showError("User not logged in");
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('receipts')
          .add({
        'productName': productName,
        'expiryDate': expiryDate,
        'category': category,
        'uploadType': 'device',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final receiptId = doc.id;

      // =================== TEST NOTIFICATIONS ======================
      final now = DateTime.now();

      NotificationService.scheduleNotification(
        id: receiptId.hashCode,
        title: "Test Notification",
        body: "$productName warranty test!",
        scheduledTime: now.add(const Duration(seconds: 10)), // 10 sec later
      );

      NotificationService.scheduleNotification(
        id: receiptId.hashCode + 1,
        title: "Second Test Notification",
        body: "$productName warranty second test!",
        scheduledTime: now.add(const Duration(seconds: 20)), // 20 sec later
      );

      print("Test notifications scheduled for 10s and 20s later.");

      // =================== Success SnackBar ======================
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Receipt saved successfully")),
      );

      // Clear form
      setState(() {
        selectedFile = null;
        extractedText = null;
        productName = null;
        expiryDate = null;
        selectedExpiry = null;
        category = null;
        ocrSuccess = false;
        noDetailsFound = false;
        productController.clear();
        expiryController.clear();
      });
    } catch (e) {
      showError("Save failed: $e");
    }
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =================== BUILD UI ======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Import & Preview Receipt"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: pickFile,
          ),
        ],
      ),
      body: isProcessing
          ? const Center(child: CircularProgressIndicator())
          : selectedFile == null
              ? Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Pick File"),
                    onPressed: pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 20),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // FILE PREVIEW
                      Container(
                        height: 300,
                        color: Colors.grey.shade200,
                        child: selectedFile!.path.toLowerCase().endsWith('.pdf')
                            ? SfPdfViewer.file(selectedFile!)
                            : Image.file(selectedFile!, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 16),

                      // DETECTED TEXT
                      if (ocrSuccess && extractedText != null) ...[
                        const Text(
                          "Detected text preview:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            extractedText!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (!ocrSuccess && noDetailsFound)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "No details detected. Fill manually.",
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),

                      // PRODUCT NAME
                      TextField(
                        controller: productController,
                        onChanged: (v) => productName = v,
                        decoration: const InputDecoration(
                          labelText: "Product Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // EXPIRY DATE
                      GestureDetector(
                        onTap: pickExpiryDate,
                        child: AbsorbPointer(
                          child: TextField(
                            controller: expiryController,
                            decoration: InputDecoration(
                              labelText: "Expiry Date",
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_month),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // CATEGORY
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: "Select Category",
                          border: OutlineInputBorder(),
                        ),
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => category = v),
                      ),
                      const SizedBox(height: 20),

                      // SAVE BUTTON
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("Save Receipt"),
                        onPressed: saveToFirebase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(
                              vertical: 15, horizontal: 20),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
