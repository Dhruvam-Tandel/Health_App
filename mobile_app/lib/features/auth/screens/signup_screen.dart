import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Role selection
  String _selectedRole = 'patient';

  // Common
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  // Doctor-specific
  final _licenseNumberController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _feeController = TextEditingController();
  final _hospitalController = TextEditingController();

  // Admin/Staff-specific
  final _adminIdController = TextEditingController();
  final _departmentController = TextEditingController();

  final List<DropdownMenuItem<String>> _roles = const [
    DropdownMenuItem(value: 'patient', child: Text('Patient (Standard User)')),
    DropdownMenuItem(
        value: 'doctor', child: Text('Doctor (Medical Practitioner)')),
    DropdownMenuItem(value: 'staff', child: Text('Admin / Staff')),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _licenseNumberController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _feeController.dispose();
    _hospitalController.dispose();
    _adminIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      await authService.signup(
        _emailController.text.trim(),
        _passwordController.text,
        _selectedRole,
        fullName: _fullNameController.text.trim(),
        licenseNumber: _selectedRole == 'doctor'
            ? _licenseNumberController.text.trim()
            : null,
        specialization: _selectedRole == 'doctor'
            ? _specializationController.text.trim()
            : null,
        experience: _selectedRole == 'doctor'
            ? _experienceController.text.trim()
            : null,
        consultationFee:
            _selectedRole == 'doctor' ? _feeController.text.trim() : null,
        hospital:
            _selectedRole == 'doctor' ? _hospitalController.text.trim() : null,
        adminId:
            _selectedRole == 'staff' ? _adminIdController.text.trim() : null,
        department:
            _selectedRole == 'staff' ? _departmentController.text.trim() : null,
      );

      // Logout immediately — force email verification before login
      await authService.logout();

      if (mounted) {
        _showSuccessDialog(
          'Account Created!',
          'A verification email has been sent to ${_emailController.text.trim()}.\n\nPlease verify your email before logging in.',
        );
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Signup Failed', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleSignup() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final role = await authService.signInWithGoogle();
      if (mounted && role != null) {
        switch (role) {
          case 'doctor':
            context.go('/doctor-dashboard');
            break;
          case 'staff':
            context.go('/staff-dashboard');
            break;
          default:
            context.go('/patient-dashboard');
        }
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Google Sign-Up Error', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Flexible(child: Text(title)),
        ]),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 8),
          Flexible(child: Text(title)),
        ]),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white),
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.primary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Account',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Join the Smart Health Vault network',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── Role Selector ─────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'I am a…',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _roles,
                      onChanged: (value) =>
                          setState(() => _selectedRole = value!),
                      dropdownColor: Colors.white,
                    ),
                    const SizedBox(height: 16),

                    // ── Common Fields ──────────────────────────────
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: _selectedRole == 'doctor'
                            ? 'Full Name (as per license)'
                            : 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'name@example.com',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Create Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Min 6 characters',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Doctor Extra Fields ────────────────────────
                    if (_selectedRole == 'doctor') ...[
                      _sectionCard(
                        icon: Icons.verified_user,
                        color: Colors.blue,
                        title: 'Doctor Professional Details',
                        subtitle:
                            'Your details will be registered directly in the clinic database.',
                        children: [
                          TextFormField(
                            controller: _licenseNumberController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Medical License Number *',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.badge),
                              hintText: 'e.g., MCI-2012-001',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'License number is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _specializationController,
                            decoration: const InputDecoration(
                              labelText: 'Specialization *',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.medical_services_outlined),
                              hintText: 'e.g., Cardiology',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Specialization is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _experienceController,
                                decoration: const InputDecoration(
                                  labelText: 'Experience',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.work_outline),
                                  hintText: 'e.g., 5 years',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _feeController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Fee (₹)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.currency_rupee),
                                  hintText: 'e.g., 500',
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _hospitalController,
                            decoration: const InputDecoration(
                              labelText: 'Hospital / Clinic',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.local_hospital_outlined),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Admin/Staff Extra Fields ───────────────────
                    if (_selectedRole == 'staff') ...[
                      _sectionCard(
                        icon: Icons.admin_panel_settings,
                        color: Colors.purple,
                        title: 'Admin Verification',
                        subtitle:
                            'Your Admin ID will be verified against the system registry.',
                        children: [
                          TextFormField(
                            controller: _adminIdController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Admin ID *',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.badge_outlined),
                              hintText: 'e.g., ADM-001',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Admin ID is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _departmentController,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.business_outlined),
                              hintText: 'e.g., Administration',
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Submit ─────────────────────────────────────
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _handleSignup,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _selectedRole == 'doctor'
                                  ? 'Register as Doctor'
                                  : _selectedRole == 'staff'
                                      ? 'Register as Admin'
                                      : 'Create Account',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          if (_selectedRole == 'patient') ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _handleGoogleSignup,
                              icon: Image.asset(
                                'assets/google_logo.png',
                                height: 22,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.g_mobiledata, size: 28),
                              ),
                              label:
                                  const Text('Sign up with Google (Patient)'),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/login'),
                child: RichText(
                  text: TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(color: Colors.grey[600]),
                    children: [
                      TextSpan(
                        text: 'Login',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 15),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
