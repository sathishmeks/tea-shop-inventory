# Enhanced Stock Counting System

## Overview
The stock counting feature now accurately calculates **expected quantities** by considering all inventory movements that occurred since the session started, including:

- ✅ **Sales** - Items sold during the session (reduces expected quantity)
- ✅ **Refunds** - Items returned from cancelled/refunded sales (increases expected quantity)  
- ✅ **Restocks** - New inventory added (increases expected quantity)
- ✅ **Adjustments** - Manual corrections for waste, damage, etc. (increases/decreases as needed)

## How It Works

### 1. Session Start Snapshot
When a sale session begins, the system takes a snapshot of current stock levels for all products.

### 2. Movement Tracking
Throughout the session, all inventory changes are tracked:
```
Expected Quantity = Starting Quantity + Net Movements

Where Net Movements = 
  + Restocks/Refills
  + Refunded items  
  + Positive adjustments
  - Sales
  - Waste/damage
  - Negative adjustments
```

### 3. Session End Counting
When ending the session, users manually count actual stock and enter the real quantities. The system shows:
- **Starting Quantity**: What was in stock when session began
- **Movements**: Net change during session (+/- values)
- **Expected Quantity**: Calculated expected amount
- **Variance Indicators**: Real-time difference between counted vs expected

## User Interface

### Stock Counting Dialog Features
- **Search Functionality**: Quickly find products by name or category
- **Movement Summary**: See starting quantity and all changes
- **Expected vs Actual**: Clear comparison with color-coded indicators
- **Real-time Variance**: Immediate feedback as you type counts

### Visual Indicators
- 🔵 **Blue**: Actual count is higher than expected (extra stock)
- 🟠 **Orange**: Actual count is lower than expected (short stock)
- ✅ **None**: Counts match exactly (accurate)

## Example Scenario

**Product: Premium Tea Leaves**
- **Session Start**: 50 kg
- **During Session**:
  - Sold: 15 kg (sales)
  - Restocked: 20 kg (new delivery)
  - Damaged: 2 kg (adjustment)
- **Expected at End**: 50 + (-15 + 20 - 2) = 53 kg
- **User Counts**: 52 kg
- **Variance**: -1 kg (short by 1 kg)

## Database Integration

### Tables Used
- `stock_snapshots`: Session start/end snapshots
- `stock_snapshot_items`: Individual product quantities
- `sales` & `sale_items`: Track sold items
- `inventory_movements`: Track restocks and adjustments

### Movement Types Tracked
- **Sales**: `sale` (negative movement)
- **Restocks**: `restock` (positive movement)
- **Refunds**: `refunded` status sales (positive movement)
- **Adjustments**: `adjustment_up`/`adjustment_down`
- **Waste/Damage**: `waste`/`damage` (negative movement)

## Benefits

### For Business Operations
1. **Accurate Reconciliation**: True stock position accounting for all changes
2. **Loss Prevention**: Identify theft, waste, or inventory errors
3. **Process Improvement**: Track patterns in stock discrepancies
4. **Compliance**: Maintain accurate records for auditing

### For Staff
1. **Clear Guidance**: Shows exactly what quantities to expect
2. **Real-time Feedback**: Immediate alerts for discrepancies
3. **Easy Workflow**: Search and count with visual indicators
4. **Accountability**: Transparent tracking of all movements

## Testing the Feature

### Test Scenarios
1. **Basic Counting**: Count products with no movements during session
2. **After Sales**: Verify expected quantities decrease correctly
3. **After Restocks**: Verify expected quantities increase correctly
4. **Mixed Movements**: Test combinations of sales, restocks, and adjustments
5. **Discrepancy Handling**: Enter different counts and verify variance calculations

### Expected Behavior
- Expected quantities should accurately reflect all tracked movements
- Variance indicators should show correct differences
- Session end should save actual counted quantities for future reference
- Stock verification should show comprehensive movement history

## Troubleshooting

### Common Issues
1. **Missing Movement Data**: If movements aren't tracked, expected quantities may be incorrect
2. **Table Access**: Ensure all required database tables exist and are accessible
3. **Calculation Errors**: Verify movement types are correctly categorized

### Error Handling
- Falls back to current product quantities if movement calculation fails
- Continues operation even if some tables are missing
- Provides clear error messages for debugging

This enhanced system ensures accurate stock counting that reflects the true business operations during each sales session.
