import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/screens/cards_screen.dart';
import 'package:ogrenme_asistani/screens/chat_welcome_screen.dart';
import 'package:ogrenme_asistani/screens/curriculum_screen.dart';
import 'package:ogrenme_asistani/screens/home_screen.dart';
import 'package:ogrenme_asistani/screens/profile_screen.dart';

/// The app shell. The app is focused on YKS: Ana Sayfa, Müfredat (TYT / AYT /
/// YDT dersleri), Sohbet, Setlerim and Profil.
///
/// The generic "Dersler" (user-defined subjects) and Keşfet (sample lessons)
/// screens still exist in the code but are no longer reachable from the UI;
/// they come back when the app is widened beyond YKS.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(onSelectTab: _selectTab),
    const CurriculumScreen(),
    const ChatWelcomeScreen(),
    const CardsScreen(),
    const ProfileScreen(),
  ];

  void _selectTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Müfredat',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Sohbet',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Setlerim',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
