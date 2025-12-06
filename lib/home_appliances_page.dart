import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'product_details_page.dart';

class HomeAppliancesPage extends StatefulWidget {
  const HomeAppliancesPage({super.key});

  @override
  State<HomeAppliancesPage> createState() => _HomeAppliancesPageState();
}

class _HomeAppliancesPageState extends State<HomeAppliancesPage> {
  bool selectMode = false;
  Set<String> selectedProducts = {};

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not signed in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAEAEA),
      body: Column(
        children: [
          // 🔹 Custom Top Bar
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

          // 🔹 List of Home Appliances products
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('receipts')
                  .where('category', isEqualTo: 'Home Appliances') // must match Firebase
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No Home Appliances products found."));
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
                  return const Center(child: Text("No active Home Appliances products."));
                }

                return Stack(
                  children: [
                    ListView.builder(
                      key: const PageStorageKey('home_appliances_list'),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;
                        final docId = filteredDocs[index].id;

                        final Timestamp? ts = data['timestamp'];
                        final addedDate = ts != null ? ts.toDate() : DateTime.now();
                        final formattedAddedDate =
                            DateFormat('yyyy-MM-dd h:mm a').format(addedDate);

                        bool isSelected = selectedProducts.contains(docId);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: selectMode
                                ? Checkbox(
                                    value: isSelected,
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
                                : const Icon(Icons.devices_other, size: 40, color: Colors.blue),
                            title: Text(
                              data['productName'] ?? 'Unknown Product',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Expiry Date: ${data['expiryDate'] ?? 'Not set'}"),
                                Text("Added On: $formattedAddedDate"),
                              ],
                            ),
                            onTap: () {
                              if (!selectMode) {
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
                              } else {
                                setState(() {
                                  if (isSelected) {
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

                    // Bottom delete + cancel bar
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
                                label: Text("Delete (${selectedProducts.length}) Selected"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: _confirmDeleteSelected,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                child: const Text("Cancel"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    padding: const EdgeInsets.symmetric(vertical: 14)),
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

  // Confirm deletion dialog
  void _confirmDeleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Selected Home Appliances"),
        content: Text(
            "Are you sure you want to delete ${selectedProducts.length} product(s)?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      _deleteSelectedProducts();
    }
  }

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
        selectedProducts.clear();
        selectMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selected products deleted successfully.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete products: $e")));
    }
  }
}
