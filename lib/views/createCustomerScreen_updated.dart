// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/customer_provider.dart';
// import 'models/customer_model.dart';


// class CreateCustomerScreen extends StatefulWidget {
//   final Customer? customer;

//   const CreateCustomerScreen({super.key, this.customer});

//   @override
//   State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
// }

// class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
//   final _formKey = GlobalKey<FormState>();

//   // Basic Information
//   late TextEditingController _nameController;
//   late TextEditingController _phoneController;
//   late TextEditingController _phone2Controller;
//   late TextEditingController _emailController;
  
//   // Organization Details
//   late TextEditingController _organizationNameController;
//   late TextEditingController _organizationUnitNameController;
//   late TextEditingController _commonNameController;
//   late TextEditingController _businessCategoryController;
  
//   // Address Information
//   late TextEditingController _addressController;
//   late TextEditingController _registeredAddressController;
//   late TextEditingController _buildingNoController;
//   late TextEditingController _streetNameController;
//   late TextEditingController _districtNameController;
//   late TextEditingController _cityNameController;
//   late TextEditingController _zipCodeController;
//   late TextEditingController _additionalNoController;
//   late TextEditingController _unitNoController;
//   late TextEditingController _countryController;
  
//   // Tax and Registration
//   late TextEditingController _taxNumberController;
//   late TextEditingController _crNumberController;
  
//   // Zatca Credentials
//   late TextEditingController _zatcaUsernameController;
//   late TextEditingController _zatcaPasswordController;

//   bool get _isEditing => widget.customer != null;

//   @override
//   void initState() {
//     super.initState();
    
//     // Initialize all controllers
//     _nameController = TextEditingController();
//     _phoneController = TextEditingController();
//     _phone2Controller = TextEditingController();
//     _emailController = TextEditingController();
//     _organizationNameController = TextEditingController();
//     _organizationUnitNameController = TextEditingController();
//     _commonNameController = TextEditingController();
//     _businessCategoryController = TextEditingController();
//     _addressController = TextEditingController();
//     _registeredAddressController = TextEditingController();
//     _buildingNoController = TextEditingController();
//     _streetNameController = TextEditingController();
//     _districtNameController = TextEditingController();
//     _cityNameController = TextEditingController();
//     _zipCodeController = TextEditingController();
//     _additionalNoController = TextEditingController();
//     _unitNoController = TextEditingController();
//     _countryController = TextEditingController();
//     _taxNumberController = TextEditingController();
//     _crNumberController = TextEditingController();
//     _zatcaUsernameController = TextEditingController();
//     _zatcaPasswordController = TextEditingController();
    
//     // Pre-fill form if editing
//     if (_isEditing) {
//       final customer = widget.customer!;
//       _nameController.text = customer.name;
//       _phoneController.text = customer.phone;
//       _phone2Controller.text = customer.phone2 ?? '';
//       _emailController.text = customer.email ?? '';
//       _organizationNameController.text = customer.organizationName ?? '';
//       _organizationUnitNameController.text = customer.organizationUnitName ?? '';
//       _commonNameController.text = customer.commonName ?? '';
//       _businessCategoryController.text = customer.businessCategory ?? '';
//       _addressController.text = customer.address;
//       _registeredAddressController.text = customer.registeredAddress ?? '';
//       _buildingNoController.text = customer.buildingNo ?? '';
//       _streetNameController.text = customer.streetName ?? '';
//       _districtNameController.text = customer.districtName ?? '';
//       _cityNameController.text = customer.cityName ?? '';
//       _zipCodeController.text = customer.zipCode ?? '';
//       _additionalNoController.text = customer.additionalNo ?? '';
//       _unitNoController.text = customer.unitNo ?? '';
//       _countryController.text = customer.country ?? '';
//       _taxNumberController.text = customer.taxNumber;
//       _crNumberController.text = customer.crNumber ?? '';
//       _zatcaUsernameController.text = customer.zatcaUsername ?? '';
//       _zatcaPasswordController.text = customer.zatcaPassword ?? '';
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _phoneController.dispose();
//     _phone2Controller.dispose();
//     _emailController.dispose();
//     _organizationNameController.dispose();
//     _organizationUnitNameController.dispose();
//     _commonNameController.dispose();
//     _businessCategoryController.dispose();
//     _addressController.dispose();
//     _registeredAddressController.dispose();
//     _buildingNoController.dispose();
//     _streetNameController.dispose();
//     _districtNameController.dispose();
//     _cityNameController.dispose();
//     _zipCodeController.dispose();
//     _additionalNoController.dispose();
//     _unitNoController.dispose();
//     _countryController.dispose();
//     _taxNumberController.dispose();
//     _crNumberController.dispose();
//     _zatcaUsernameController.dispose();
//     _zatcaPasswordController.dispose();
//     super.dispose();
//   }

//   void _saveCustomer() async {
//     if (_formKey.currentState!.validate()) {
//       final provider = Provider.of<CustomerProvider>(context, listen: false);

//       bool success;
//       String successMessage;

//       if (_isEditing) {
//         // Update existing customer
//         success = await provider.updateCustomer(
//           id: widget.customer!.id,
//           name: _nameController.text.trim(),
//           phone: _phoneController.text.trim(),
//           phone2: _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim(),
//           email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
//           organizationName: _organizationNameController.text.trim().isEmpty ? null : _organizationNameController.text.trim(),
//           organizationUnitName: _organizationUnitNameController.text.trim().isEmpty ? null : _organizationUnitNameController.text.trim(),
//           commonName: _commonNameController.text.trim().isEmpty ? null : _commonNameController.text.trim(),
//           businessCategory: _businessCategoryController.text.trim().isEmpty ? null : _businessCategoryController.text.trim(),
//           address: _addressController.text.trim(),
//           registeredAddress: _registeredAddressController.text.trim().isEmpty ? null : _registeredAddressController.text.trim(),
//           buildingNo: _buildingNoController.text.trim().isEmpty ? null : _buildingNoController.text.trim(),
//           streetName: _streetNameController.text.trim().isEmpty ? null : _streetNameController.text.trim(),
//           districtName: _districtNameController.text.trim().isEmpty ? null : _districtNameController.text.trim(),
//           cityName: _cityNameController.text.trim().isEmpty ? null : _cityNameController.text.trim(),
//           zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
//           additionalNo: _additionalNoController.text.trim().isEmpty ? null : _additionalNoController.text.trim(),
//           unitNo: _unitNoController.text.trim().isEmpty ? null : _unitNoController.text.trim(),
//           country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
//           taxNumber: _taxNumberController.text.trim(),
//           crNumber: _crNumberController.text.trim().isEmpty ? null : _crNumberController.text.trim(),
//           zatcaUsername: _zatcaUsernameController.text.trim().isEmpty ? null : _zatcaUsernameController.text.trim(),
//           zatcaPassword: _zatcaPasswordController.text.trim().isEmpty ? null : _zatcaPasswordController.text.trim(),
//         );
//         successMessage = 'Customer updated successfully!';
//       } else {
//         // Add new customer
//         success = await provider.addCustomer(
//           name: _nameController.text.trim(),
//           phone: _phoneController.text.trim(),
//           phone2: _phone2Controller.text.trim().isEmpty ? null : _phone2Controller.text.trim(),
//           email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
//           organizationName: _organizationNameController.text.trim().isEmpty ? null : _organizationNameController.text.trim(),
//           organizationUnitName: _organizationUnitNameController.text.trim().isEmpty ? null : _organizationUnitNameController.text.trim(),
//           commonName: _commonNameController.text.trim().isEmpty ? null : _commonNameController.text.trim(),
//           businessCategory: _businessCategoryController.text.trim().isEmpty ? null : _businessCategoryController.text.trim(),
//           address: _addressController.text.trim(),
//           registeredAddress: _registeredAddressController.text.trim().isEmpty ? null : _registeredAddressController.text.trim(),
//           buildingNo: _buildingNoController.text.trim().isEmpty ? null : _buildingNoController.text.trim(),
//           streetName: _streetNameController.text.trim().isEmpty ? null : _streetNameController.text.trim(),
//           districtName: _districtNameController.text.trim().isEmpty ? null : _districtNameController.text.trim(),
//           cityName: _cityNameController.text.trim().isEmpty ? null : _cityNameController.text.trim(),
//           zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
//           additionalNo: _additionalNoController.text.trim().isEmpty ? null : _additionalNoController.text.trim(),
//           unitNo: _unitNoController.text.trim().isEmpty ? null : _unitNoController.text.trim(),
//           country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
//           taxNumber: _taxNumberController.text.trim(),
//           crNumber: _crNumberController.text.trim().isEmpty ? null : _crNumberController.text.trim(),
//           zatcaUsername: _zatcaUsernameController.text.trim().isEmpty ? null : _zatcaUsernameController.text.trim(),
//           zatcaPassword: _zatcaPasswordController.text.trim().isEmpty ? null : _zatcaPasswordController.text.trim(),
//         );
//         successMessage = 'Customer saved successfully!';
//       }

//       if (success) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(successMessage),
//               backgroundColor: Colors.green,
//             ),
//           );
//           Navigator.pop(context);
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(provider.errorMessage ?? 'Failed to save customer'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     IconData? icon,
//     TextInputType keyboardType = TextInputType.text,
//     int maxLines = 1,
//     bool required = false,
//   }) {
//     return Container(
//       height: maxLines > 1 ? 100 : 50,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 2,
//             blurRadius: 5,
//             offset: const Offset(0, 0),
//           ),
//         ],
//       ),
//       child: TextFormField(
//         controller: controller,
//         keyboardType: keyboardType,
//         maxLines: maxLines,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(borderSide: BorderSide.none),
//           prefixIcon: icon != null ? Icon(icon) : null,
//         ),
//         validator: required
//             ? (value) => value == null || value.trim().isEmpty
//                 ? 'Please enter $label'
//                 : null
//             : null,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade50,
//       appBar: AppBar(
//         centerTitle: true,
//         title: Text(
//           _isEditing ? 'Edit Customer' : 'Create New Customer',
//           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//         ),
//         backgroundColor: Colors.white,
//       ),
//       body: Form(
//         key: _formKey,
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // ── Basic Information ──────────────────────────────────────
//                       const Text(
//                         'Basic Information',
//                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _nameController,
//                         label: 'Customer Name',
//                         icon: Icons.person,
//                         required: true,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _phoneController,
//                         label: 'Phone Number 1',
//                         icon: Icons.phone,
//                         keyboardType: TextInputType.phone,
//                         required: true,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _phone2Controller,
//                         label: 'Phone Number 2 (Optional)',
//                         icon: Icons.phone,
//                         keyboardType: TextInputType.phone,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _emailController,
//                         label: 'Email (Optional)',
//                         icon: Icons.email,
//                         keyboardType: TextInputType.emailAddress,
//                       ),
//                       const SizedBox(height: 20),

//                       // ── Organization Details ───────────────────────────────────
//                       const Text(
//                         'Organization Details',
//                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _organizationNameController,
//                         label: 'Organization Name (Optional)',
//                         icon: Icons.business,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _organizationUnitNameController,
//                         label: 'Organization Unit Name (Optional)',
//                         icon: Icons.domain,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _commonNameController,
//                         label: 'Common Name (Optional)',
//                         icon: Icons.label,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _businessCategoryController,
//                         label: 'Business Category (Optional)',
//                         icon: Icons.category,
//                       ),
//                       const SizedBox(height: 20),

//                       // ── Address Information ────────────────────────────────────
//                       const Text(
//                         'Address Information',
//                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _addressController,
//                         label: 'Primary Address',
//                         icon: Icons.location_on,
//                         maxLines: 3,
//                         required: true,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _registeredAddressController,
//                         label: 'Registered Address (Optional)',
//                         icon: Icons.location_on_outlined,
//                         maxLines: 3,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _countryController,
//                         label: 'Country (Optional)',
//                         icon: Icons.public,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _cityNameController,
//                         label: 'City Name (Optional)',
//                         icon: Icons.location_city,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _districtNameController,
//                         label: 'District Name (Optional)',
//                         icon: Icons.map,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _streetNameController,
//                         label: 'Street Name (Optional)',
//                         icon: Icons.streetview,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _buildingNoController,
//                         label: 'Building No (Optional)',
//                         icon: Icons.apartment,
//                         keyboardType: TextInputType.number,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _additionalNoController,
//                         label: 'Additional No (Optional)',
//                         icon: Icons.numbers,
//                         keyboardType: TextInputType.number,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _unitNoController,
//                         label: 'Unit No (Optional)',
//                         icon: Icons.home,
//                         keyboardType: TextInputType.number,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _zipCodeController,
//                         label: 'Zip Code (Optional)',
//                         icon: Icons.mail,
//                       ),
//                       const SizedBox(height: 20),

//                       // ── Tax & Registration ─────────────────────────────────────
//                       const Text(
//                         'Tax & Registration',
//                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _taxNumberController,
//                         label: 'VAT Number',
//                         icon: Icons.credit_card,
//                         required: true,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _crNumberController,
//                         label: 'Commercial Registration (CR) (Optional)',
//                         icon: Icons.assignment,
//                       ),
//                       const SizedBox(height: 20),

//                       // ── Zatca Credentials ──────────────────────────────────────
//                       const Text(
//                         'Zatca Credentials (Optional)',
//                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _zatcaUsernameController,
//                         label: 'Zatca Username (Optional)',
//                         icon: Icons.person_add,
//                       ),
//                       const SizedBox(height: 12),
//                       _buildTextField(
//                         controller: _zatcaPasswordController,
//                         label: 'Zatca Password (Optional)',
//                         icon: Icons.lock,
//                       ),
//                       const SizedBox(height: 20),
//                     ],
//                   ),
//                 ),
//               ),
//               SafeArea(
//                 child: Consumer<CustomerProvider>(
//                   builder: (context, provider, child) {
//                     return SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: InkWell(
//                               onTap: () {
//                                 Navigator.of(context).pop();
//                               },
//                               child: Container(
//                                 height: 50,
//                                 decoration: BoxDecoration(
//                                   border: Border.all(color: Colors.grey.shade300),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: Colors.grey.withOpacity(0.1),
//                                       spreadRadius: 2,
//                                       blurRadius: 5,
//                                       offset: const Offset(0, 0),
//                                     ),
//                                   ],
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: const Center(
//                                   child: Text(
//                                     'Cancel',
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 16),
//                           Expanded(
//                             child: GestureDetector(
//                               onTap: provider.isLoading ? null : _saveCustomer,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(vertical: 14),
//                                 decoration: BoxDecoration(
//                                   color: provider.isLoading ? Colors.teal.shade300 : Colors.teal,
//                                   borderRadius: BorderRadius.circular(8),
//                                   boxShadow: [
//                                     if (!provider.isLoading)
//                                       BoxShadow(
//                                         color: Colors.teal.withOpacity(0.3),
//                                         blurRadius: 8,
//                                         offset: const Offset(0, 3),
//                                       ),
//                                   ],
//                                 ),
//                                 alignment: Alignment.center,
//                                 child: provider.isLoading
//                                     ? const SizedBox(
//                                   height: 22,
//                                   width: 22,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2.5,
//                                     valueColor:
//                                     AlwaysStoppedAnimation<Color>(Colors.white),
//                                   ),
//                                 )
//                                     : Text(
//                                   _isEditing ? 'Update Customer' : 'Save Customer',
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
