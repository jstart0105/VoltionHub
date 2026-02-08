// lib/ui/screens/login/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/core/common/constants/app_assets.dart';
import '/core/common/constants/theme/app_colors.dart';
import '/ui/main_navigation.dart';
import '/ui/widgets/button.dart';
import '/ui/widgets/textfield.dart';
import '/core/services/api/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  
  final LocalAuthentication auth = LocalAuthentication();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
  }

  // 1. Carrega último usuário e tenta biometria se houver sessão válida
  Future<void> _loadLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('last_email');
    final lastLoginTime = prefs.getInt('login_timestamp');
    
    if (lastEmail != null) {
      setState(() {
        _userIdController.text = lastEmail;
      });

      // Verifica se a sessão ainda é válida (ex: 24 horas = 86400000 ms)
      if (lastLoginTime != null) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        const sessionDuration = 24 * 60 * 60 * 1000; 

        if (currentTime - lastLoginTime < sessionDuration) {
          // Sessão válida, tenta biometria direto
          _authenticateBiometric();
        }
      }
    }
  }

  // 2. Lógica de Biometria
  Future<void> _authenticateBiometric() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) return;

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Toque no sensor para entrar como ${_userIdController.text}',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        // Se biometria passou, faz login automático (assumindo senha salva ou bypass)
        // Aqui, para segurança, você faria o login na API novamente.
        // Como o password pode ser nulo, tentamos o login sem senha ou com senha vazia.
        _performLogin(isBiometric: true);
      }
    } on PlatformException catch (e) {
      print("Erro biometria: $e");
    }
  }

  // 3. Lógica de Login na API
  Future<void> _performLogin({bool isBiometric = false}) async {
    setState(() => _isLoading = true);

    try {
      final email = _userIdController.text.trim();
      final password = _passwordController.text.isEmpty ? null : _passwordController.text;

      // Chama API
      final user = await _apiService.login(email, password);

      // Salva dados na sessão
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', email);
      await prefs.setInt('user_id', user.id!); // Salva ID para usar no header das requisições
      await prefs.setInt('login_timestamp', DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    AppAssets.logo,
                    height: 150,
                  ),
                  const Gap(48),
                  CustomTextField(
                    controller: _userIdController,
                    labelText: 'Usuário',
                    icon: Icons.person_outline,
                  ),
                  const Gap(16),
                  CustomTextField(
                    controller: _passwordController,
                    labelText: 'Senha',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isPasswordVisible: _isPasswordVisible,
                    onVisibilityToggle: _togglePasswordVisibility,
                  ),
                  const Gap(24),
                  
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : CustomButton(
                        text: 'Entrar',
                        onPressed: () => _performLogin(),
                      ),
                  
                  const Gap(16),
                  
                  // Botão de Biometria (aparece se já houver usuário salvo)
                  if (_userIdController.text.isNotEmpty)
                    TextButton.icon(
                      onPressed: _authenticateBiometric,
                      icon: const Icon(Icons.fingerprint, size: 40, color: AppColors.blue),
                      label: Text(
                        'Entrar com Biometria',
                        style: GoogleFonts.inter(color: AppColors.blue),
                      ),
                    ),

                  TextButton(
                    onPressed: () {
                      // Lógica de "Esqueci minha senha" (pode ser implementada depois)
                    },
                    child: Text(
                      'Esqueci minha senha',
                      style: GoogleFonts.inter(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}