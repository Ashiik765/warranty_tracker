import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'product_details_page.dart';

class HomeAppliancesPage extends StatelessWidget {
  const HomeAppliancesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 🔥 Prevent crash if user is null
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not signed in"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAEAEA),

      body: Column(
        children: [
          // ---------------- TOP APP BAR ----------------
          Container(
            height: 101,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF1D4AB4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Home Appliances',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------------- RECEIPT LIST ----------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('receipts')               // 🔥 Correct collection
                  .where('category', isEqualTo: 'Home Appliances')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No products found."));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    // Safe timestamp conversion
                    final timestamp = data['timestamp'];
                    DateTime addedDate = DateTime.now();
                    if (timestamp is Timestamp) {
                      addedDate = timestamp.toDate();
                    }

                    String formattedDate =
                        DateFormat('yyyy-MM-dd h:mm a').format(addedDate);

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.devices_other, size: 40),
                        title: Text(
                          data['productName'] ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Expiry Date: ${data['expiryDate'] ?? 'Not set'}"),
                            Text("Added On: $formattedDate"),
                          ],
                        ),

                        // ---------------- GO TO DETAILS ----------------
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsPage(
                                productName: data['productName'] ?? '',
                                expiryDate: data['expiryDate'] ?? '',
                                category: 'Home Appliances',
                                importDate: addedDate,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ---------------- BOTTOM NAV BAR ----------------
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          if (index == 0) Navigator.pop(context); // Simple navigation
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'User'),
        ],
      ),
    );
  }
}
