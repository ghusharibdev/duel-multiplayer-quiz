import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import 'home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() {
    final authService = ref.read(authProvider);
    if (authService.rememberMe) {
      setState(() {
        _rememberMe = true;
        _emailController.text = authService.savedEmail;
        _passwordController.text = authService.savedPassword;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isSignUp && name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authProvider);
      if (_isSignUp) {
        await authService.signUpWithEmail(email, password, displayName: name);
      } else {
        await authService.signInWithEmail(email, password, rememberMe: _rememberMe);
      }
      if (mounted) {
        final canPop = Navigator.of(context).canPop();
        if (canPop) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              Text(
                _isSignUp ? 'Create Account' : 'Sign In',
                style: AppTypography.display(color: AppColors.ink),
              ),

              const SizedBox(height: 8),

              Text(
                _isSignUp
                    ? 'Link your games to a permanent account'
                    : 'Play with a saved profile and stats',
                style: AppTypography.body(
                  color: AppColors.ink.withValues(alpha: 0.5),
                ),
              ),

              const SizedBox(height: 32),

              // Display name field (sign up only)
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'What should we call you?',
                    labelStyle: AppTypography.body(
                      color: AppColors.ink.withValues(alpha: 0.4),
                    ),
                    hintStyle: AppTypography.body(
                      color: AppColors.ink.withValues(alpha: 0.25),
                    ),
                    filled: true,
                    fillColor: AppColors.stone,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.coral),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: AppTypography.body(
                    color: AppColors.ink.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.stone,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.coral),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: AppTypography.body(
                    color: AppColors.ink.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.stone,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.coral),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Remember me checkbox
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                    activeColor: AppColors.coral,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                    'Remember me',
                    style: AppTypography.body(
                      color: AppColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: AppTypography.body(color: AppColors.coral),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // Submit button
              PrimaryButton(
                label: _isLoading
                    ? 'Loading...'
                    : _isSignUp
                        ? 'Sign Up'
                        : 'Sign In',
                onPressed: _isLoading ? () {} : _submit,
              ),

              const SizedBox(height: 16),

              // Toggle sign in / sign up
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                  });
                },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign In'
                      : "Don't have an account? Sign Up",
                  style: AppTypography.body(color: AppColors.coral),
                ),
              ),

              const SizedBox(height: 12),

              // Continue as guest
              SecondaryButton(
                label: 'Continue as Guest',
                onPressed: () {
                  if (canPop) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
