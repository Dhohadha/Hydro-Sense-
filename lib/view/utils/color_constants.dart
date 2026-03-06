  import 'package:flutter/material.dart';

  class AppColors {
    static const Color primaryColor =  Color.fromARGB(255, 74, 131, 205); //Color(0xFF00C6A8);
    static const Color secondaryColor =  Color(0xFF00B4DB);
    static const Color accentColor = Color(0xFF91E39F);
    static const Color accentSoft = Color.fromARGB(255, 28, 207, 135);  
      static const Color card = Color(0xFFFFFFFF);         // white card

    static const Color lightBg = Color(0xFFE6FDF4);
    static const Color white = Colors.white;
    static const Color grey = Colors.grey;
    static const Color black = Colors.black87;
    static const Color red = Colors.red;
    static const Color green = Colors.green;

    // Capacitor Card Colors
    static const Color activeGreen = Colors.green;
    static const Color inactiveRed = Colors.red;
    static const Color activeGreenLight = Color(0xFFE8F5E9); // green.shade50
    static const Color inactiveRedLight = Color(0xFFFFEBEE); // red.shade50

    // Parameters Page Colors
    static const Color cardColor = Color(0xFF00C6A8);
    static const Color borderColor = Color.fromARGB(51, 34, 211, 238);
    static const Color titleColor = Color.fromARGB(255, 51, 33, 67);
    static const Color textColor = Colors.white;
    static const Color valueColor = Color.fromARGB(255, 213, 183, 51);
    static const Color disconnectedColor = Colors.redAccent;

    // Gradient Button
    static const Gradient buttonGradient = LinearGradient(
      colors: [
        Color.fromARGB(255, 0, 255, 115),
        Color.fromARGB(255, 0, 180, 220),
        Color.fromARGB(255, 0, 132, 255),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    static const Color background = Color(0xFFF0F4F8);
    static const Color cardBackground = Colors.white;

    static const Color subtextColor = Color(0xFF757575);

    static const Color connectedColor = Color(0xFF4CAF50);

    static const Color shadowColor = Color(0xFFB0B0B0);
    static const Gradient titleGradient = LinearGradient(
      colors: [primaryColor, secondaryColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    static const Gradient warmgradient = LinearGradient(
      colors: [Color(0xFFF2C94C), Color(0xFFF2994A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    static const Gradient watergradient = LinearGradient(
      colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    static const Gradient greengradient = LinearGradient(
      colors: [Color(0xFF00C6A8), Color(0xFF00A98F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    static const Gradient purplegradient = LinearGradient(
      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    static const Gradient pastelSkyLavender = LinearGradient(
    colors: [Color(0xFFA1C4FD), Color(0xFFC2E9FB)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
  static const Gradient pastelMintAqua = LinearGradient(
    colors: [Color(0xFFD4FC79), Color(0xFF96E6A1)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
  static const Gradient pastelSandBlue = LinearGradient(
    colors: [Color(0xFFFFECD2), Color(0xFFFCB69F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient pastelGreenYellow = LinearGradient(
    colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const Gradient pastelRainbow = LinearGradient(
    colors: [
      Color(0xFFFF9A9E),
      Color(0xFFFAD0C4),
      Color(0xFFFBC2EB),
      Color(0xFFA1C4FD),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient softGreenTeal = LinearGradient(
    colors: [Color(0xFFA8E6CF), Color(0xFFDCEDC1)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
  static const Gradient forestMint = LinearGradient(
    colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient coralPeach = LinearGradient(
    colors: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient strawberryOrange = LinearGradient(
    colors: [Color(0xFFF5576C), Color(0xFFF093FB)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
  static const Gradient cherryViolet = LinearGradient(
    colors: [Color(0xFFFF0844), Color(0xFFFFB199)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
   static const Color primary = Color.fromARGB(255, 28, 207, 135);      // deep blue
  static const Color accent = Color.fromARGB(255, 74, 131, 205);     // white card
  static const Color borderSubtle = Color(0xFFE1E5EA); // soft border

  // Text colors
  static const Color textPrimary = Color(0xFF1F2933);  // dark text
  static const Color textSecondary = Color(0xFF6B7280); // grey text

  // Status colors (optional, for future use)
  static const Color ok = Color(0xFF16A34A);           // success
  static const Color warn = Color(0xFFF59E0B);         // warning
  static const Color error = Color(0xFFDC2626);  

  }
