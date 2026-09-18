import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;
  bool _rememberMe = false;
  bool _obscurePassword = true;

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
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Capitalize each word in the name (e.g. "john doe" -> "John Doe")
  String _capitalizeName(String name) {
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _submit() async {
    final rawName = _nameController.text.trim();
    final name = _isSignUp ? _capitalizeName(rawName) : rawName;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isSignUp && rawName.isEmpty) {
      setState(() => _error = 'Please enter your name');
      _nameFocus.requestFocus();
      return;
    }

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      _emailFocus.requestFocus();
      return;
    }

    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      _passwordFocus.requestFocus();
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      _passwordFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authProvider);
      if (_isSignUp) {
        final credential = await authService.signUpWithEmail(email, password, displayName: name);
        // Create Firestore player document for the new user
        final user = credential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('players').doc(user.uid).set({
            'displayName': name,
            'email': email,
            'isAnonymous': false,
            'wins': 0,
            'losses': 0,
            'draws': 0,
            'streak': 0,
            'bestStreak': 0,
            'rating': 1000,
            'totalMatches': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          });
        }
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
    final colors = AppColors.of(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colors.ink),
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
              const SizedBox(height: 8),

              // App logo/icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.coral.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sports_esports_rounded,
                    size: 32,
                    color: colors.coral,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                _isSignUp ? 'Create Account' : 'Welcome Back',
                style: AppTypography.display(color: colors.ink),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                _isSignUp
                    ? 'Sign up to save your stats and compete'
                    : 'Sign in to continue playing',
                style: AppTypography.body(color: colors.inkSubtle),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ─── Form fields ───

              // Display name field (sign up only)
              if (_isSignUp) ...[
                _buildTextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  label: 'Display Name',
                  hint: 'e.g. John Doe',
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.name,
                  onSubmitted: (_) => _emailFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              _buildTextField(
                controller: _emailController,
                focusNode: _emailFocus,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),

              const SizedBox(height: 16),

              // Password field
              _buildTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: 'Password',
                hint: 'At least 6 characters',
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.visiblePassword,
                obscureText: _obscurePassword,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: colors.inkSubtle,
                    size: 22,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 16),

              // Remember me + Forgot row
              Row(
                children: [
                  // Remember me
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _rememberMe ? colors.coral : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _rememberMe ? colors.coral : colors.border,
                              width: 1.5,
                            ),
                          ),
                          child: _rememberMe
                              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: AppTypography.caption(color: colors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 18, color: colors.coral),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.caption(color: colors.coral),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Submit button
              PrimaryButton(
                label: _isLoading
                    ? 'Loading...'
                    : _isSignUp
                        ? 'Create Account'
                        : 'Sign In',
                onPressed: _isLoading ? () {} : _submit,
              ),

              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: colors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: AppTypography.caption(color: colors.inkFaint),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: colors.border)),
                ],
              ),

              const SizedBox(height: 20),

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

              const SizedBox(height: 24),

              // Toggle sign in / sign up
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isSignUp
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: AppTypography.body(color: colors.inkSubtle),
                      children: [
                        TextSpan(
                          text: _isSignUp ? 'Sign In' : 'Sign Up',
                          style: AppTypography.body(color: colors.coral),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    final colors = AppColors.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: AppTypography.body(color: colors.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colors.inkSubtle, size: 22),
        suffixIcon: suffixIcon,
        labelStyle: AppTypography.body(color: colors.inkSubtle),
        hintStyle: AppTypography.body(color: colors.inkFaint),
        filled: true,
        fillColor: colors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.coral, width: 1.5),
        ),
      ),
    );
  }
}
