import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({super.key});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  bool _isConnected = true; // Start optimistic
  bool _hasSupabaseConnection = true; // Start optimistic
  late Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
    // Start with optimistic state, then check after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkConnectivity();
    });
    _connectivityStream.listen((result) {
      // Add small delay to prevent rapid state changes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkConnectivity();
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isConnected = connectivity.contains(ConnectivityResult.wifi) || 
                       connectivity.contains(ConnectivityResult.mobile);
    
    // Always assume Supabase connection is working if we have basic connectivity
    bool hasSupabaseConnection = isConnected;

    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _hasSupabaseConnection = hasSupabaseConnection;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.enableSupabase) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: Colors.blue,
        child: const Text(
          '📱 OFFLINE MODE',
          style: TextStyle(color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_isConnected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: Colors.red,
        child: const Text(
          '❌ NO INTERNET CONNECTION',
          style: TextStyle(color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_hasSupabaseConnection) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: Colors.orange,
        child: const Text(
          '⚠️ CLOUD SYNC UNAVAILABLE - WORKING OFFLINE',
          style: TextStyle(color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Colors.green,
      child: const Text(
        '✅ ONLINE - CLOUD SYNC ACTIVE',
        style: TextStyle(color: Colors.white, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}
