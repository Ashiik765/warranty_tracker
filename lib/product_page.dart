import 'package:flutter/material.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'electronic_page.dart';
import 'home_appliances_page.dart';
import 'vehicle_page.dart';
import 'others_page.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  void navigateBack(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void openCategory(BuildContext context, String category) {
    Widget page;
    switch (category) {
      case 'Electronics':
        page = const ElectronicsPage();
        break;
      case 'Home Appliances':
        page = const HomeAppliancesPage();
        break;
      case 'Vehicle':
        page = const VehiclePage();
        break;
      case 'Others':
        page = const OthersPage();
        break;
      default:
        page = const HomePage();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAEAEA),
      body: Column(
        children: [
          // Top bar
          Container(
            height: 101,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF1D4AB4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => navigateBack(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Categories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: [
                  _buildCategoryBox(
                    context,
                    title: 'Electronics',
                    imagePath: 'images/electronics.png',
                  ),
                  _buildCategoryBox(
                    context,
                    title: 'Home Appliances',
                    imagePath: 'images/home_appliances.png',
                  ),
                  _buildCategoryBox(
                    context,
                    title: 'Vehicle',
                    imagePath: 'images/vehicle.png',
                  ),
                  _buildCategoryBox(
                    context,
                    title: 'Others',
                    imagePath: 'images/others.png',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 🔹 SAME BLUE BOTTOM NAV BAR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D4AB4),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -2),
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
              icon: Icons.shopping_bag,
              label: 'Product',
              active: true,
              onTap: () {},
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

  // Reusable Category Card
  Widget _buildCategoryBox(BuildContext context,
      {required String title, required String imagePath}) {
    return GestureDetector(
      onTap: () => openCategory(context, title),
      child: Container(
        width: 179,
        height: 196,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 70, height: 70, fit: BoxFit.contain),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Reusable bottom navigation item
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
          Icon(
            icon,
            color: active ? Colors.white : Colors.white70,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
