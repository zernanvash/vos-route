import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade900.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      size: 64,
                      color: Colors.blue.shade400,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'VOSRoute',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fleet Dispatch',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                  ),
                  SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Email', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'Enter a valid email',
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    style: TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Password', Icons.lock),
                    obscureText: true,
                    validator: (v) => v != null && v.length >= 4
                        ? null
                        : 'Password too short',
                  ),
                  SizedBox(height: 24),
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: auth.isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('Sign In', style: TextStyle(fontSize: 16)),
                        ),
                      );
                    },
                  ),
                  if (context.watch<AuthProvider>().error != null)
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        context.watch<AuthProvider>().error!,
                        style: TextStyle(color: Colors.red.shade300),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.grey.shade900,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red),
      ),
    );
  }

  void _login() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<AuthProvider>().login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }
}
