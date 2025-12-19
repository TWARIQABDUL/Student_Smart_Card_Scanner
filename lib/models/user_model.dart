import 'dart:convert';

class Campus {
  final String name;
  final String abrev;
  final String logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final String backgroundColor;
  final String cardTextColor;

  Campus({
    required this.name,
    required this.abrev,
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.cardTextColor,
  });

  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      name: json['name'] ?? 'Unknown University',
      abrev: json['abrev'] ?? 'UNIV',
      logoUrl: json['logoUrl'] ?? '',
      // Default to Blue Theme if backend sends null
      primaryColor: json['primaryColor'] ?? '#3D5CFF',
      secondaryColor: json['secondaryColor'] ?? '#2B45B5',
      backgroundColor: json['backgroundColor'] ?? '#0F111A',
      cardTextColor: json['cardTextColor'] ?? '#FFFFFF',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'abrev': abrev,
      'logoUrl': logoUrl,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'backgroundColor': backgroundColor,
      'cardTextColor': cardTextColor,
    };
  }
}

class User {
  final String name;
  final String email;
  final String role;
  final String nfcToken;
  final double walletBalance;
  final bool isActive;
  final Campus? campus; // 👈 THE SAAS FIELD

  User({
    required this.name,
    required this.email,
    required this.role,
    required this.nfcToken,
    required this.walletBalance,
    required this.isActive,
    this.campus,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'GUARD',
      nfcToken: json['nfcToken'] ?? '',
      walletBalance: (json['walletBalance'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? true,
      campus: json['campus'] != null ? Campus.fromJson(json['campus']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'nfcToken': nfcToken,
      'walletBalance': walletBalance,
      'isActive': isActive,
      'campus': campus?.toJson(),
    };
  }
}