import 'package:bookself_/pages/collection_page.dart';
import 'package:bookself_/pages/home_page.dart';
import 'package:bookself_/pages/profile_page.dart';
import 'package:bookself_/pages/search_page.dart';
import 'package:flutter/material.dart';

const _blue = Color(0xFF2563EB);

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  String? _searchQuery;
  int _searchQueryVersion = 0;

  void _openSearch(String query) {
    setState(() {
      _idx = 1;
      _searchQuery = query;
      _searchQueryVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: [
          HomePage(onCategorySelected: _openSearch),
          SearchPage(
            initialQuery: _searchQuery,
            queryVersion: _searchQueryVersion,
          ),
          const CollectionPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E1B4B).withOpacity(.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _navItem(1, Icons.search_rounded, Icons.search_rounded, 'Cari'),
                _navItem(
                  2,
                  Icons.auto_stories,
                  Icons.auto_stories_outlined,
                  'Koleksi',
                ),
                _navItem(
                  3,
                  Icons.person_rounded,
                  Icons.person_outline_rounded,
                  'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int idx,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final active = _idx == idx;
    return GestureDetector(
      onTap: () => setState(() => _idx = idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _blue.withOpacity(.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : inactiveIcon,
              color: active ? _blue : const Color(0xFF9CA3AF),
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? _blue : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
