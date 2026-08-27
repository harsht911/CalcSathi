import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../../calculators/presentation/catalog_screen.dart';
import '../../calculators/presentation/favorites_screen.dart';
import '../../calculators/presentation/history_screen.dart';
import '../../coins/state/coin_state.dart';

/// The signed-in app shell: catalog / favorites / history tabs, plus sign
/// out. Each tab's screen is built once and kept alive in an [IndexedStack]
/// rather than rebuilt per tap, so their `StreamBuilder`s don't re-subscribe
/// to Firestore every time the user switches tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  static const _tabs = [
    _Tab(label: 'Calculators', icon: Icons.calculate_outlined, screen: CatalogScreen()),
    _Tab(label: 'Favorites', icon: Icons.star_outline, screen: FavoritesScreen()),
    _Tab(label: 'History', icon: Icons.history, screen: HistoryScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        // Tab 0 (Calculators) gets the app's own brand name in the title
        // bar; every other tab just shows its own label. Keyed off the
        // index, not the label text, so relabeling a tab can't silently
        // break this.
        title: Text(_tabIndex == 0 ? 'CalcSathi' : _tabs[_tabIndex].label),
        actions: [
          const _CoinBalanceChip(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => authState.repository.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [for (final tab in _tabs) tab.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          for (final tab in _tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.label, required this.icon, required this.screen});

  final String label;
  final IconData icon;
  final Widget screen;
}

/// Live coin balance, shown app-wide in the shell's app bar rather than
/// per-screen — a user should always be able to see it, not just while
/// looking at a gated calculator. Reads [CoinState] rather than opening its
/// own Firestore stream, so it shares the one subscription every other
/// coin-aware widget (e.g. InsufficientCoinsScreen) already uses.
class _CoinBalanceChip extends StatelessWidget {
  const _CoinBalanceChip();

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<CoinState>().balance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        avatar: const Icon(Icons.toll_outlined, size: 18),
        label: Text('$balance'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
