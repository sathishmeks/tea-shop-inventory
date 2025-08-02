import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  static final _client = Supabase.instance.client;

  /// Test database connection and common operations
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      // Test 1: Check if we can connect to Supabase
      final user = _client.auth.currentUser;
      
      if (user == null) {
        return {
          'status': 'error',
          'error': 'No authenticated user',
          'message': 'Please log in first'
        };
      }

      final Map<String, String> testResults = {};
      
      // Test 2: Try to query users table (this is where the RLS error occurs)
      try {
        await _client
            .from('users')
            .select('id, email, name, role')
            .eq('id', user.id)
            .maybeSingle();
        testResults['users_table'] = 'OK';
      } catch (e) {
        testResults['users_table'] = 'FAILED: ${e.toString()}';
        if (e.toString().contains('infinite recursion detected in policy')) {
          return {
            'status': 'error',
            'error': 'PostgreSQL RLS Policy Error',
            'details': 'Infinite recursion detected in users table policy',
            'solution': 'Database RLS policies need to be fixed. Run the fix_database_rls.sql script in Supabase SQL Editor.',
            'message': 'Failed to diagnose database: ${e.toString()}'
          };
        }
      }
      
      // Test 3: Try to query products table
      try {
        await _client
            .from('products')
            .select('count')
            .limit(1);
        testResults['products_table'] = 'OK';
      } catch (e) {
        testResults['products_table'] = 'FAILED: ${e.toString()}';
      }
      
      // Test 4: Try to query sales table
      try {
        await _client
            .from('sales')
            .select('count')
            .limit(1);
        testResults['sales_table'] = 'OK';
      } catch (e) {
        testResults['sales_table'] = 'FAILED: ${e.toString()}';
      }
      
      // Test 5: Try to query shifts table
      try {
        await _client
            .from('shifts')
            .select('count')
            .limit(1);
        testResults['shifts_table'] = 'OK';
      } catch (e) {
        testResults['shifts_table'] = 'FAILED: ${e.toString()}';
      }

      // Check if any tests failed
      final failedTests = testResults.entries.where((e) => e.value.startsWith('FAILED')).toList();
      
      if (failedTests.isNotEmpty) {
        return {
          'status': 'error',
          'user': user.id,
          'email': user.email ?? 'No email',
          'tests': testResults,
          'failed_tests': failedTests.map((e) => e.key).toList(),
          'message': 'Some database tests failed'
        };
      }

      return {
        'status': 'success',
        'user': user.id,
        'email': user.email ?? 'No email',
        'tests': testResults,
        'message': 'All database connections successful'
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'message': 'Database connection failed'
      };
    }
  }

  /// Safe database operation with error handling
  static Future<T?> safeOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    try {
      return await operation();
    } catch (e) {
      print('Database Error${operationName != null ? ' ($operationName)' : ''}: $e');
      
      // Common PostgreSQL error handling
      if (e.toString().contains('column') && e.toString().contains('does not exist')) {
        print('Column does not exist error - check database schema');
      } else if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        print('Table does not exist error - run database migrations');
      } else if (e.toString().contains('permission denied')) {
        print('Permission denied error - check RLS policies');
      } else if (e.toString().contains('duplicate key')) {
        print('Duplicate key error - item already exists');
      } else if (e.toString().contains('foreign key')) {
        print('Foreign key constraint error - referenced item does not exist');
      }
      
      return null;
    }
  }

  /// Check and fix common database issues
  static Future<Map<String, dynamic>> diagnoseAndFix() async {
    final issues = <String>[];
    final fixes = <String>[];

    try {
      // Check if user profile exists
      final user = _client.auth.currentUser;
      if (user != null) {
        final userProfile = await _client
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (userProfile == null) {
          issues.add('User profile missing');
          // Try to create user profile
          try {
            await _client.from('users').insert({
              'id': user.id,
              'email': user.email,
              'name': user.email?.split('@')[0] ?? 'User',
              'role': 'admin',
            });
            fixes.add('Created missing user profile');
          } catch (e) {
            issues.add('Failed to create user profile: $e');
          }
        }
      }

      // Check if tables exist by trying to query them
      final tables = ['products', 'sales', 'sale_items', 'shifts', 'inventory_movements'];
      for (final table in tables) {
        try {
          await _client.from(table).select('count').limit(1);
        } catch (e) {
          if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
            issues.add('Table $table does not exist');
          }
        }
      }

      return {
        'issues': issues,
        'fixes': fixes,
        'status': issues.isEmpty ? 'healthy' : 'issues_found'
      };

    } catch (e) {
      return {
        'issues': ['Failed to diagnose database: $e'],
        'fixes': [],
        'status': 'error'
      };
    }
  }
}
