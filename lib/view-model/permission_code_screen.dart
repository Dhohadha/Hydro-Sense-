import 'package:flutter/material.dart';
import 'package:gf1/model/user_model.dart';
import 'package:gf1/view-model/auth/edit_profile_screen.dart';
import 'package:gf1/view/utils/color_constants.dart';

class PermissionCodeScreen extends StatefulWidget {
  final UserModel userModel;
  const PermissionCodeScreen({super.key, required this.userModel});

  @override
  State<PermissionCodeScreen> createState() => _PermissionCodeScreenState();
}

class _PermissionCodeScreenState extends State<PermissionCodeScreen> {
  final TextEditingController _codeCtrl = TextEditingController();
  String? _errorMsg;

  // reusable code validation
  void _validateCode() {
    if (_codeCtrl.text.trim() == "0579") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfileScreen(
            userModel: widget.userModel,
          ),
        ),
      );
    } else {
      setState(() => _errorMsg = "Invalid code. Contact company.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Authorization Required",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter Company Code",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "This action is confidential. Only authorized access is permitted.",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 35),

            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              obscureText: true, // hides digits
              onSubmitted: (_) => _validateCode(), // Keyboard Tick triggers
              decoration: InputDecoration(
                labelText: "Company Code",
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                errorText: _errorMsg,
                prefixIcon: const Icon(Icons.lock_outline),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              "If you don't have the company code, please contact the company directly.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _validateCode,
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
