PURCHASE ENTRY SYSTEM - IMPLEMENTATION GUIDE
===========================================

FILES CREATED/MODIFIED:
======================

1. models/purchase_entry_model.dart (NEW)
   - PurchaseEntry class with all required fields
   - toMap() and fromMap() methods for Firebase
   - copyWith() for updates

2. providers/purchase_entry_provider.dart (NEW)
   - addLocalEntry() - Add entry to local list
   - removeLocalEntry() - Remove entry from list
   - updateLocalEntry() - Update entry in list
   - clearEntries() - Clear all entries
   - saveAllEntries() - Save all entries to Firebase
   - fetchEntriesByCustomer() - Fetch entries by customer from Firebase
   - Calculate total amounts (total, VAT, etc.)

3. purchaseEntryScreen.dart (NEW)
   - Complete Purchase Entry screen with:
     ✓ Customer selection dropdown
     ✓ Search functionality for customers
     ✓ Entry form (Item Name, Quantity, Price, VAT Rate)
     ✓ Add Entry button to add to local list
     ✓ Table display of all entries with columns:
       - Item Name
       - Quantity
       - Price per Unit
       - Total Amount
       - Delete action
     ✓ Summary section showing:
       - Subtotal (Ex. VAT)
       - Total VAT
       - Total (Inc. VAT)
     ✓ Save All Entries button to save to Firebase
     ✓ Reset form after successful save

4. main.dart (MODIFIED)
   - Added import for PurchaseEntryProvider
   - Added PurchaseEntryProvider to MultiProvider

5. navBarScreen.dart (MODIFIED)
   - Added import for PurchaseEntryScreen
   - Replaced "Entries Screen" with PurchaseEntryScreen
   - PurchaseEntryScreen accessible via "Entries" tab (index 2)

FIREBASE STRUCTURE:
==================
Collection: purchaseEntries
Documents contain:
{
  id: String (timestamp-based),
  customerId: String (reference to customer),
  itemName: String,
  quantity: Int,
  price: Double,
  vatRate: Double,
  vatAmount: Double,
  totalAmount: Double,
  createdAt: DateTime
}

WORKFLOW:
=========
1. User opens "Entries" tab
2. Selects or searches for a customer
3. Enters item details (name, quantity, price, VAT rate)
4. Clicks "Add Entry to List"
5. Entry appears in the table below
6. Can add multiple entries
7. Views summary of all amounts
8. Can remove entries before saving
9. Clicks "Save All Entries" to save to Firebase
10. Data is saved and form resets

KEY FEATURES:
=============
✓ Timestamp-based document IDs for uniqueness
✓ Customer reference in each entry
✓ Automatic VAT calculation
✓ Local list management before saving
✓ Table view with responsive columns
✓ Edit/Delete capabilities
✓ Summary totals
✓ Error handling and user feedback
✓ Loading states during save
