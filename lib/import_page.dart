import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';               // for text extraction
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';  // for PDF preview
import 'package:intl/intl.dart';

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
  final TextEditingController expiryController = TextEditingController();
  bool noDetailsFound = false;

  @override
  void dispose() {
    productController.dispose();
    expiryController.dispose();
    super.dispose();
  }

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
          productController.clear();
          expiryController.clear();
          noDetailsFound = false;
          selectedDate = null;
          category = null;
        });
        await processFile(file);
      }
    } catch (e) {
      showError("File pick error: $e");
    }
  }

  Future<void> processFile(File file) async {
    if (file.path.toLowerCase().endsWith('.pdf')) {
      await extractTextFromPdf(file);
    } else {
      await extractTextFromImage(file);
    }
  }

  Future<void> extractTextFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();

      setState(() {
        extractedText = text;
        autoFillFields(text);
      });
    } catch (e) {
      showError("PDF extraction failed: $e");
    }
  }

  Future<void> extractTextFromImage(File file) async {
    TextRecognizer? recognizer;
    try {
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await recognizer.processImage(inputImage);

      setState(() {
        extractedText = recognizedText.text;
        autoFillFields(recognizedText.text);
      });
    } catch (e) {
      showError("Image OCR failed: $e");
    } finally {
      await recognizer?.close();
    }
  }

  void autoFillFields(String text) {
    bool foundProduct = false;
    bool foundDate = false;

    final lines = text.split('\n');
    for (var line in lines) {
      final l = line.trim();
      if (!foundProduct && l.length > 3 && !RegExp(r'^[\d\W]+$').hasMatch(l)) {
        productController.text = l;
        foundProduct = true;
      }
    }

    final dateRegex = RegExp(r'\b(20\d{2}-\d{2}-\d{2})\b');
    final match = dateRegex.firstMatch(text);
    if (match != null) {
      try {
        selectedDate = DateTime.parse(match.group(1)!);
        expiryController.text = match.group(1)!;
        foundDate = true;
      } catch (_) {}
    }

    setState(() {
      noDetailsFound = !(foundProduct || foundDate);
    });
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

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
          .collection('receipts')
          .add({
        'productName': productController.text.trim(),
        'expiryDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
        'category': category,
        'uploadType': 'device',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Receipt saved successfully")),
      );

      setState(() {
        selectedFile = null;
        extractedText = null;
        productController.clear();
        expiryController.clear();
        selectedDate = null;
        category = null;
        noDetailsFound = false;
      });
    } catch (e) {
      showError("Save failed: $e");
    }
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
      body: selectedFile == null
          ? Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text("Pick File"),
                onPressed: pickFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                ),
              ),
            )
          : Row(
              children: [
                // LEFT: preview
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Colors.grey.shade200,
                    child: selectedFile!.path.toLowerCase().endsWith('.pdf')
                        ? SfPdfViewer.file(selectedFile!)
                        : Image.file(selectedFile!, fit: BoxFit.contain),
                  ),
                ),
                // RIGHT: form
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (noDetailsFound)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "No details automatically detected. Please fill manually.",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),

                        TextField(
                          controller: productController,
                          decoration: const InputDecoration(
                            labelText: "Product Name",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: expiryController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Expiry Date",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: selectDate,
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
                          items: const [
                            DropdownMenuItem(value: "Electronics", child: Text("Electronics")),
                            DropdownMenuItem(value: "Home Appliances", child: Text("Home Appliances")),
                            DropdownMenuItem(value: "Vehicle", child: Text("Vehicle")),
                            DropdownMenuItem(value: "Others", child: Text("Others")),
                          ],
                          onChanged: (v) => setState(() => category = v),
                        ),
                        const SizedBox(height: 20),

                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text("Save Receipt"),
                          onPressed: saveToFirebase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (extractedText != null) ...[
                          const Divider(),
                          const Text("Detected text preview:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(extractedText!, style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
