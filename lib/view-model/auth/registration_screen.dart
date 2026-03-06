import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gf1/view-model/homepage.dart';
import '../../view/utils/color_constants.dart';
import '../../view/widgets/widgets.dart';

class RegistrationScreen extends StatefulWidget {
  final String phoneNumber;

  const RegistrationScreen({super.key, required this.phoneNumber});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _pondAreaController = TextEditingController();
  final _aeratorsController = TextEditingController();
  final _guardian1Controller = TextEditingController();
  final _guardian2Controller = TextEditingController();
  final _aeratorRatingController = TextEditingController();
  final _deviceController = TextEditingController();

  bool _isLoading = false;

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

  Future<void> _saveUserData() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in!");
      }

      final userData = {
        'name': _nameController.text.trim(),
        'phoneNumber': widget.phoneNumber,
        'location': _locationController.text.trim(),
        'pondArea': _pondAreaController.text.trim(),
        'numberOfAerators': int.tryParse(_aeratorsController.text.trim()) ?? 0,
        'guardianNumber1': _guardian1Controller.text.trim(),
        'guardianNumber2': _guardian2Controller.text.trim(),
        'aeratorRating':
            double.tryParse(_aeratorRatingController.text.trim()) ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': user.uid,
        'deviceId': _deviceController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Successful! Welcome.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainNavigationPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The AppBar is removed to give a more modern, seamless feel.
      appBar: AppBar(
        title: Text("Register"),
        centerTitle: true,
        elevation: 2,
        actions: [
          Tooltip(
            message: 'Logout',
            child: IconButton(
              icon: const Icon(Icons.logout_outlined),
              color: Colors
                  .redAccent, // Use a color to signify a 'destructive' action
              onPressed: () {
                // Correctly sign the user out
                FirebaseAuth.instance.signOut();

                // The AuthGate will automatically handle navigation, so you
                // often don't even need the Navigator call here.
              },
            ),
          ),
        ],
        useDefaultSemanticsOrder: true,
        forceMaterialTransparency: true,
        
      ),
      
      // A custom header is built into the body.
      body: Container(
        // A subtle gradient background adds depth.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppColors.lightBg.withValues(alpha: 0.5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildSectionCard(
                      title: 'User Profile',
                      children: [
                        _buildStyledTextFormField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildStyledTextFormField(
                          controller: _locationController,
                          label: 'City / Location',
                          icon: Icons.location_on_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Farm Details',
                      children: [
                        _buildStyledTextFormField(
                          controller: _pondAreaController,
                          label: 'Area of the pond (in acres)',
                          icon: Icons.aspect_ratio_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildStyledTextFormField(
                          controller: _deviceController,
                          label: 'Device ID',
                          icon: Icons.pin,
                          // keyboardType: TextInputType.number,
                          
                        ),
                        const SizedBox(height: 16),
                        _buildStyledTextFormField(
                          controller: _aeratorsController,
                          label: 'Number of Aerators',
                          icon: Icons.wind_power_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildStyledTextFormField(
                          controller: _aeratorRatingController,
                          label: 'Aerator rating (e.g., 2 HP)',
                          icon: Icons.flash_on_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Emergency Contacts',
                      children: [
                        _buildStyledTextFormField(
                          controller: _guardian1Controller,
                          label: 'Guardian Number 1',
                          icon: Icons.security_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'This field is required';
                            }
                            if (value.length < 10) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildStyledTextFormField(
                          controller: _guardian2Controller,
                          label: 'Guardian Number 2 (Optional)',
                          icon: Icons.add_moderator_outlined,
                          isOptional: true,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    PrimaryButton(
                      text: 'Create My Account',
                      onPressed: _saveUserData,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET BUILDER METHODS FOR A CLEANER STRUCTURE

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.person_add_alt_1, size: 60, color: AppColors.primaryColor),
        const SizedBox(height: 16),
        Text(
          'Complete Your Profile',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Just a few details to get you set up.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4.0,
      shadowColor: AppColors.primaryColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            ),
            const Divider(height: 24, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryColor.withValues(alpha: 0.8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryColor,
            width: 2.0,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator:
          validator ??
          (value) {
            if (!isOptional && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
    );
  }
}
