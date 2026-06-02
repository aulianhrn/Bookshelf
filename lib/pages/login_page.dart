import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool obscurePassword = true;
  bool isLoading = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan kata sandi wajib diisi")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userService = userser();
      final result = await userService.login(email, password);

      if (result == null) {
        throw Exception('Email atau password salah');
      }

      // Simpan nama user
      final user = result['user'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('user_id', user['uuid']);
      await prefs.setString('nama', user['nama']);
      await prefs.setString('email', user['email']);

      await UserService.saveCurrentUserName(user['nama']);

      final token = result['token'] as String;

      await AuthStorage.saveSession(
        token: token,
        expiredAt: DateTime.now().add(
          const Duration(hours: 24),
        ), //ganti jam disini
      );

      final biometricVerified = await _showBiometricDialog();

      if (biometricVerified && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } catch (e) {
      String errorMessage = 'Terjadi kesalahan';

      if (e.toString().contains('salah')) {
        errorMessage = 'Email atau password salah';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Tidak bisa terhubung ke server';
      } else {
        errorMessage = e.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xff031632);
    const secondary = Color(0xff9E421E);
    const background = Color(0xffFBF9F5);

    return Scaffold(
      backgroundColor: background,

      body: Stack(
        children: [
          /// DECORATION
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),

                  child: Column(
                    children: [
                      /// LOGO
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        "BookShelf",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "Selamat Datang Kembali",
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),

                      const SizedBox(height: 40),

                      /// CARD
                      Container(
                        padding: const EdgeInsets.all(24),

                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 15,
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ],
                        ),

                        child: Column(
                          children: [
                            /// EMAIL
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "Email",
                                hintText: "nama@email.com",
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// PASSWORD
                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                labelText: "Kata Sandi",

                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      obscurePassword = !obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text("Lupa Kata Sandi?"),
                              ),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              height: 55,

                              child: ElevatedButton.icon(
                                onPressed: isLoading ? null : login,

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: secondary,
                                  foregroundColor: Colors.white,
                                ),

                                icon: isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.login),

                                label: Text(
                                  isLoading ? "Memproses..." : "Masuk",
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "Atau masuk dengan",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(
                                      Icons.g_mobiledata,
                                      size: 30,
                                    ),
                                    label: const Text("Google"),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.apple),
                                    label: const Text("Apple"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("Belum punya akun?"),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Daftar sekarang",
                              style: TextStyle(color: secondary),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          dot(secondary),
                          dot(secondary.withValues(alpha: 0.6)),
                          dot(secondary.withValues(alpha: 0.3)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget dot(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
