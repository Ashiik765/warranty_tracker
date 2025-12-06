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
  bool selectMode = false; // Toggle selection mode
  Set<String> selectedProducts = {}; // Track selected doc IDs

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
                const Spacer(),
                // Top-right selection toggle
                IconButton(
                  icon: Icon(selectMode ? Icons.close : Icons.check_box),
                  onPressed: () {
                    setState(() {
                      selectMode = !selectMode;
                      selectedProducts.clear();
                    });
                  },
                  color: Colors.white,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 🔹 Product list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('receipts')
                  .where('category', isEqualTo: 'others')
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

                // Filter expired products
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

                return Stack(
                  children: [
                    ListView.builder(
                      key: const PageStorageKey('others_list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data =
                            filteredDocs[index].data() as Map<String, dynamic>;
                        final docId = filteredDocs[index].id;

                        final Timestamp? ts = data['timestamp'];
                        final addedDate =
                            ts != null ? ts.toDate() : DateTime.now();
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
                            leading: selectMode
                                ? Checkbox(
                                    value: selectedProducts.contains(docId),
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          selectedProducts.add(docId);
                                        } else {
                                          selectedProducts.remove(docId);
                                        }
                                      });
                                    },
                                  )
                                : const Icon(Icons.devices_other,
                                    size: 40, color: Colors.blue),
                            title: Text(
                              data['productName'] ?? 'Unnamed Product',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Expiry Date: ${data['expiryDate'] ?? 'N/A'}"),
                                Text("Added On: $formattedAddedDate"),
                              ],
                            ),
                            onTap: () {
                              if (!selectMode) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailsPage(
                                      productName:
                                          data['productName'] ?? '',
                                      expiryDate: data['expiryDate'] ?? '',
                                      category:
                                          data['category'] ?? 'Others',
                                      importDate: addedDate,
                                    ),
                                  ),
                                );
                              } else {
                                setState(() {
                                  if (selectedProducts.contains(docId)) {
                                    selectedProducts.remove(docId);
                                  } else {
                                    selectedProducts.add(docId);
                                  }
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),

                    // Delete + Cancel buttons at bottom
                    if (selectMode && selectedProducts.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text("Delete Selected"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                onPressed: _confirmDeleteSelected,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text("Cancel"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectMode = false;
                                    selectedProducts.clear();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Confirm deletion of multiple products
  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Products"),
        content: Text(
            "Are you sure you want to delete ${selectedProducts.length} product(s)?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedProducts();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // Delete selected products from Firestore
  Future<void> _deleteSelectedProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();

    for (String docId in selectedProducts) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('receipts')
          .doc(docId);
      batch.delete(docRef);
    }

    try {
      await batch.commit();
      setState(() {
        selectMode = false;
        selectedProducts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selected products deleted successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete products: $e")),
      );
    }
  }
}
