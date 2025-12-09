import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'home_page.dart';
import 'product_page.dart';
import 'login_page.dart';
import 'editprofile_page.dart';
import 'help_faq_page.dart';
import 'about_device.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? photoUrl;
  final String defaultImage = 'images/common.jpg';
  File? _image;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    setState(() {
      photoUrl = doc.data()?['photoUrl'];
    });
  }

  // ================= Pick & Upload Image ==================
  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);

    setState(() {
      _image = file; // Show local preview immediately
    });

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading profile picture...")),
      );

      // Delete old image first (if exists)
      final oldDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final oldPhotoUrl = oldDoc.data()?['photoUrl'];
      if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldPhotoUrl).delete();
          print('✓ Old image deleted');
        } catch (e) {
          print('⚠ Old image not found or already deleted: $e');
        }
      }

      // Use a unique filename with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_images/${user.uid}_$timestamp.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      // Upload file
      final uploadTask = storageRef.putFile(file);

      // Wait for upload to complete
      await uploadTask;

      // Verify upload was successful
      try {
        // Add delay to ensure file is finalized in storage
        await Future.delayed(const Duration(milliseconds: 1000));

        // Get download URL
        final downloadUrl = await storageRef.getDownloadURL();

        // Save download URL to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'photoUrl': downloadUrl});

        setState(() {
          photoUrl = downloadUrl; // Update UI with uploaded image
          _image = null; // Clear local preview
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated!")),
          );
        }
      } catch (e) {
        print('Error getting download URL: $e');
        throw Exception('Failed to get download URL: $e');
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _image = null; // Clear preview on error
        photoUrl = null; // Reset to default
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading: $e")),
        );
      }
    }
  }

  // ================= Remove Image ==================
  Future<void> _removeImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get current photoUrl from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final currentPhotoUrl = doc.data()?['photoUrl'];

      if (currentPhotoUrl != null) {
        try {
          // Delete from storage using the URL
          await FirebaseStorage.instance.refFromURL(currentPhotoUrl).delete();
        } catch (e) {
          // If file not found in storage, continue anyway
          print('Storage file not found (OK): $e');
        }
      }

      // Remove photoUrl from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photoUrl': FieldValue.delete()}, SetOptions(merge: true));

      setState(() {
        photoUrl = null;
        _image = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture removed.")),
      );
    } catch (e) {
      print('Error removing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error removing image: $e")),
      );
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SizedBox(
          height: 150,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload, color: Colors.blue),
                title: const Text("Upload Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Remove Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Do you really want to logout?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout"),
          )
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
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
          Text(label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 110,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D4AB4), Color(0xFF395EB6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Text(
            "Profile",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Profile card
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(2, 4))
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _image != null
                          ? FileImage(_image!)
                          : (photoUrl != null
                              ? NetworkImage(photoUrl!) as ImageProvider
                              : AssetImage(defaultImage) as ImageProvider),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      user?.displayName ??
                          user?.email?.split('@').first ??
                          "User",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4AB4),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Grid buttons
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: [
                _buildGridCard(
                  icon: Icons.edit,
                  title: "Edit Profile",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  ),
                ),
                _buildGridCard(
                  icon: Icons.help_center,
                  title: "Help & FAQ",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpFaqPage()),
                  ),
                ),
                _buildGridCard(
                  icon: Icons.info_outline,
                  title: "About App",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutDevicePage()),
                  ),
                ),
                _buildGridCard(
                  icon: Icons.logout,
                  title: "Logout",
                  onTap: () => logout(context),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF1D4AB4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bottomNavItem(
                icon: Icons.home,
                label: "Home",
                active: false,
                onTap: () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const HomePage()));
                }),
            _bottomNavItem(
                icon: Icons.shopping_bag,
                label: "Product",
                active: false,
                onTap: () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const ProductPage()));
                }),
            _bottomNavItem(
                icon: Icons.person, label: "User", active: true, onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(2, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: const Color(0xFF1D4AB4)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D4AB4)),
            )
          ],
        ),
      ),
    );
  }
}
