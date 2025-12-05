import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductDetailsPage extends StatelessWidget {
  final String productName;
  final String expiryDate;
  final String category;
  final DateTime importDate;

  const ProductDetailsPage({
    super.key,
    required this.productName,
    required this.expiryDate,
    required this.category,
    required this.importDate,
  });

  @override
  Widget build(BuildContext context) {
    String formattedImportDate = DateFormat('yyyy-MM-dd h:mm a').format(importDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4AB4),
        title: const Text('Product Details'),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 30, color: Colors.blueAccent),
              const SizedBox(height: 16),
              Text(
                "📦 Product Name",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                productName,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              Text(
                "📅 Expiry Date",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                expiryDate,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              Text(
                "📥 Imported On",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                formattedImportDate,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              Text(
                "📂 Category",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                category,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
