import 'package:flutter/material.dart';

import '../widgets/banner_ad_widget.dart';
import 'notes_home_screen.dart';
import 'tasks_home_screen.dart';

/// Notes এবং Tasks — দুই মূল সেকশনের মধ্যে সুইচ করার জন্য শেল স্ক্রিন।
/// IndexedStack ব্যবহার করা হয়েছে যাতে ট্যাব পরিবর্তনে state (স্ক্রল পজিশন,
/// সার্চ ইত্যাদি) হারিয়ে না যায়।
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    NotesHomeScreen(),
    TasksHomeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: _index, children: _screens)),
          // Notes ↔ Tasks যেকোনো ট্যাবেই সবসময় দৃশ্যমান — নোট এডিটর/ড্রয়িং
          // স্ক্রিনে এই BannerAdWidget নেই, তাই সেখানে দেখাবে না।
          const BannerAdWidget(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}
