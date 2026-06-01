import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool isLoading = false;

  Future<void> register() async {
    final username = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Semua field wajib diisi")));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konfirmasi kata sandi tidak sama")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = await SupabaseService.instance.register(
        username: username,
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registrasi berhasil. Halo, ${user.username}")),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Registrasi gagal: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
          /// BACKGROUND DECORATION
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),

                  child: Column(
                    children: [
                      /// LOGO
                      const Icon(Icons.menu_book, size: 70, color: primary),

                      const SizedBox(height: 12),

                      const Text(
                        "BookShelf",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Container(
                        padding: const EdgeInsets.all(24),

                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                            ),
                          ],
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Buat Akun Baru",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              "Mulai perjalanan literasi Anda hari ini.",
                              style: TextStyle(color: Colors.grey),
                            ),

                            const SizedBox(height: 30),

                            /// NAMA
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: "Nama Lengkap",
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// EMAIL
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.mail),
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// PASSWORD
                            TextField(
                              controller: passwordController,
                              obscureText: hidePassword,
                              decoration: InputDecoration(
                                labelText: "Kata Sandi",
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      hidePassword = !hidePassword;
                                    });
                                  },
                                  icon: Icon(
                                    hidePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// KONFIRMASI PASSWORD
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: hideConfirmPassword,
                              decoration: InputDecoration(
                                labelText: "Konfirmasi Kata Sandi",
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      hideConfirmPassword =
                                          !hideConfirmPassword;
                                    });
                                  },
                                  icon: Icon(
                                    hideConfirmPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            SizedBox(
                              width: double.infinity,
                              height: 55,

                              child: ElevatedButton(
                                onPressed: isLoading ? null : register,

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: secondary,
                                  foregroundColor: Colors.white,
                                ),

                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "Daftar",
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("Sudah punya akun?"),

                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Masuk",
                              style: TextStyle(
                                color: secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 50, height: 1, color: Colors.grey),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.auto_stories, color: Colors.grey),
                          ),
                          Container(width: 50, height: 1, color: Colors.grey),
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
}
