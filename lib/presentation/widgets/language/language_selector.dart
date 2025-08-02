import 'package:flutter/material.dart';
import '../../../core/services/language_service.dart';
import '../../../l10n/app_localizations.dart';

class LanguageSelector extends StatefulWidget {
  final Function(Locale) onLanguageChanged;
  
  const LanguageSelector({
    super.key,
    required this.onLanguageChanged,
  });

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  String _selectedLanguage = LanguageService.currentLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.language,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                RadioListTile<String>(
                  title: Text(l10n.english),
                  value: 'en',
                  groupValue: _selectedLanguage,
                  onChanged: (value) => _changeLanguage(value!),
                ),
                RadioListTile<String>(
                  title: Text(l10n.tamil),
                  value: 'ta',
                  groupValue: _selectedLanguage,
                  onChanged: (value) => _changeLanguage(value!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeLanguage(String languageCode) async {
    setState(() {
      _selectedLanguage = languageCode;
    });
    
    await LanguageService.setLanguage(languageCode);
    widget.onLanguageChanged(Locale(languageCode, ''));
    
    // Show confirmation
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.language}: ${LanguageService.getLanguageName(languageCode)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
