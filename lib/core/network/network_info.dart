import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Future<List<ConnectivityResult>> get connectivityResult;
  Stream<List<ConnectivityResult>> get connectivityStream;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;
  final InternetConnectionChecker internetConnectionChecker;

  NetworkInfoImpl({
    required this.connectivity,
    required this.internetConnectionChecker,
  });

  @override
  Future<bool> get isConnected => internetConnectionChecker.hasConnection;

  @override
  Future<List<ConnectivityResult>> get connectivityResult => 
      connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get connectivityStream => 
      connectivity.onConnectivityChanged;
}
