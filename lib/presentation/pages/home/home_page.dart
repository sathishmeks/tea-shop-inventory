import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';
import '../inventory/inventory_page.dart';
import '../sales/sales_page.dart';
import '../reports/reports_page.dart';
import '../debug/database_test_page.dart';
import '../debug/network_troubleshooting_page.dart';
import '../../widgets/language/language_selector.dart';
import '../../widgets/network_status_banner.dart';
import '../../../l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    // Initialize pages with navigation callback
    _pages.addAll([
      DashboardTab(onNavigateToTab: navigateToTab),
      const InventoryPage(),
      const SalesPage(),
      const ReportsPage(),
      const SettingsTab(),
    ]);
  }

  // Make this method accessible to child widgets
  void navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          const NetworkStatusBanner(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory),
            label: l10n.inventory,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.point_of_sale),
            label: l10n.sales,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: l10n.reports,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Placeholder tabs - will be implemented in detail later
class DashboardTab extends StatefulWidget {
  final Function(int) onNavigateToTab;
  
  const DashboardTab({super.key, required this.onNavigateToTab});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isLoading = true;
  
  // Dashboard metrics
  double _todaySales = 0.0;
  double _todayProfit = 0.0;
  int _todayTransactions = 0;
  int _totalProducts = 0;
  int _lowStockProducts = 0;
  int _outOfStockProducts = 0;
  List<Map<String, dynamic>> _recentSales = [];
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, dynamic>? _activeSession;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _currentUserId = user.id;
        
        await Future.wait([
          _loadTodaySales(),
          _loadProductStats(),
          _loadRecentSales(),
          _loadTopProducts(),
          _loadActiveSession(),
        ]);
      }
    } catch (e) {
      print('Dashboard error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTodaySales() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      final salesResponse = await Supabase.instance.client
          .from('sales')
          .select('total_amount, discount_amount')
          .gte('sale_date', '${today}T00:00:00')
          .lte('sale_date', '${today}T23:59:59');

      double totalSales = 0.0;
      int transactionCount = 0;
      
      if (salesResponse is List) {
        transactionCount = salesResponse.length;
        for (var sale in salesResponse) {
          totalSales += (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      setState(() {
        _todaySales = totalSales;
        _todayTransactions = transactionCount;
        _todayProfit = totalSales * 0.3; // Assuming 30% profit margin
      });
    } catch (e) {
      print('Error loading today sales: $e');
    }
  }

  Future<void> _loadProductStats() async {
    try {
      final productsResponse = await Supabase.instance.client
          .from('products')
          .select('id, stock_quantity, minimum_stock, is_active')
          .eq('is_active', true);

      if (productsResponse is List) {
        int total = productsResponse.length;
        int lowStock = 0;
        int outOfStock = 0;

        for (var product in productsResponse) {
          int stockQty = product['stock_quantity'] ?? 0;
          int minStock = product['minimum_stock'] ?? 10;
          
          if (stockQty <= 0) {
            outOfStock++;
          } else if (stockQty <= minStock) {
            lowStock++;
          }
        }

        setState(() {
          _totalProducts = total;
          _lowStockProducts = lowStock;
          _outOfStockProducts = outOfStock;
        });
      }
    } catch (e) {
      print('Error loading product stats: $e');
    }
  }

  Future<void> _loadRecentSales() async {
    try {
      final salesResponse = await Supabase.instance.client
          .from('sales')
          .select('id, sale_number, customer_name, total_amount, payment_method, sale_date')
          .order('sale_date', ascending: false)
          .limit(5);

      if (salesResponse is List) {
        setState(() {
          _recentSales = List<Map<String, dynamic>>.from(salesResponse);
        });
      }
    } catch (e) {
      print('Error loading recent sales: $e');
    }
  }

  Future<void> _loadTopProducts() async {
    try {
      // This would require aggregation - for now using mock data
      setState(() {
        _topProducts = [
          {'name': 'Green Tea Premium', 'sales': 45, 'revenue': 2250.0},
          {'name': 'Earl Grey Tea', 'sales': 38, 'revenue': 1900.0},
          {'name': 'Chai Masala', 'sales': 32, 'revenue': 1600.0},
          {'name': 'Oolong Tea', 'sales': 28, 'revenue': 1680.0},
          {'name': 'White Tea', 'sales': 22, 'revenue': 1540.0},
        ];
      });
    } catch (e) {
      print('Error loading top products: $e');
    }
  }

  Future<void> _loadActiveSession() async {
    try {
      if (_currentUserId != null) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        
        final sessionResponse = await Supabase.instance.client
            .from('wallet_balances')
            .select()
            .eq('user_id', _currentUserId!)
            .eq('date', today)
            .eq('status', 'opened')
            .maybeSingle();

        setState(() {
          _activeSession = sessionResponse;
        });
      }
    } catch (e) {
      print('Error loading active session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 20),
            
            // Quick Stats
            _buildQuickStats(),
            const SizedBox(height: 20),
            
            // Active Session Status
            if (_activeSession != null) ...[
              _buildActiveSessionCard(),
              const SizedBox(height: 20),
            ],
            
            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 20),
            
            // Recent Sales & Top Products
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRecentSales()),
                const SizedBox(width: 16),
                Expanded(child: _buildTopProducts()),
              ],
            ),
            const SizedBox(height: 20),
            
            // Alerts & Notifications
            _buildAlertsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.email?.split('@').first ?? 'User';
    final currentHour = DateTime.now().hour;
    String greeting = 'Good Morning';
    
    if (currentHour >= 12 && currentHour < 17) {
      greeting = 'Good Afternoon';
    } else if (currentHour >= 17) {
      greeting = 'Good Evening';
    }

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, $userName!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome to your Tea Shop Dashboard',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateTime.now().toString().substring(0, 10),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today\'s Sales',
            '₹${_todaySales.toStringAsFixed(2)}',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Transactions',
            _todayTransactions.toString(),
            Icons.receipt_long,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Profit',
            '₹${_todayProfit.toStringAsFixed(2)}',
            Icons.attach_money,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Products',
            _totalProducts.toString(),
            Icons.inventory,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    final session = _activeSession!;
    final openingBalance = session['opening_balance'] as double;
    
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.play_circle, color: Colors.green, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Session',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Opening Balance: ₹${openingBalance.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'Started: ${DateTime.parse(session['created_at']).toString().substring(11, 16)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onNavigateToTab(2); // Switch to Sales tab
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('End Session', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'New Sale',
                    Icons.add_shopping_cart,
                    Colors.blue,
                    () => widget.onNavigateToTab(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Add Product',
                    Icons.add_box,
                    Colors.green,
                    () => widget.onNavigateToTab(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'View Reports',
                    Icons.analytics,
                    Colors.orange,
                    () => widget.onNavigateToTab(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Manage Stock',
                    Icons.inventory_2,
                    Colors.purple,
                    () => widget.onNavigateToTab(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSales() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Sales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_recentSales.isEmpty)
              const Text('No recent sales')
            else
              ...(_recentSales.map((sale) => _buildSaleListItem(sale))),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleListItem(Map<String, dynamic> sale) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale['sale_number'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  sale['customer_name'] ?? 'Walk-in Customer',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '₹${(sale['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...(_topProducts.map((product) => _buildProductListItem(product))),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(Map<String, dynamic> product) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.local_cafe, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${product['sales']} sales',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '₹${product['revenue'].toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    final alerts = <Widget>[];
    
    if (_outOfStockProducts > 0) {
      alerts.add(_buildAlertCard(
        'Out of Stock',
        '$_outOfStockProducts products are out of stock',
        Icons.warning,
        Colors.red,
        () => widget.onNavigateToTab(1),
      ));
    }
    
    if (_lowStockProducts > 0) {
      alerts.add(_buildAlertCard(
        'Low Stock',
        '$_lowStockProducts products are running low',
        Icons.info,
        Colors.orange,
        () => widget.onNavigateToTab(1),
      ));
    }
    
    if (_activeSession == null) {
      alerts.add(_buildAlertCard(
        'No Active Session',
        'Start a new wallet balance session to track sales',
        Icons.play_arrow,
        Colors.blue,
        () => widget.onNavigateToTab(2),
      ));
    }

    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alerts & Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...alerts,
      ],
    );
  }

  Widget _buildAlertCard(String title, String message, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(message),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const InventoryPage();
  }
}

class SalesTab extends StatelessWidget {
  const SalesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SalesPage();
  }
}

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Reports', style: TextStyle(fontSize: 24, color: Colors.grey)),
          Text('Analytics and reports coming soon...'),
        ],
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          
          // Language Selector
          LanguageSelector(
            onLanguageChanged: (locale) {
              // Restart the app to apply new locale
              _restartApp();
            },
          ),
          const SizedBox(height: 16),
          
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report),
              title: Text(l10n.databaseTest),
              subtitle: Text(l10n.testDatabaseConnection),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DatabaseTestPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Network Troubleshooting'),
              subtitle: const Text('Fix connection issues and test offline mode'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NetworkTroubleshootingPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.logout),
              subtitle: const Text('Sign out of the application'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                try {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _restartApp() {
    // Show a dialog asking user to restart the app
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Language Changed'),
        content: const Text('Please restart the app to apply the new language.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
