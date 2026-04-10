import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gf1/model/user_model.dart';
import 'package:gf1/view-model/auth/phone_login_screen.dart';
import 'package:gf1/view-model/permission_code_screen.dart';
import 'package:gf1/view/utils/color_constants.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _alertSoundEnabled = true;
  late Future<UserModel?> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _userDataFuture = _fetchUserData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alertSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
    });
  }

  Future<void> _toggleAlertSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_sound_enabled', value);
    setState(() {
      _alertSoundEnabled = value;
    });
  }


  Future<UserModel?> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
        
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
    return null;
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _logout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => PhoneNumberPage(),
        ), // your login widget
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
      }
    }
  }


  Widget _buildHeader() {
  return Padding(
    padding:EdgeInsetsGeometry.fromLTRB(28, 10, 0, 5),
    child: Align(
      alignment: Alignment.centerLeft, // 🔒 forces LEFT always
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Profile Page',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage Account',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.subtextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),

              // SizedBox(height: 20,),
              FutureBuilder<UserModel?>(
                future: _userDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      heightFactor: 10,
                      child: Center(
                        child: Image.asset(
                          "assets/loading.gif",
                          width: 500,
                          height: 300,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('An error occurred.'));
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(
                      child: Text('Could not load profile. Please try again.'),
                    );
                  }

                  final userModel = snapshot.data!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ClockWidget(), // Live clock widget
                        const SizedBox(height: 16),
                        _buildProfileHeader(userModel),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Account Settings"),
                        _buildMenuItems(userModel),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Support"),
                        _buildSupportMenuItems(),
                        const SizedBox(height: 24),
                        _buildLogoutButton(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildProfileHeader(UserModel userModel) {
  //   return Card(
  //     elevation: 5,
  //     shadowColor: Colors.black.withValues(alpha: 0.2),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //     child: Container(
  //       padding: const EdgeInsets.all(15.0),
  //       decoration: BoxDecoration(
  //         borderRadius: BorderRadius.circular(20),
  //         gradient:AppColors.watergradient,
  //       ),
  //       child: Column(
  //         children: [
  //           const CircleAvatar(
  //             radius: 50,
  //             backgroundColor: Colors.white,
  //             child: Icon(Icons.water_drop_sharp, size: 60, color: Colors.blue),
  //           ),
  //           const SizedBox(height: 10),
  //           Text(
  //             userModel.name,
  //             style: const TextStyle(
  //                 fontSize: 22,
  //                 fontWeight: FontWeight.bold,
  //                 color: Colors.black),
  //           ),
  //           const SizedBox(height: 4),
  //           Text(
  //             userModel.phoneNumber,
  //             style: TextStyle(fontSize: 16, color: Colors.black),
  //           ),
  //           const SizedBox(height: 12),
  //           Chip(
  //             avatar: const Icon(Icons.calendar_today,
  //                 size: 16, color: AppColors.primaryColor),
  //             label: Text(
  //               'Joined ${DateFormat('MMMM d, yyyy').format(userModel.createdAt.toDate())}',
  //               style: const TextStyle(color: AppColors.primaryColor),
  //             ),
  //             backgroundColor: Colors.white,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildProfileHeader(UserModel userModel) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppColors.watergradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 35, // smaller avatar
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.water_drop_sharp,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userModel.name,
                        style: const TextStyle(
                          fontSize: 18, // smaller text
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userModel.phoneNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: Chip(
                avatar: const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.blue,
                ),
                label: Text(
                  'Joined ${DateFormat('MMM d, yyyy').format(userModel.createdAt.toDate())}',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
                backgroundColor: Colors.white,
                visualDensity: VisualDensity.compact, // makes chip smaller
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

 Widget _buildMenuItems(UserModel userModel) {
  return Card(
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      children: [
        // ✏️ Edit Profile
        _buildMenuTile(
          icon: Icons.edit_outlined,
          title: 'Edit Profile',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PermissionCodeScreen(userModel: userModel),
              ),
            );
          },
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // 🌐 Change Language (BUTTON ONLY)
        _buildMenuTile(
          icon: Icons.language_outlined,
          title: 'Change Language',
          onTap: () {
            // No action for now
          },
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // 🔔 Notification Settings
        _buildMenuTile(
          icon: Icons.notifications_outlined,
          title: 'Notification Settings',
          onTap: () {},
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // 🔊 Alert Sound Toggle
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined, color: Colors.blue),
          title: const Text(
            'Alert Sound',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: const Text('Play loud sound for alerts'),
          value: _alertSoundEnabled,
          activeThumbColor: Colors.blue,
          onChanged: (bool value) {
            _toggleAlertSound(value);
          },
        ),
      ],
    ),
  );
}


  Widget _buildSupportMenuItems() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildMenuTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuTile(
            icon: Icons.info_outline,
            title: 'About Us',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // _buildMenuTile(
          //   icon: Icons.bug_report_outlined,
          //   title: 'Notification Debugger',
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => const BackgroundMessageDebugger(),
          //       ),
          //     );
          //   },
          // ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // _buildMenuTile(
          //   icon: Icons.engineering_outlined,
          //   title: 'Diagnostics',
          //   onTap: () {
          //     Navigator.pushNamed(context, '/diagnostics');
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 8.0,
      ),
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout, color: Colors.white),
      label: const Text('Logout', style: TextStyle(color: Colors.white)),
      onPressed: () => _showLogoutConfirmationDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 228, 119, 119),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }
}

// /// A widget that displays the current date and a live-updating clock.
// class ClockWidget extends StatefulWidget {
//   const ClockWidget({super.key});

//   @override
//   State<ClockWidget> createState() => _ClockWidgetState();
// }

// class _ClockWidgetState extends State<ClockWidget> {
//   late DateTime _currentTime;
//   late Timer _timer;

//   @override
//   void initState() {
//     super.initState();
//     _currentTime = DateTime.now();
//     // Update the time every second
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (mounted) {
//         setState(() {
//           _currentTime = DateTime.now();
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _timer.cancel();
//     super.dispose();
//   }

//   String _getGreeting() {
//     final hour = _currentTime.hour;
//     if (hour < 12) {
//       return 'Good Morning';
//     } else if (hour < 17) {
//       return 'Good Afternoon';
//     } else {
//       return 'Good Evening';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     String formattedDate = DateFormat('EEEE, MMMM d').format(_currentTime);
//     String formattedTime = DateFormat('h:mm:ss a').format(_currentTime);

//     return Card(
//       elevation: 2,
//       shadowColor: Colors.black.withValues(alpha: 0.1),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               _getGreeting(),
//               style: TextStyle(
//                 color: AppColors.accentColor,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 20,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   formattedDate,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     color: Colors.black54,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 Text(
//                   formattedTime,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     color: Colors.black87,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

// }

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late DateTime _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // Update the time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = _currentTime.hour;
    if (hour < 12) {
      return 'Good Morning 🌅';
    } else if (hour < 17) {
      return 'Good Afternoon ☀️';
    } else {
      return 'Good Evening 🌙';
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEEE, MMMM d').format(_currentTime);
    String formattedTime = DateFormat('h:mm:ss a').format(_currentTime);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.pastelGreenYellow,
        boxShadow: [
          // 3D Neumorphic effect
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(6, 6),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            offset: const Offset(-6, -6),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting with gradient text
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.primaryColor, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Date text
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.titleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Time with glowing effect
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: AppColors.softGreenTeal,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
