import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'product_page.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  // 🔹 Determine if the product is expiring within 10 days
  bool shouldNotify(DateTime expiry) {
    final today = DateTime.now();
    final daysLeft = expiry.difference(today).inDays;
    return daysLeft <= 10 && daysLeft >= 0;
  }

  // 🔹 Category Icon
  Widget getCategoryIcon(String? category) {
    String path;

    switch (category?.toLowerCase()) {
      case 'electronics':
        path = 'images/electronics.png';
        break;
      case 'vehicle':
        path = 'images/vehicle.png';
        break;
      case 'home appliances':
        path = 'images/home_appliances.png';
        break;
      default:
        path = 'images/default.png';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        path,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? Colors.white : Colors.white70),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: active ? Colors.white : Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in first.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAEAEA),

      body: Column(
        children: [
          // 🔹 Top Header
          Container(
            height: 100,
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
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 Notifications Live Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('receipts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No notifications available."));
                }

                final docs = snapshot.data!.docs;

                // 🔹 Filter: Expiring within 10 days
                final notifications = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final expiryStr = data['expiryDate'];
                  if (expiryStr == null) return false;

                  try {
                    final expiry = DateFormat('yyyy-MM-dd').parse(expiryStr);
                    return shouldNotify(expiry);
                  } catch (e) {
                    return false;
                  }
                }).toList();

                if (notifications.isEmpty) {
                  return const Center(child: Text("No notifications today."));
                }

                // 🔹 Notification Cards
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final data =
                        notifications[index].data() as Map<String, dynamic>;
                    final expiry =
                        DateFormat('yyyy-MM-dd').parse(data['expiryDate']);
                    final daysLeft = expiry.difference(DateTime.now()).inDays;

                    return Card(
                      color: Colors.white,
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            getCategoryIcon(data['category']),
                            const SizedBox(width: 15),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['productName'] ?? 'Unnamed Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Expires in $daysLeft day(s)",
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 🔹 Bottom Navigation
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1D4AB4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bottomNavItem(
              icon: Icons.home,
              label: 'Home',
              active: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
            ),

            _bottomNavItem(
              icon: Icons.notifications,
              label: 'Products',
              active: true,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductPage()),
                );
              },
            ),

            _bottomNavItem(
              icon: Icons.person,
              label: 'User',
              active: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

