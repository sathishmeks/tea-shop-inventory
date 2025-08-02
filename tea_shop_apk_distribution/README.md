# Tea Shop Inventory & Sales Management App

A Flutter-based cross-platform mobile application for tea shop inventory and sales management with offline support and cloud synchronization.

## Features

### 🔐 Authentication & User Management
- Admin/Staff login with role-based access control
- Supabase authentication integration
- Secure user session management

### 📦 Inventory Management
- Product catalog with categories
- Stock level tracking with low-stock alerts
- Real-time inventory updates
- Product images and barcode support
- Batch operations for stock management

### 💰 Sales & POS System
- Quick point-of-sale interface
- Multiple payment methods (cash, card, UPI)
- Customer information management
- Sale receipt generation
- Real-time sales tracking

### ⏰ Shift Management
- Employee shift tracking
- Cash register management
- Shift reports and summaries
- Time tracking for staff

### 📊 Reports & Analytics
- Daily, weekly, monthly sales reports
- Inventory reports with stock levels
- Staff performance analytics
- Export to PDF and CSV formats
- Visual charts and graphs

### 🔄 Offline Support & Sync
- Offline-first architecture using Hive local database
- Automatic cloud sync when online
- Conflict resolution for data synchronization
- Works completely offline when needed

## Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile development
- **Dart** - Programming language
- **Material Design 3** - UI/UX components

### Backend & Database
- **Supabase** - Backend-as-a-Service (PostgreSQL database)
- **Hive** - Local NoSQL database for offline storage

### State Management
- **BLoC Pattern** - Predictable state management
- **flutter_bloc** - State management library

### Key Dependencies
- `supabase_flutter` - Supabase integration
- `hive_flutter` - Local database
- `flutter_bloc` - State management
- `connectivity_plus` - Network connectivity
- `pdf` - PDF report generation
- `csv` - CSV export functionality

## Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio / VS Code
- Supabase account (free tier available)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/tea-shop-inventory.git
   cd tea-shop-inventory
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Supabase**
   - Create a new project at [supabase.com](https://supabase.com)
   - Copy your project URL and anon key
   - Update `lib/core/constants/app_constants.dart`:
     ```dart
     static const String supabaseUrl = 'YOUR_SUPABASE_URL';
     static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
     ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Database Setup

The app uses Supabase PostgreSQL for cloud storage. Required tables:

- `users` - User authentication and profiles
- `categories` - Product categories
- `products` - Product inventory
- `sales` - Sales transactions
- `shifts` - Employee shift tracking

SQL scripts for table creation will be provided in the `database/` folder.

## Demo Credentials

For testing purposes:
- **Admin**: admin@teashop.com / admin123
- **Staff**: staff@teashop.com / staff123

## Features Roadmap

- [x] User authentication
- [x] Basic app structure
- [ ] Inventory management
- [ ] Sales POS system
- [ ] Shift management
- [ ] Report generation
- [ ] Data synchronization
- [ ] Advanced analytics

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
