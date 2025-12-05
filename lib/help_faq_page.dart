import 'package:flutter/material.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  final List<Map<String, String>> faqList = const [
    {
      "question": "How do I edit my profile?",
      "answer": "Go to the Profile page and tap 'Edit Profile' to change your name."
    },
    {
      "question": "How can I report a problem?",
      "answer": "Use the 'Feedback / Report Issue' option from the Profile page."
    },
    {
      "question": "Is my data safe?",
      "answer": "Yes, your data is stored securely using Firebase Authentication and Firestore."
    },
    {
      "question": "What is this app for?",
      "answer": "This app is used to manage your products, profile, and feedback in a simple way."
    },
    {
      "question": "Who developed this app?",
      "answer": "This app was developed by Ashiii and team for a university project."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & FAQs"),
        backgroundColor: const Color(0xFF1D4AB4),
      ),
      body: ListView.builder(
        itemCount: faqList.length,
        itemBuilder: (context, index) {
          final faq = faqList[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Card(
              child: ExpansionTile(
                title: Text(faq["question"]!),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(faq["answer"]!),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
