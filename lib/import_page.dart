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
  File? selectedFile;
  String? extractedText;
  DateTime? selectedDate;
  String? category;

  final TextEditingController productController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-open file picker shortly after page loads
    Future.delayed(const Duration(milliseconds: 300), () {
      pickFile();
    });
  }

  @override
  void dispose() {
    productController.dispose();
    super.dispose();
  }

  // Pick a file (PDF or Image)
  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFile = File(result.files.single.path!);
          extractedText = null;
          // Keep any previous productController text until we extract new
        });

        if (selectedFile!.path.toLowerCase().endsWith('.pdf')) {
          await extractTextFromPdf(selectedFile!);
        } else {
          await extractTextFromImage(selectedFile!);
        }
      } else {
        // user cancelled — optionally pop page
        // Navigator.pop(context);
      }
    } catch (e) {
      showError("File pick error: $e");
    }
  }

  // Extract text from PDF using Syncfusion
  Future<void> extractTextFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Use PdfTextExtractor to extract all text from document
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();

      document.dispose();

      setState(() {
        extractedText = text;
        // Auto-fill product name from extracted text
        productController.text = extractProductName(text);
      });
    } catch (e) {
      showError("Error reading PDF: $e");
    }
  }

  // Extract text from image using ML Kit OCR
  Future<void> extractTextFromImage(File file) async {
    TextRecognizer? textRecognizer;
    try {
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(file);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      setState(() {
        extractedText = recognizedText.text;
        productController.text = extractProductName(extractedText ?? '');
      });
    } catch (e) {
      showError("Error reading image: $e");
    } finally {
      // always close recognizer if it was created
      await textRecognizer?.close();
    }
  }

  // Return a probable product name from raw text
  String extractProductName(String text) {
    if (text.trim().isEmpty) return '';

    // split lines by newline properly
    List<String> lines = text.split('\n');

    // Try to find a line that looks like a product name: longer than 3 chars and not mainly digits
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.length > 3 && !RegExp(r'^[\d\W]+$').hasMatch(trimmed)) {
        return trimmed;
      }
    }

    // fallback to first non-empty line or empty string
    for (var line in lines) {
      if (line.trim().isNotEmpty) return line.trim();
    }
    return '';
  }

  // Save the extracted/entered product record to Firestore
  Future<void> saveToFirebase() async {
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .add({
        'productName': productController.text.trim(),
        'expiryDate': selectedDate!.toIso8601String().split("T").first,
        'category': category,
        'timestamp': FieldValue.serverTimestamp(),
        // you can add e.g. 'sourceFile': selectedFile?.path
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Receipt saved successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      showError("Error saving: $e");
    }
  }

  // Open a date picker for expiry date
  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) setState(() => selectedDate = picked);
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Import Receipt"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // show selected filename if exists
            if (selectedFile != null) Text("Selected: ${selectedFile!.path.split('/').last}"),
            const SizedBox(height: 12),

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
            if (extractedText != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const Text("Extracted text (preview):", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(extractedText ?? '', style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
