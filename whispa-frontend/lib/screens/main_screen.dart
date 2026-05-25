import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'home.dart';
import '../screens/nearby_page.dart';
import '../screens/music_page.dart';
import '../screens/settings_page.dart';

/// ✅ NEW: Main App with Bottom Navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Pages for navigation
  final List<Widget> _pages = const [
    Home(),
    NearbyPage(),
    MusicPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            // Desktop/Web layout with NavigationRail
            return Row(
              children: [
                NavigationRail(
                  backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(
                    color: Color.fromRGBO(32, 211, 102, 1),
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: Color.fromRGBO(161, 161, 170, 1),
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Color.fromRGBO(32, 211, 102, 1),
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Color.fromRGBO(161, 161, 170, 1),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: _buildNavIcon(Icons.chat_bubble_outline, 0),
                      selectedIcon: _buildNavIcon(Icons.chat_bubble, 0),
                      label: const Text('Chats'),
                    ),
                    NavigationRailDestination(
                      icon: _buildNavIcon(Icons.people_outline, 1),
                      selectedIcon: _buildNavIcon(Icons.people, 1),
                      label: const Text('Nearby'),
                    ),
                    NavigationRailDestination(
                      icon: _buildNavIcon(Icons.music_note_outlined, 2),
                      selectedIcon: _buildNavIcon(Icons.music_note, 2),
                      label: const Text('Music'),
                    ),
                    NavigationRailDestination(
                      icon: _buildNavIcon(Icons.settings_outlined, 3),
                      selectedIcon: _buildNavIcon(Icons.settings, 3),
                      label: const Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: Color.fromRGBO(39, 39, 42, 1)),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
              ],
            );
          } else {
            // Mobile layout with BottomNavigationBar
            return Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
                Consumer<AppStateProvider>(
                  builder: (context, provider, child) {
                    return Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Color.fromRGBO(39, 39, 42, 1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: BottomNavigationBar(
                        currentIndex: _currentIndex,
                        onTap: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
                        selectedItemColor: const Color.fromRGBO(32, 211, 102, 1),
                        unselectedItemColor: const Color.fromRGBO(161, 161, 170, 1),
                        type: BottomNavigationBarType.fixed,
                        elevation: 0,
                        items: [
                          BottomNavigationBarItem(
                            icon: _buildNavIcon(Icons.chat_bubble_outline, 0),
                            activeIcon: _buildNavIcon(Icons.chat_bubble, 0),
                            label: 'Chats',
                          ),
                          BottomNavigationBarItem(
                            icon: _buildNavIcon(Icons.people_outline, 1),
                            activeIcon: _buildNavIcon(Icons.people, 1),
                            label: 'Nearby',
                          ),
                          BottomNavigationBarItem(
                            icon: _buildNavIcon(Icons.music_note_outlined, 2),
                            activeIcon: _buildNavIcon(Icons.music_note, 2),
                            label: 'Music',
                          ),
                          BottomNavigationBarItem(
                            icon: _buildNavIcon(Icons.settings_outlined, 3),
                            activeIcon: _buildNavIcon(Icons.settings, 3),
                            label: 'Settings',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color.fromRGBO(32, 211, 102, 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon),
    );
  }
}