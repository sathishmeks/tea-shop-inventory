# Tea Shop Inventory - Low Stock Notification System

## 🔔 Overview

The Tea Shop Inventory app now includes a comprehensive low stock notification system that automatically monitors your inventory levels and sends mobile notifications when items need restocking.

## ✨ Features

### 📱 Mobile Notifications
- **Low Stock Alerts**: Get notified when items fall below minimum threshold
- **Critical Stock Alerts**: Immediate alerts for out-of-stock items  
- **Summary Notifications**: Consolidated alerts to avoid notification spam
- **Daily Reminders**: Optional daily inventory check reminders (9 AM)

### 🔍 Smart Monitoring
- **Automatic Monitoring**: Checks stock levels every 30 minutes
- **Intelligent Cooldowns**: Prevents notification spam with smart timing
- **Real-time Updates**: Notifications stop automatically after restocking
- **Offline Support**: Works in both online and offline modes

### ⚙️ Customizable Settings
- **Enable/Disable Notifications**: Full control over notification preferences
- **Notification Types**: Choose which types of alerts to receive
- **Test Notifications**: Send test alerts to verify setup
- **Force Stock Check**: Manual inventory checks on-demand

## 🚀 How to Use

### Initial Setup

1. **Enable Notifications**
   - Open the app and navigate to Home → Alerts & Notifications → Settings
   - Toggle "Enable Stock Notifications" 
   - Grant notification permissions when prompted

2. **Configure Alert Types**
   - ✅ **Low Stock Alerts**: For items below minimum threshold
   - ✅ **Critical Stock Alerts**: For out-of-stock items
   - ⏰ **Daily Reminders**: Optional daily check at 9 AM

3. **Test Your Setup**
   - Use "Send Test Notification" to verify notifications work
   - Use "Check Stock Now" to force an immediate inventory check

### Managing Notifications

#### From Settings Page:
- **Settings Button**: Access notification settings from Home → Alerts & Notifications
- **System Settings**: Open Android notification settings for advanced control
- **Clear Notifications**: Remove all pending notifications

#### Automatic Monitoring:
- Stock monitoring starts automatically when notifications are enabled
- Checks inventory every 30 minutes
- Smart cooldown prevents notification spam:
  - Low stock alerts: Every 2 hours max
  - Critical alerts: Every 1 hour max  
  - Summary alerts: Every 6 hours max

## 📊 Notification Types

### 📦 Low Stock Alert
**When**: Item quantity ≤ minimum stock threshold
**Example**: "Earl Grey Tea is running low! Current: 2 kg (Min: 10 kg)"
**Action**: Consider restocking soon

### 🚨 Critical Stock Alert  
**When**: Item quantity = 0 (out of stock)
**Example**: "Critical: Green Tea is completely out of stock! Immediate restocking required."
**Action**: Restock immediately

### 📊 Summary Alert
**When**: Multiple items need attention
**Example**: "Stock Alert Summary: 3 items out of stock, 5 items low on stock"
**Action**: Review inventory dashboard

### ⏰ Daily Reminder
**When**: Every day at 9:00 AM (if enabled)
**Example**: "Daily Stock Check: Time for your daily inventory review"
**Action**: Review stock levels and plan restocking

## 🔧 Technical Details

### System Requirements
- **Android Version**: 6.0+ (API level 23+)
- **Permissions**: Notification access, Vibration, Wake lock
- **Internet**: Optional (works offline with local data)

### Monitoring Logic
```
Stock Level Classification:
- Out of Stock: quantity = 0
- Critical Stock: quantity ≤ 5 (App constant)
- Low Stock: quantity ≤ minimum_stock setting
- In Stock: quantity > minimum_stock setting
```

### Notification Channels
- **Stock Alerts**: Standard low stock notifications
- **Critical Stock**: High-priority out-of-stock alerts
- **Reminders**: Daily check reminders (silent)

## 🛠️ Troubleshooting

### Notifications Not Working?

1. **Check Permissions**
   - Settings → Apps → Tea Shop Inventory → Notifications → Allow all

2. **Battery Optimization**
   - Some phones aggressively close background apps
   - Add Tea Shop Inventory to battery optimization whitelist

3. **Do Not Disturb**
   - Check if Do Not Disturb mode is blocking notifications
   - Critical alerts should still come through

4. **Test Connection**
   - Use "Send Test Notification" in settings
   - If test works but auto-alerts don't, check monitoring status

### Common Issues

**Q: Why am I getting too many notifications?**
A: The system has built-in cooldowns. If you're still getting too many, you can disable specific alert types in settings.

**Q: Notifications stopped after restocking**
A: This is normal! The system automatically stops alerting once stock levels are adequate.

**Q: No notifications for new low stock items**
A: Check that "Low Stock Alerts" is enabled and the item's minimum stock is set properly.

**Q: Daily reminders not working**
A: Ensure "Daily Stock Reminders" is enabled and your phone allows scheduled notifications.

## 📱 Best Practices

### For Shop Owners:
1. **Set Realistic Minimums**: Configure minimum stock levels based on your sales patterns
2. **Check Settings Weekly**: Review notification preferences as your needs change
3. **Use Summary View**: Enable summary notifications to get overview without spam
4. **Monitor Trends**: Use the notification patterns to identify fast-moving items

### For Staff:
1. **Enable Critical Only**: Staff might want only critical out-of-stock alerts
2. **Quick Response**: Set up notifications to address stock-outs immediately
3. **Regular Checks**: Use daily reminders to maintain good inventory habits

## 🔄 Integration with Inventory Management

### Automatic Updates
- **After Restocking**: Notifications automatically stop when you add stock
- **After Sales**: System monitors real-time stock changes
- **After Adjustments**: Manual adjustments trigger immediate re-evaluation

### Dashboard Integration
- **Home Screen Alerts**: Quick access to notification settings
- **Inventory Status**: Visual indicators for low/out-of-stock items
- **Quick Actions**: Direct links to restock pages from notifications

## 🎯 Getting the Most Value

1. **Configure Minimum Stock Levels Properly**
   - Set based on lead time and sales velocity
   - Review and adjust monthly based on usage patterns

2. **Use the Right Notification Mix**
   - Enable all types initially, then customize based on your workflow
   - Consider staff roles when setting up multiple devices

3. **Act on Alerts Promptly**
   - Critical alerts need immediate action
   - Low stock alerts are planning tools - use them proactively

4. **Regular Review**
   - Check notification effectiveness monthly
   - Adjust minimum stock levels as business grows

---

## 📞 Support

If you need help with the notification system:
1. Use "Send Test Notification" to verify basic functionality
2. Check the troubleshooting section above
3. Review your Android notification settings
4. Ensure the app has all required permissions

The notification system is designed to be helpful, not overwhelming. Customize it to match your workflow and inventory management style!
