# Stock Counting Feature Test Guide

## Test Scenarios for Manual Stock Counting During Session End

### Prerequisites
- Ensure you have products in your inventory
- Start a sale session with an initial balance
- Make some sales transactions (optional, but recommended)

### Test Steps

#### 1. Basic Stock Counting Flow
1. **Start Session**: Click "Start Sale" and enter a starting balance
2. **Navigate to Sales**: Go to the Sales page
3. **End Session**: Click "End Sale Session" 
4. **Stock Counting Dialog**: 
   - Verify the dialog shows "Stock Count" title with inventory icon
   - Confirm all products are listed with expected quantities
   - Test search functionality by typing product names

#### 2. Manual Count Entry
1. **Enter Counts**: For each product, enter actual counted quantities
2. **Real-time Variance**: Verify difference indicators show:
   - Blue "+X Extra" for counts higher than expected
   - Orange "-X Short" for counts lower than expected
   - No indicator when counts match exactly

#### 3. Validation Tests
1. **Empty Values**: Leave some fields empty - should use expected quantities
2. **Invalid Values**: Try entering negative numbers or non-numeric text
3. **Decimal Values**: Test with decimal quantities (e.g., 2.5 kg)

#### 4. Session End Completion
1. **Confirm Counts**: Click "Confirm Counts" 
2. **Verification**: Check that session ends successfully
3. **Data Persistence**: Verify actual counts are saved correctly

#### 5. Edge Cases
1. **Cancel Operation**: Test clicking "Cancel" - should return to sales without ending session
2. **Large Variance**: Test with significantly different counts
3. **Search Filter**: Test searching while entering counts

### Expected Behavior
- Stock counting is mandatory - cannot end session without providing counts
- Real-time variance calculation shows immediately as you type
- Search filters products but maintains entered values
- Session creates accurate snapshot with actual counts vs expected
- All data is properly saved to both local and cloud storage

### Error Testing
- Try to end session without network - should work with local storage
- Test with very large numbers or special characters
- Verify proper error messages for invalid inputs

## Success Criteria
✅ Stock counting dialog appears during session end
✅ All products are displayed with current expected quantities  
✅ Search functionality works correctly
✅ Real-time variance indicators show accurate differences
✅ Mandatory validation prevents session end without counts
✅ Actual counts are properly saved and used for inventory balance
✅ Session end completes successfully with accurate snapshot
