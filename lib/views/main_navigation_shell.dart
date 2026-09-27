import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home/home_screen.dart';
import 'image_to_pdf/image_to_pdf_screen.dart';
import 'pdf_editor/pdf_editor_screen.dart';
import 'pdf_organizer/pdf_organizer_screen.dart';
import 'security/pdf_security_screen.dart';
import 'universal_studio/universal_studio_router.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialIntent());
  }

  Future<void> _checkInitialIntent() async {
    try {
      const channel = MethodChannel('com.zenpdf.app/intents');
      final String? initialPath = await channel.invokeMethod<String>('getInitialPdfPath');
      if (initialPath != null && initialPath.isNotEmpty && mounted) {
        await UniversalStudioRouter.openFileInStudio(
          context,
          initialPath,
          isExternalIntent: true,
        );
      }
    } catch (_) {}
  }

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onNavigateTab: _onTabSelected),
      const ImageToPdfScreen(),
      const PdfEditorScreen(),
      const PdfOrganizerScreen(),
      const PdfSecurityScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        if (isDesktop) {
          // Desktop / PC Sidebar layout
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onTabSelected,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ZenPDF',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.photo_library_outlined),
                      selectedIcon: Icon(Icons.photo_library),
                      label: Text('Images to PDF'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.edit_document),
                      selectedIcon: Icon(Icons.edit),
                      label: Text('Edit & Sign'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.merge_type),
                      selectedIcon: Icon(Icons.merge_type),
                      label: Text('Manage Pages'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.lock_outline),
                      selectedIcon: Icon(Icons.lock),
                      label: Text('Lock & Protect'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: screens[_selectedIndex],
                ),
              ],
            ),
          );
        } else {
          // Mobile layout with BottomNavigationBar
          return Scaffold(
            body: screens[_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onTabSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Images',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_outlined),
                  selectedIcon: Icon(Icons.edit),
                  label: 'Edit',
                ),
                NavigationDestination(
                  icon: Icon(Icons.merge_type),
                  selectedIcon: Icon(Icons.merge_type),
                  label: 'Pages',
                ),
                NavigationDestination(
                  icon: Icon(Icons.lock_outline),
                  selectedIcon: Icon(Icons.lock),
                  label: 'Protect',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
