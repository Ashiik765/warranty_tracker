import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'product_details_page.dart';

class OthersPage extends StatefulWidget {
  const OthersPage({super.key});

  @override
  State<OthersPage> createState() => _OthersPageState();
}

class _OthersPageState extends State<OthersPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFEAEAEA),

      body: Column(
        children: [
          // 🔹 Top bar
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
                  'Others',
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

          // 🔹 Product list (Firestore)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('receipts')
                  .where('category', isEqualTo: 'others') // ✅ Match exact case
                  // .orderBy('timestamp', descending: true)
                  .snapshots(),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading data. Please try again.'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No products found under Others.'),
                  );
                }

                final docs = snapshot.data!.docs;

                // ✅ Filter out expired products
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final expiry = data['expiryDate'];
                  if (expiry == null) return true;

                  try {
                    final expiryDate = DateFormat('yyyy-MM-dd').parse(expiry);
                    return expiryDate.isAfter(DateTime.now());
                  } catch (_) {
                    return true;
                  }
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No active receipts available.'),
                  );
                }

                // ✅ Stable list (prevents flickering)
                return ListView.builder(
                  key: const PageStorageKey('others_list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;

                    final Timestamp? ts = data['timestamp'];
                    final addedDate = ts != null ? ts.toDate() : DateTime.now();
                    final formattedAddedDate =
                        DateFormat('yyyy-MM-dd h:mm a').format(addedDate);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.devices_other,
                            size: 40, color: Colors.blue),
                        title: Text(
                          data['productName'] ?? 'Unnamed Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Expiry Date: ${data['expiryDate'] ?? 'N/A'}"),
                            Text("Added On: $formattedAddedDate"),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsPage(
                                productName: data['productName'] ?? '',
                                expiryDate: data['expiryDate'] ?? '',
                                category: data['category'] ?? 'Others',
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
    );
  }
}
