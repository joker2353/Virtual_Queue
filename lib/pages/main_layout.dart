import 'package:flutter/material.dart';
import 'home_page.dart';
import 'saved_rooms_page.dart';
import 'create_room_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [const SavedRoomsPage(), const HomePage(), const CreateRoomPage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        height: 90,
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 20),
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    Icons.store_outlined,
                    Icons.store,
                    'Saved Shops',
                  ),
                  _buildNavItem(
                    1,
                    Icons.home_outlined,
                    Icons.home,
                    'Home',
                    opacity: 0,
                  ),
                  _buildNavItem(
                    2,
                    Icons.add_box_outlined,
                    Icons.add_box,
                    'Create Shop',
                  ),
                ],
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () => _onItemTapped(1),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _selectedIndex == 1 ? Icons.home : Icons.home_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    double opacity = 1.0,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: Opacity(
        opacity: opacity,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.deepPurple : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.deepPurple : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
