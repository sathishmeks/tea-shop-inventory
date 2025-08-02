import 'package:flutter/material.dart';

class NetworkTroubleshootingPage extends StatelessWidget {
  const NetworkTroubleshootingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Troubleshooting'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔧 Quick Fixes for Network Issues',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('If you see "Failed host lookup" errors:'),
                    const SizedBox(height: 8),
                    _buildTroubleshootingStep('1. Restart Android Emulator',
                        'Close emulator completely and restart it'),
                    _buildTroubleshootingStep('2. Check Emulator Network',
                        'Ensure emulator has internet access'),
                    _buildTroubleshootingStep('3. Try Physical Device',
                        'Test on real Android device if available'),
                    _buildTroubleshootingStep('4. Use Offline Mode',
                        'App works fully offline while network issues persist'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚙️ Current Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildConfigItem('Supabase URL', 'yrcrgftltpwufqxuzurj.supabase.co'),
                    _buildConfigItem('Online Mode', 'Enabled'),
                    _buildConfigItem('App Name', 'Tea Shop Inventory'),
                    _buildConfigItem('Version', '1.0.0'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📱 Offline Mode Features',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Your app works completely offline with:'),
                    const SizedBox(height: 8),
                    _buildFeatureItem('✅ Create sales and transactions'),
                    _buildFeatureItem('✅ Manage inventory and products'),
                    _buildFeatureItem('✅ Track shifts and employee time'),
                    _buildFeatureItem('✅ Generate reports and analytics'),
                    _buildFeatureItem('✅ Auto-sync when connection restored'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to App'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(feature),
    );
  }
}
