import 'package:flutter/material.dart';

class AboutDevicePage extends StatelessWidget {
  const AboutDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About App"),
        backgroundColor: const Color(0xFF1D4AB4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF2F2F2),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
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
            children: const [
              Text(
                "📱 App Name",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text("Applux – Smart Warranty Tracker App"),

              SizedBox(height: 16),
              Text(
                "🧾 Version",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text("1.0.0"),

              SizedBox(height: 16),
              Text(
                "👨‍💻 Developer",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text("Ashiii & Team – IT Students, Final Year Project"),

              SizedBox(height: 16),
              Text(
                "📌 Description",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                "Applux is a smart warranty management system that helps users track receipts, manage product warranties, "
                "and get notified before expiry. It supports OCR scanning, PDF import, secure Firebase login, and real-time updates.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
