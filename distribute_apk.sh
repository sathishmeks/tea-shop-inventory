#!/bin/bash

# Tea Shop Inventory - APK Distribution Script
# This script helps organize and prepare APK files for distribution

echo "🏪 Tea Shop Inventory - APK Builder & Distributor"
echo "================================================"

# Create distribution directory
DIST_DIR="tea_shop_apk_distribution"
mkdir -p "$DIST_DIR"

# Copy APK files
echo "📱 Copying APK files..."
cp build/app/outputs/flutter-apk/app-release.apk "$DIST_DIR/TeaShop-Universal-v1.0.0.apk"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$DIST_DIR/TeaShop-ARM64-v1.0.0.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$DIST_DIR/TeaShop-ARM32-v1.0.0.apk"
cp build/app/outputs/flutter-apk/app-x86_64-release.apk "$DIST_DIR/TeaShop-x86_64-v1.0.0.apk"

# Copy documentation
echo "📄 Copying documentation..."
cp BUILD_INFO.md "$DIST_DIR/"
cp SALES_MANAGEMENT_GUIDE.md "$DIST_DIR/"
cp README.md "$DIST_DIR/" 2>/dev/null || echo "README.md not found, skipping..."

# Create installation instructions
cat > "$DIST_DIR/INSTALLATION_GUIDE.txt" << EOF
Tea Shop Inventory - Installation Guide
======================================

QUICK START:
1. Download TeaShop-Universal-v1.0.0.apk (recommended for most users)
2. Transfer to your Android device
3. Enable "Install from Unknown Sources" in Settings
4. Tap the APK file to install

APK OPTIONS:
- TeaShop-Universal-v1.0.0.apk (25.7MB) - Works on all devices
- TeaShop-ARM64-v1.0.0.apk (9.4MB) - Modern phones (2019+)
- TeaShop-ARM32-v1.0.0.apk (9.1MB) - Older phones
- TeaShop-x86_64-v1.0.0.apk (9.6MB) - Emulators

SYSTEM REQUIREMENTS:
- Android 5.0 or higher
- 2GB RAM (recommended)
- 50MB storage space
- Internet connection for cloud sync

FEATURES:
✅ Complete inventory management
✅ Sales tracking and editing
✅ User management (admin/staff)
✅ Offline support
✅ Cloud synchronization
✅ Audit trail compliance
✅ PDF/CSV reports

For detailed information, see BUILD_INFO.md and SALES_MANAGEMENT_GUIDE.md

EOF

# Show file sizes
echo "📊 APK File Sizes:"
echo "=================="
ls -lah "$DIST_DIR"/*.apk

echo ""
echo "✅ Distribution package ready!"
echo "📁 Location: $(pwd)/$DIST_DIR"
echo ""
echo "🚀 Ready to distribute:"
echo "   - Universal APK for general use"
echo "   - Architecture-specific APKs for optimized size"
echo "   - Complete documentation included"
echo ""
echo "📱 Install on device: Transfer any APK to Android device and install"
echo "☁️  App features: Full inventory management with cloud sync"
