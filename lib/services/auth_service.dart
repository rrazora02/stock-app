import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _emailKey = 'email';
  static const String _passwordKey = 'password';
  static const String _pinKey = 'pin';
  static const String _hasPinKey = 'hasPin';
  static const String _rememberMeKey = 'rememberMe';

  final LocalAuthentication _localAuth = LocalAuthentication();
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<bool> isLoggedIn() async {
    return _prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<bool> isRememberMeEnabled() async {
    return _prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithPin() async {
    final pin = await getPin();
    if (pin == null) return false;

    final result = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter PIN'),
        content: TextField(
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          onSubmitted: (value) {
            Navigator.of(context).pop(value == pin);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<bool> hasPin() async {
    return _prefs.getBool(_hasPinKey) ?? false;
  }

  Future<String?> getPin() async {
    return _prefs.getString(_pinKey);
  }

  Future<void> savePin(String pin) async {
    await _prefs.setString(_pinKey, pin);
    await _prefs.setBool(_hasPinKey, true);
  }

  Future<String?> getEmail() async {
    return _prefs.getString(_emailKey);
  }

  Future<String?> getPassword() async {
    return _prefs.getString(_passwordKey);
  }

  Future<void> saveLoginCredentials(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    if (rememberMe) {
      await _prefs.setString(_emailKey, email);
      await _prefs.setString(_passwordKey, password);
    }
    await _prefs.setBool(_rememberMeKey, rememberMe);
  }

  Future<void> logout() async {
    if (!await isRememberMeEnabled()) {
      await _prefs.remove(_emailKey);
      await _prefs.remove(_passwordKey);
    }
    await _prefs.remove(_rememberMeKey);
  }

  Future<bool> setupPin() async {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Setup PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter 4-digit PIN',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'Confirm 4-digit PIN',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text.length != 4) {
                  setState(() {
                    errorText = 'PIN must be 4 digits';
                  });
                  return;
                }

                if (pinController.text != confirmPinController.text) {
                  setState(() {
                    errorText = 'PINs do not match';
                  });
                  return;
                }

                savePin(pinController.text);
                Navigator.of(context).pop(true);
              },
              child: const Text('Setup'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }
}
