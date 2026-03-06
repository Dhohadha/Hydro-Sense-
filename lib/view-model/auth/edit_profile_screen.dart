import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gf1/model/user_model.dart';

import 'package:gf1/view/utils/color_constants.dart';
class EditProfileScreen extends StatefulWidget {
  final UserModel userModel;

  const EditProfileScreen({super.key, required this.userModel});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _pondAreaController;
  late TextEditingController _aeratorsController;
  late TextEditingController _guardian1Controller;
  late TextEditingController _guardian2Controller;
  late TextEditingController _aeratorRatingController;
  late TextEditingController _deviceController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userModel.name);
    _locationController = TextEditingController(text: widget.userModel.location);
    _pondAreaController = TextEditingController(text: widget.userModel.pondArea);
    _aeratorsController =
        TextEditingController(text: widget.userModel.numberOfAerators.toString());
    _guardian1Controller =
        TextEditingController(text: widget.userModel.guardianNumber1);
    _guardian2Controller =
        TextEditingController(text: widget.userModel.guardianNumber2 ?? '');
    _aeratorRatingController =
        TextEditingController(text: widget.userModel.aeratorRating.toString());
    _deviceController = TextEditingController(text: widget.userModel.deviceId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _pondAreaController.dispose();
    _aeratorsController.dispose();
    _guardian1Controller.dispose();
    _guardian2Controller.dispose();
    _aeratorRatingController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in!");

      final updatedData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'pondArea': _pondAreaController.text.trim(),
        'numberOfAerators': int.tryParse(_aeratorsController.text.trim()) ?? 0,
        'guardianNumber1': _guardian1Controller.text.trim(),
        'guardianNumber2': _guardian2Controller.text.trim(),
        'aeratorRating':
            double.tryParse(_aeratorRatingController.text.trim()) ?? 0.0,
        'deviceId': _deviceController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updatedData);

      if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      children: const [
        Icon(Icons.done, color: Colors.white),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Profile Updated ',
            style: TextStyle(fontSize: 15),
          ),
        ),
      ],
    ),
    backgroundColor: Colors.blueAccent,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  ),
);

Navigator.pop(context); // close Edit Profile
Navigator.pop(context); // close Permission Code
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextFormField(
                  controller: _nameController,
                  label: 'Name',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _deviceController,
                  label: 'Device ID',
                  icon: Icons.qr_code_scanner_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _locationController,
                  label: 'Location',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _pondAreaController,
                  label: 'Area of the pond (e.g., 2 Acres)',
                  icon: Icons.aspect_ratio_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _aeratorsController,
                  label: 'Number of Aerators',
                  icon: Icons.wind_power,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _aeratorRatingController,
                  label: 'Aerator rating (HP)',
                  icon: Icons.power_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _guardian1Controller,
                  label: 'Guardian Number 1',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _guardian2Controller,
                  label: 'Guardian Number 2 (Optional)',
                  icon: Icons.phone_forwarded_outlined,
                  keyboardType: TextInputType.phone,
                  isOptional: true,
                ),
                const SizedBox(height: 32),
                _buildSaveChangesButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: AppColors.primaryColor,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.titleGradient,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context)
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.titleColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.subtextColor),
        prefixIcon: Icon(icon, color: AppColors.primaryColor.withValues(alpha: 0.8)),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (!isOptional && (value == null || value.trim().isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildSaveChangesButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _updateUserData,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Center(
          child: _isLoading
              ? Center(heightFactor: 10, child: Center(
                  child: Image.asset("assets/loading.gif",
                    width: 100,
                    height: 100,
                  )
                ))
              : const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
