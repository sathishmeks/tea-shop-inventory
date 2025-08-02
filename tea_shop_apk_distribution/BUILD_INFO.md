# Tea Shop Inventory - APK Build Information

## Build Details
- **Build Date**: August 3, 2025
- **Flutter Version**: Latest
- **Build Type**: Release APK
- **App Version**: 1.0.0

## Generated APK Files

### 1. Universal APK (Recommended for Distribution)
- **File**: `app-release.apk`
- **Size**: 25.7 MB
- **Architecture**: Universal (supports all Android devices)
- **Use Case**: General distribution, Play Store upload

### 2. Architecture-Specific APKs (Smaller Sizes)
- **ARM64 (64-bit)**: `app-arm64-v8a-release.apk` - 9.4 MB
  - For modern Android devices (most common)
- **ARM32 (32-bit)**: `app-armeabi-v7a-release.apk` - 9.1 MB  
  - For older Android devices
- **x86_64**: `app-x86_64-release.apk` - 9.6 MB
  - For emulators and x86-based devices

## File Locations
All APK files are located in:
```
build/app/outputs/flutter-apk/
```

## Installation Instructions

### For Most Users (Recommended)
1. Download `app-release.apk` (25.7 MB)
2. Transfer to your Android device
3. Enable "Install from Unknown Sources" in Android Settings
4. Open the APK file to install

### For Optimized Size
1. Check your device architecture:
   - Modern phones (2019+): Use `app-arm64-v8a-release.apk`
   - Older phones: Use `app-armeabi-v7a-release.apk`
   - Emulators: Use `app-x86_64-release.apk`

## Features Included in This Build

### ✅ Core Functionality
- Complete inventory management system
- Sales tracking and management
- User authentication (admin/staff roles)
- Offline support with local storage
- Supabase cloud synchronization

### ✅ Enhanced Sales Features (Latest)
- Edit completed sales
- Cancel sales with audit trail
- Refund processing
- Complete sales history tracking
- Audit compliance features

### ✅ Dashboard & Reporting
- Daily sales summaries
- Inventory status monitoring
- Low stock alerts
- Wallet balance management

### ✅ Database Integration
- Supabase PostgreSQL backend
- Row Level Security (RLS)
- Real-time data synchronization
- Immutable audit trails

## System Requirements
- **Android Version**: 5.0 (API level 21) or higher
- **RAM**: Minimum 2GB recommended
- **Storage**: 50MB available space
- **Internet**: Required for cloud sync (app works offline)

## Security Features
- Encrypted local storage
- Secure authentication
- Role-based access control
- Audit trail for all changes
- Data privacy compliance

## Support Information
- **App Name**: Tea Shop Inventory
- **Package Name**: com.example.tea_shop_inventory
- **Target SDK**: 34 (Android 14)
- **Minimum SDK**: 21 (Android 5.0)

## Installation Notes
1. The app requires internet connection for initial setup
2. Supabase credentials are pre-configured
3. Default login creates staff role (admin upgrade available)
4. All data is stored both locally and in cloud
5. App works offline with automatic sync when online

## Troubleshooting
- If installation fails, ensure "Unknown Sources" is enabled
- For older devices, use the 32-bit ARM APK
- Check available storage space before installation
- Ensure Android version is 5.0 or higher
