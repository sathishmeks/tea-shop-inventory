import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import '../../../core/themes/app_theme.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  Map<String, dynamic>? _testResults;
  Map<String, dynamic>? _diagnosticResults;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() => _isLoading = true);

    try {
      final testResults = await DatabaseService.testConnection();
      final diagnosticResults = await DatabaseService.diagnoseAndFix();

      setState(() {
        _testResults = testResults;
        _diagnosticResults = diagnosticResults;
      });
    } catch (e) {
      setState(() {
        _testResults = {
          'status': 'error',
          'error': e.toString(),
        };
      });
    }

    setState(() => _isLoading = false);
  }

  void _showSQLFix() {
    const sqlFix = '''
-- Fix for PostgreSQL infinite recursion error in RLS policies
-- Run this in your Supabase SQL Editor to fix the users table RLS issue

-- First, drop the existing problematic policies
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;

-- Create a single, non-recursive policy for users table
CREATE POLICY "Users can access user data" ON public.users
  FOR ALL USING (
    -- Users can access their own data
    auth.uid() = id
    OR
    -- Or if they are an admin (check directly against auth.users table to avoid recursion)
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid() 
      AND au.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Ensure the users table has proper default values and constraints
ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'staff';
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SQL Fix for Database RLS Error'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy and run this SQL script in your Supabase SQL Editor:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    sqlFix,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Database Test'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runTests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection Test Results
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _testResults?['status'] == 'success'
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _testResults?['status'] == 'success'
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Connection Test',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_testResults != null) ...[
                            Text('Status: ${_testResults!['status']}'),
                            if (_testResults!['user'] != null)
                              Text('User ID: ${_testResults!['user']}'),
                            if (_testResults!['email'] != null)
                              Text('Email: ${_testResults!['email']}'),
                            if (_testResults!['error'] != null) ...[
                              Text(
                                'Error: ${_testResults!['error']}',
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                              if (_testResults!['details'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Details: ${_testResults!['details']}',
                                  style: TextStyle(color: AppTheme.errorColor),
                                ),
                              ],
                              if (_testResults!['solution'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.warningColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.lightbulb, color: AppTheme.warningColor, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Solution:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.warningColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _testResults!['solution'],
                                        style: TextStyle(color: AppTheme.warningColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                            if (_testResults!['tests'] != null) ...[
                              const SizedBox(height: 8),
                              const Text('Table Tests:'),
                              ...(_testResults!['tests'] as Map<String, dynamic>)
                                  .entries
                                  .map((entry) => Text('  ${entry.key}: ${entry.value}')),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Diagnostic Results
                  if (_diagnosticResults != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _diagnosticResults!['status'] == 'healthy'
                                      ? Icons.health_and_safety
                                      : Icons.warning,
                                  color: _diagnosticResults!['status'] == 'healthy'
                                      ? AppTheme.successColor
                                      : AppTheme.warningColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Database Diagnostic',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('Status: ${_diagnosticResults!['status']}'),
                            
                            if (_diagnosticResults!['issues'] != null && 
                                (_diagnosticResults!['issues'] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Issues Found:'),
                              ...(_diagnosticResults!['issues'] as List<String>)
                                  .map((issue) => Text(
                                        '  • $issue',
                                        style: TextStyle(color: AppTheme.errorColor),
                                      )),
                            ],
                            
                            if (_diagnosticResults!['fixes'] != null && 
                                (_diagnosticResults!['fixes'] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Fixes Applied:'),
                              ...(_diagnosticResults!['fixes'] as List<String>)
                                  .map((fix) => Text(
                                        '  • $fix',
                                        style: TextStyle(color: AppTheme.successColor),
                                      )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _runTests,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Run Tests Again'),
                        ),
                      ),
                      if (_testResults?['status'] == 'error' && 
                          _testResults?['error']?.toString().contains('infinite recursion') == true) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _showSQLFix,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.warningColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('View SQL Fix'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back to App'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
