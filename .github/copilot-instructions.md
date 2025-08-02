# Copilot Instructions for Tea Shop Inventory App

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## Project Overview
This is a Flutter-based tea shop inventory and sales management application with the following tech stack:

- **Frontend**: Flutter (Cross-platform mobile app)
- **Backend**: Supabase (PostgreSQL database, authentication, real-time subscriptions)
- **Local Database**: Hive (for offline support)
- **State Management**: BLoC pattern
- **Reports**: PDF and CSV generation

## Key Features
- Admin/Staff authentication and role-based access
- Inventory management (add, edit, delete items)
- Sales tracking and logging
- Shift management for employees
- Dashboard with analytics
- PDF/CSV report generation
- Offline-first architecture with cloud sync
- Multi-user support

## Architecture Guidelines
1. **BLoC Pattern**: Use flutter_bloc for state management
2. **Repository Pattern**: Separate data layer with repositories that handle both local (Hive) and remote (Supabase) data
3. **Offline-First**: All data should be stored locally first, then synced to cloud when online
4. **Error Handling**: Proper error handling for network failures and offline scenarios
5. **Clean Architecture**: Separate presentation, domain, and data layers

## Code Style
- Use proper null safety
- Follow Flutter/Dart naming conventions
- Add meaningful comments for complex business logic
- Use dependency injection for repositories and services
- Implement proper error states in UI

## Key Dependencies
- supabase_flutter: For backend services
- hive/hive_flutter: For local database
- flutter_bloc: For state management
- connectivity_plus: For network status
- pdf: For report generation
- form_field_validator: For form validation
