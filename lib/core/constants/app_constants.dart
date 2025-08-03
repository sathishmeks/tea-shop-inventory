class AppConstants {
  // App Information
  static const String appName = 'Tea Shop Inventory';
  static const String appVersion = '1.0.0';
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://yrcrgftltpwufqxuzurj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlyY3JnZnRsdHB3dWZxeHV6dXJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQxMTE2OTcsImV4cCI6MjA2OTY4NzY5N30.KOwTOTT42iBf4kKITeWZY8EurtK0rnLTpR6uHqMUmDc';
  
  // Enable Supabase
  static const bool enableSupabase = true;
  
  // Database Configuration
  static const String hiveBoxName = 'tea_shop_box';
  
  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleStaff = 'staff';
  
  // Hive Type IDs (for model registration)
  static const int userTypeId = 0;
  static const int productTypeId = 1;
  static const int saleTypeId = 2;
  static const int inventoryTypeId = 3;
  static const int categoryTypeId = 5;
  static const int walletBalanceTypeId = 6;
  
  // API Endpoints
  static const String usersTable = 'users';
  static const String productsTable = 'products';
  static const String salesTable = 'sales';
  static const String saleItemsTable = 'sale_items';
  static const String inventoryTable = 'inventory';
  static const String categoriesTable = 'categories';
  static const String reportsTable = 'reports';
  static const String walletBalanceTable = 'wallet_balances';
  static const String inventoryMovementsTable = 'inventory_movements';
  static const String salesHistoryTable = 'sales_history';
  static const String stockSnapshotsTable = 'stock_snapshots';
  static const String stockSnapshotItemsTable = 'stock_snapshot_items';
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Report Formats
  static const String pdfFormat = 'PDF';
  static const String csvFormat = 'CSV';
  
  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayDateTimeFormat = 'MMM dd, yyyy hh:mm a';
  
  // Stock Levels
  static const int lowStockThreshold = 10;
  static const int criticalStockThreshold = 5;
}
