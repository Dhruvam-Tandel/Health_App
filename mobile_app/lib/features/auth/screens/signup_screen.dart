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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Doctor verification fields
  final _licenseNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _medicalCouncilController = TextEditingController();

  // Staff verification fields
  final _organizationIdController = TextEditingController();
  final _employeeIdController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'patient';
  String _selectedMedicalCouncil = 'Medical Council of India';
  bool _isLoading = false;

  final List<DropdownMenuItem<String>> _roles = [
    const DropdownMenuItem(
        value: 'patient', child: Text('Patient (Standard User)')),
    const DropdownMenuItem(
        value: 'doctor', child: Text('Doctor (Medical Practitioner)')),
    const DropdownMenuItem(
        value: 'staff', child: Text('Hospital Staff (Admin)')),
  ];

  final List<String> _medicalCouncils = [
    'Medical Council of India',
    'State Medical Council',
    'Dental Council of India',
    'Nursing Council',
  ];

  void _handleGoogleSignup() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      String? role = await authService.signInWithGoogle();
      if (mounted && role != null) {
        _showSuccessDialog('Account created successfully!',
            'You can now access your dashboard.');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go('/dashboard');
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Google Sign-Up Error', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      await authService.signup(
        _emailController.text.trim(),
        _passwordController.text,
        _selectedRole,
        licenseNumber: _selectedRole == 'doctor'
            ? _licenseNumberController.text.trim()
            : null,
        fullName:
            _selectedRole == 'doctor' ? _fullNameController.text.trim() : null,
        medicalCouncil:
            _selectedRole == 'doctor' ? _selectedMedicalCouncil : null,
        organizationId: _selectedRole == 'staff'
            ? _organizationIdController.text.trim()
            : null,
        employeeId:
            _selectedRole == 'staff' ? _employeeIdController.text.trim() : null,
      );

      // Logout immediately after signup to force email verification
      await authService.logout();

      if (mounted) {
        _showSuccessDialog(
          'Account Created Successfully!',
          'A verification email has been sent to ${_emailController.text.trim()}. Please verify your email before logging in.',
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) context.go('/login');
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Signup Failed', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'name@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter email';
                        if (!RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Create Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Min 6 characters',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'User Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _roles,
                      onChanged: (value) =>
                          setState(() => _selectedRole = value!),
                      dropdownColor: Colors.white,
                    ),

                    // Doctor Verification Fields
                    if (_selectedRole == 'doctor') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user,
                                    color: Colors.blue, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Doctor Verification Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name (as per license)',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _licenseNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Medical License Number',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.badge),
                                hintText: 'e.g., MCI123456',
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedMedicalCouncil,
                              decoration: const InputDecoration(
                                labelText: 'Medical Council',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.account_balance),
                              ),
                              items: _medicalCouncils
                                  .map((council) => DropdownMenuItem(
                                      value: council, child: Text(council)))
                                  .toList(),
                              onChanged: (value) => setState(
                                  () => _selectedMedicalCouncil = value!),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your credentials will be verified against the medical council database',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber[900]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Staff Verification Fields
                    if (_selectedRole == 'staff') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.purple.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.business,
                                    color: Colors.purple, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Organization Verification Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[900],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _organizationIdController,
                              decoration: const InputDecoration(
                                labelText: 'Organization ID',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.business_center),
                                hintText: 'e.g., ORG12345',
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _employeeIdController,
                              decoration: const InputDecoration(
                                labelText: 'Employee ID',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.badge_outlined),
                                hintText: 'e.g., EMP789',
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your email domain must match your organization and employee ID must be registered',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber[900]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _handleSignup,
                            child: const Text('Create Account'),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _handleGoogleSignup,
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text(
                                "Sign Up with Google (Patient Only)"),
                          ),
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
                    text: "Already have an account? ",
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _licenseNumberController.dispose();
    _fullNameController.dispose();
    _medicalCouncilController.dispose();
    _organizationIdController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }
}
