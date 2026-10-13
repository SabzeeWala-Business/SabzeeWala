import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import '../models/models.dart';

class AddAddressScreen extends StatefulWidget {
  final Address? addressToEdit;
  const AddAddressScreen({super.key, this.addressToEdit});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.addressToEdit != null) {
      _nameController.text = widget.addressToEdit!.fullName;
      _mobileController.text = widget.addressToEdit!.mobile;
      _addressController.text = widget.addressToEdit!.addressLine;
      _landmarkController.text = widget.addressToEdit!.landmark;
      _cityController.text = widget.addressToEdit!.city;
      _pinController.text = widget.addressToEdit!.pinCode;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleSaveAddress() {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);
      final isEditing = widget.addressToEdit != null;
      final address = Address(
        id: isEditing ? widget.addressToEdit!.id : appState.generateUuid(),
        title: isEditing ? widget.addressToEdit!.title : 'Saved Address',
        fullName: _nameController.text.trim().isNotEmpty 
            ? _nameController.text.trim() 
            : (appState.userName.isNotEmpty ? appState.userName : 'Valued Customer'),
        mobile: _mobileController.text.trim(),
        addressLine: _addressController.text.trim(),
        landmark: _landmarkController.text.trim(),
        city: _cityController.text.trim(),
        pinCode: _pinController.text.trim(),
        isSelected: isEditing ? widget.addressToEdit!.isSelected : true,
      );

      appState.addAddress(address);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.addressToEdit != null ? 'Edit Delivery Address' : 'Add Delivery Address',
          style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Recipient Name',
                        hint: 'e.g. John Doe',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter recipient name' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _mobileController,
                        label: 'Contact Mobile Number',
                        hint: '9876543210',
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        validator: (v) => v == null || v.length != 10 ? 'Please enter a 10-digit number' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address (House No, Building, Street)',
                        hint: '123, MG Road',
                        validator: (v) => v == null || v.isEmpty ? 'Please enter address details' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _landmarkController,
                        label: 'Landmark (Optional)',
                        hint: 'Near Metro Station',
                        required: false,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                              hint: 'Delhi',
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _pinController,
                              label: 'Pin Code',
                              hint: '110001',
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              validator: (v) => v == null || v.length != 6 ? 'Enter 6 digit PIN' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky save button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _handleSaveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Address',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? Function(String?)? validator,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
