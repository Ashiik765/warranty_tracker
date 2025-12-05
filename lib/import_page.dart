import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({Key? key}) : super(key: key);

  @override
  _ImportPageState createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  File? selectedFile; // chosen PDF/image file
  String? extractedText; // OCR / PDF extracted text
  DateTime? selectedDate; // expiry date chosen by user
  String? category; // selected category
  final TextEditingController productController = TextEditingController(); // product name input

  @override
  void initState() {
    super.initState();
    // try to auto-open file picker shortly after page loads, but protect against errors
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        await pickFile();
      } catch (e) {
        // ignore errors here so page doesn't crash on startup
        debugPrint("Auto file pick error (ignored): $e");
      }
    });
  }

  @override
  void dispose() {
    productController.dispose(); // release controller resources
    super.dispose();
  }

  // ---------- PICK A FILE (PDF or IMAGE) ----------
  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFile = File(result.files.single.path!); // save file
          extractedText = null; // reset previous extraction
        });

        // If PDF → extract with Syncfusion, else use ML Kit OCR
        if (selectedFile!.path.toLowerCase().endsWith('.pdf')) {
          await extractTextFromPdf(selectedFile!);
        } else {
          await extractTextFromImage(selectedFile!);
        }
      } else {
        // user cancelled — nothing to do
      }
    } catch (e) {
      showError("File pick error: $e");
    }
  }

  // ---------- EXTRACT TEXT FROM PDF ----------
  Future<void> extractTextFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes(); // read PDF bytes
      final PdfDocument document = PdfDocument(inputBytes: bytes); // open PDF
      final PdfTextExtractor extractor = PdfTextExtractor(document); // extractor
      final String text = extractor.extractText(); // get text
      document.dispose(); // free document resources

      setState(() {
        extractedText = text; // set extracted text
        // auto-fill product controller with best guess
        productController.text = extractProductName(text);
      });
    } catch (e) {
      showError("Error reading PDF: $e");
    }
  }

  // ---------- EXTRACT TEXT FROM IMAGE USING ML KIT ----------
  Future<void> extractTextFromImage(File file) async {
    TextRecognizer? textRecognizer;
    try {
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(file);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      setState(() {
        extractedText = recognizedText.text; // full text
        productController.text = extractProductName(extractedText ?? '');
      });
    } catch (e) {
      showError("Error reading image: $e");
    } finally {
      // always close recognizer if created to avoid resource leaks
      await textRecognizer?.close();
    }
  }

  // ---------- SIMPLE HEURISTIC TO PICK A PRODUCT NAME ----------
  String extractProductName(String text) {
    if (text.trim().isEmpty) return '';

    // split by newline and try to find a useful line
    final List<String> lines = text.split('\n');

    for (var line in lines) {
      final trimmed = line.trim();
      // prefer lines longer than 3 chars and not purely symbols/digits
      if (trimmed.length > 3 && !RegExp(r'^[\d\W]+$').hasMatch(trimmed)) {
        return trimmed;
      }
    }

    // fallback: first non-empty line
    for (var line in lines) {
      if (line.trim().isNotEmpty) return line.trim();
    }
    return '';
  }

  // ---------- SAVE TO FIRESTORE (users/{uid}/receipts) ----------
  Future<void> saveToFirebase() async {
    // basic validation: product name, date, and category required
    if (productController.text.trim().isEmpty || selectedDate == null || category == null) {
      showError("Please fill all fields");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showError("User not signed in");
      return;
    }

    try {
      // write to receipts collection (consistent with other pages)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('receipts') // FIXED COLLECTION NAME
          .add({
        'productName': productController.text.trim(),
        'expiryDate': selectedDate!.toIso8601String().split("T").first,
        'category': category,
        'uploadType': 'Imported', // ADDED FIELD FOR CONSISTENCY
        'sourceFile': selectedFile?.path, // optional helpful field
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Receipt saved successfully")),
      );

      Navigator.pop(context); // close page after save
    } catch (e) {
      showError("Error saving: $e");
    }
  }

  // ---------- DATE PICKER ----------
  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  // ---------- HELPER TO SHOW ERRORS ----------
  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Import Receipt"),
        backgroundColor: Colors.deepPurple,
        actions: [
          // Allow user to re-open file picker anytime
          IconButton(
            tooltip: 'Pick file',
            icon: const Icon(Icons.folder_open),
            onPressed: () => pickFile(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // show selected filename if exists
            if (selectedFile != null) ...[
              Text("Selected: ${selectedFile!.path.split('/').last}"),
              const SizedBox(height: 12),
            ],

            // Product name (auto filled or editable)
            TextField(
              controller: productController,
              decoration: const InputDecoration(
                labelText: "Product Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Category selector
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: "Select Category",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "Electronics", child: Text("Electronics")),
                DropdownMenuItem(value: "Home Appliances", child: Text("Home Appliances")),
                DropdownMenuItem(value: "Vehicle", child: Text("Vehicle")),
                DropdownMenuItem(value: "Others", child: Text("Others")),
              ],
              onChanged: (v) => setState(() => category = v),
            ),
            const SizedBox(height: 12),

            // expiry date display + picker
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate == null
                        ? "No date selected"
                        : "Expiry: ${selectedDate!.toLocal().toString().split(' ')[0]}",
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: selectDate,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Save button
            ElevatedButton.icon(
              onPressed: saveToFirebase,
              icon: const Icon(Icons.save),
              label: const Text("Save Receipt"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),

            const SizedBox(height: 20),

            // Show extracted raw text (optional, helps user edit)
            if (extractedText != null) ...[
              const Divider(),
              const Text("Extracted text (preview):", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(extractedText ?? '', style: const TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
