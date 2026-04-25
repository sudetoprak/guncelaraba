import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/cart_screen.dart';
import 'screens/main/checkout_screen.dart';
import 'screens/main/profile_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const SmartCarApp(),
    ),
  );
}

class SmartCarApp extends StatelessWidget {
  const SmartCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartCar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E3A8A),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const _RootWidget(),
    );
  }
}

class _RootWidget extends StatelessWidget {
  const _RootWidget();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
        ),
      );
    }

    return auth.isAuthenticated ? const _MainTabs() : const _AuthFlow();
  }
}

// ─── Auth Flow ────────────────────────────────────────────────────────────────

class _AuthFlow extends StatefulWidget {
  const _AuthFlow();

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterScreen(onGoLogin: () => setState(() => _showRegister = false));
    }
    return LoginScreen(onGoRegister: () => setState(() => _showRegister = true));
  }
}

// ─── Main Tabs ────────────────────────────────────────────────────────────────

class _MainTabs extends StatefulWidget {
  const _MainTabs();

  @override
  State<_MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<_MainTabs> {
  int _tabIndex = 0;
  Key _cartKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          const HomeScreen(),
          _CartFlow(key: _cartKey),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() {
            if (i == 1) _cartKey = UniqueKey();
            _tabIndex = i;
          }),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E3A8A),
          unselectedItemColor: const Color(0xFFCBD5E1),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Sepet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cart Flow ────────────────────────────────────────────────────────────────

class _CartFlow extends StatefulWidget {
  const _CartFlow({super.key});

  @override
  State<_CartFlow> createState() => _CartFlowState();
}

class _CartFlowState extends State<_CartFlow> {
  bool _checkout = false;

  @override
  Widget build(BuildContext context) {
    if (_checkout) {
      return CheckoutScreen(
        onBack: () => setState(() => _checkout = false),
        onSuccess: () => setState(() => _checkout = false),
      );
    }
    return CartScreen(onCheckout: () => setState(() => _checkout = true));
  }
}