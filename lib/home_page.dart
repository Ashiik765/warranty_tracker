// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'type_receipt.dart';
import 'product_page.dart';
import 'profile_page.dart';
import 'notification_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _pressedIndex = -1;

  void logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void openGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selected image: ${image.name}")),
      );
    }
  }

  Widget _actionCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    final isPressed = _pressedIndex == index;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedIndex = index),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 120),
          () => setState(() => _pressedIndex = -1)),
      onTapCancel: () => setState(() => _pressedIndex = -1),
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: isPressed ? 0.93 : 1.0,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.95), color.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
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
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginPage()));
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayName =
        user.displayName ?? user.email?.split('@')[0] ?? 'Chief';

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF6D8DF6),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => logout(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white),
                          ),
                        ),

                        // 🔔 Notification Icon with Badge
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('receipts')
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = 0;
                            if (snapshot.hasData) {
                              final docs = snapshot.data!.docs;
                              final today = DateTime.now();
                              count = docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final expiryStr = data['expiryDate'];
                                if (expiryStr == null) return false;
                                try {
                                  final expiry = DateTime.parse(expiryStr);
                                  final daysLeft =
                                      expiry.difference(today).inDays;
                                  return daysLeft <= 10 && daysLeft >= 0;
                                } catch (e) {
                                  return false;
                                }
                              }).length;
                            }

                            String badgeText = count > 99 ? '99+' : '$count';

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationPage()));
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          badgeText,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text('Welcome back,',
                        style: TextStyle(
                            fontSize: 30,
                            color: Colors.white.withOpacity(0.9))),
                    const SizedBox(height: 6),
                    Text(displayName,
                        style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Here are your latest receipts and shortcuts',
                        style: TextStyle(
                            fontSize: 17,
                            color: Colors.white.withOpacity(0.9))),
                    const SizedBox(height: 26),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _actionCard(
                            label: 'Add',
                            icon: Icons.upload_file,
                            color: Colors.blueGrey.shade700,
                            onTap: openGallery,
                            index: 0),
                        _actionCard(
                            label: 'Scan',
                            icon: Icons.qr_code_scanner,
                            color: Colors.deepOrange,
                            onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ScanPage()),
                                ),
                            index: 1),
                        _actionCard(
                            label: 'Type',
                            icon: Icons.edit,
                            color: Colors.purple,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const TypeReceiptPage())),
                            index: 2),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text('Recent',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('receipts')
                          .orderBy('timestamp', descending: true)
                          .limit(1)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child:
                                  CircularProgressIndicator(color: Colors.white));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const RecentReceiptCard(data: null);
                        }

                        final doc = snapshot.data!.docs.first;
                        final data = doc.data() as Map<String, dynamic>?;

                        return RecentReceiptCard(data: data);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _bottomNavItem(
                      icon: Icons.home,
                      label: 'Home',
                      active: true,
                      onTap: () {}),
                  _bottomNavItem(
                      icon: Icons.shopping_bag,
                      label: 'Product',
                      active: false,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProductPage()))),
                  _bottomNavItem(
                      icon: Icons.person,
                      label: 'User',
                      active: false,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfilePage()))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Separate stateless widget for recent receipt =====
class RecentReceiptCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  const RecentReceiptCard({Key? key, this.data}) : super(key: key);

  Widget _categoryIcon(dynamic category) {
    final cat = (category ?? "").toString().toLowerCase();
    if (cat.contains('elect')) {
      return const Icon(Icons.electrical_services, color: Colors.blue);
    } else if (cat.contains('home')) {
      return const Icon(Icons.kitchen, color: Colors.orange);
    } else if (cat.contains('veh') || cat.contains('car')) {
      return const Icon(Icons.directions_car, color: Colors.green);
    } else if (cat == '-' || cat.isEmpty) {
      return const Icon(Icons.receipt_long, color: Colors.black54);
    } else {
      return const Icon(Icons.category, color: Colors.purple);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = data?['productName'] ?? 'No receipts yet';
    final category = data?['category'] ?? '-';
    final expiry = data?['expiryDate'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: _categoryIcon(data?['category'])),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 6),
                Text("Category: $category",
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                Text("Expiry: $expiry",
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
