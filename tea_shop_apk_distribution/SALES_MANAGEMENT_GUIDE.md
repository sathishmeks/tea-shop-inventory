# Sales Management with Edit Functionality and History Tracking

This implementation adds comprehensive sales management features to the Tea Shop inventory app, including the ability to edit completed sales and track all changes using a detailed audit trail.

## Features Added

### 1. Enhanced Sales Management
- **Edit Sales**: Modify completed sales including customer information, payment method, status, and sale items
- **Cancel Sales**: Cancel completed sales with reason tracking
- **Refund Sales**: Process sale refunds with audit logging
- **Sales History**: View complete audit trail for each sale

### 2. Sales History Tracking
All changes to sales are tracked in the `sales_history` table with the following information:
- **Change Type**: created, updated, cancelled, refunded
- **Field Changes**: Specific fields that were modified
- **Old/New Values**: Before and after values in JSON format
- **Reason**: User-provided reason for the change
- **Metadata**: Additional context (items count, timestamps, etc.)
- **User Tracking**: Who made the change and when

### 3. Database Schema

#### Sales History Table
```sql
create table public.sales_history (
    id uuid not null default gen_random_uuid(),
    sale_id uuid not null,
    change_type text not null,
    field_changed text null,
    old_value jsonb null,
    new_value jsonb null,
    reason text null,
    changed_by text not null,
    changed_at timestamp with time zone null default now(),
    metadata jsonb null,
    constraint sales_history_pkey primary key (id),
    constraint sales_history_sale_id_fkey foreign key (sale_id) references sales (id),
    constraint sales_history_change_type_check check (
        change_type = any (array['created'::text, 'updated'::text, 'cancelled'::text, 'refunded'::text])
    )
);
```

## User Interface Changes

### 1. Sales List Enhancement
- **Tap Action**: Tapping on a sale now opens an actions dialog
- **Actions Available**:
  - View History: See complete audit trail
  - Edit Sale: Modify sale details (for completed sales)
  - Cancel Sale: Cancel the sale with reason
  - Refund Sale: Process refund with reason

### 2. Edit Sale Page
- **Customer Information**: Edit name and phone
- **Payment Method**: Change payment method
- **Status**: Update sale status
- **Sale Items**: Modify quantities (recalculates total)
- **Reason Required**: Must provide reason for all changes
- **History Access**: Quick access to view sale history

### 3. Sales History Page
- **Chronological View**: All changes listed by date
- **Change Details**: Shows what changed and why
- **Visual Indicators**: Color-coded change types
- **Detailed Comparison**: Before/after values for all fields

## Code Structure

### 1. Entities
- `SalesHistory`: Model for audit trail records
- `SalesChangeType`: Enum for change types (created, updated, cancelled, refunded)

### 2. Pages
- `SalesPage`: Enhanced with edit functionality
- `EditSalePage`: Complete sale editing with validation
- `SalesHistoryPage`: Audit trail viewer

### 3. Database Integration
- Automatic history logging on sale creation
- Granular change tracking on edits
- Immutable audit trail (no updates/deletes allowed)

## Security Features

### Row Level Security (RLS)
- Users can only view/edit sales they created or admins can access all
- Sales history is immutable (cannot be updated or deleted)
- Audit trail integrity is maintained

### Audit Compliance
- All changes are logged with timestamp and user
- Reasons are required for modifications
- Original values are preserved
- Complete traceability of all transactions

## Usage Examples

### 1. Editing a Sale
1. Navigate to Sales page
2. Tap on a completed sale
3. Select "Edit Sale"
4. Make changes and provide reason
5. Save changes (history automatically logged)

### 2. Viewing History
1. From sales list: Tap sale → "View History"
2. From edit page: Tap history icon in app bar
3. View chronological list of all changes

### 3. Processing Refunds
1. Tap on completed sale
2. Select "Refund Sale"
3. Provide refund reason
4. Confirm refund (status updated, history logged)

## Benefits

1. **Compliance**: Full audit trail for accounting/legal requirements
2. **Error Correction**: Ability to fix mistakes in sales data
3. **Customer Service**: Handle refunds and cancellations properly
4. **Reporting**: Detailed change tracking for business insights
5. **Security**: Immutable audit trail prevents data tampering

## Migration Notes

To enable these features in an existing installation:

1. Run the `create_sales_history_table.sql` script in Supabase
2. Update app constants to include `salesHistoryTable`
3. Import new entity and page files
4. Update sales page with new UI

The implementation is backward compatible and doesn't affect existing sales data.
