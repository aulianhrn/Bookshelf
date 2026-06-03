import 'package:bookself_/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'main_nav.dart';
import 'register_page.dart';

// ── Shared design tokens ──────────────────────────────────────────
const kBg        = Color(0xFFF4EAE1);
const kBlue      = Color(0xFF2563EB);
const kBlueDark  = Color(0xFF1E40AF);
const kBlueLight = Color(0xFFDBEAFE);
const kInk       = Color(0xFF1E1B4B);
const kMuted     = Color(0xFF6B7280);
const kAccent    = Color(0xFF9E421E);
const kCard      = Color(0xFFFFFFFF);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool _obscure = true;
  bool _loading = false;
  final _email    = TextEditingController();
  final _password = TextEditingController();
  late final AnimationController _anim;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _snack('Email dan kata sandi wajib diisi'); return;
    }
    setState(() => _loading = true);
    try {
      final result = await AuthService().login(
          email: _email.text.trim(), password: _password.text);
      if (result == null) throw Exception('Email atau password salah');
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainNavigation()));
    } catch (e) {
      _snack(e.toString().contains('salah')
          ? 'Email atau password salah'
          : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: kAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        // Decorative blobs
        Positioned(top: -90, right: -90,
          child: _blob(kBlue.withOpacity(.13), 260)),
        Positioned(bottom: -70, left: -70,
          child: _blob(kAccent.withOpacity(.11), 220)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(opacity: _fade,
                child: SlideTransition(position: _slide,
                  child: Column(children: [
                    // Logo
                    Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kBlue, kBlueDark],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(
                          color: kBlue.withOpacity(.30),
                          blurRadius: 24, offset: const Offset(0, 10))]),
                      child: const Icon(Icons.menu_book_rounded,
                          color: Colors.white, size: 38)),
                    const SizedBox(height: 18),
                    const Text('BookShelf',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                            color: kInk, letterSpacing: -.5)),
                    const SizedBox(height: 4),
                    const Text('Selamat datang kembali',
                        style: TextStyle(color: kMuted, fontSize: 15)),
                    const SizedBox(height: 32),
                    // Card
                    _card(Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Masuk', style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w700, color: kInk)),
                        const SizedBox(height: 22),
                        _field(_email, 'Email',
                            Icons.mail_outline_rounded,
                            type: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _field(_password, 'Kata Sandi',
                            Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                                  size: 20, color: kMuted),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure))),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: () {},
                            child: const Text('Lupa kata sandi?',
                                style: TextStyle(color: kBlue, fontSize: 13)))),
                        const SizedBox(height: 6),
                        _gradBtn(
                          onTap: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Masuk', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: Colors.white))),
                      ])),
                    const SizedBox(height: 26),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Belum punya akun? ',
                          style: TextStyle(color: kMuted, fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterPage())),
                        child: const Text('Daftar',
                            style: TextStyle(color: kBlue,
                                fontWeight: FontWeight.w700, fontSize: 14))),
                    ]),
                  ]))))),
        ),
      ]),
    );
  }

  Widget _blob(Color c, double s) => Container(width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(colors: [c, Colors.transparent])));

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(28),
      boxShadow: [BoxShadow(
          color: kInk.withOpacity(.06), blurRadius: 32,
          offset: const Offset(0, 12))]),
    child: child);

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text,
      bool obscure = false, Widget? suffix}) =>
    TextField(controller: ctrl, keyboardType: type, obscureText: obscure,
      style: const TextStyle(color: kInk, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: kBlue, size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: kBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBlue, width: 1.6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));

  Widget _gradBtn({required Widget child, VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: onTap == null
              ? LinearGradient(colors: [kBlue.withOpacity(.5),
                  kBlueDark.withOpacity(.5)])
              : const LinearGradient(
                  colors: [kBlue, kBlueDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null ? [] : [BoxShadow(
              color: kBlue.withOpacity(.32),
              blurRadius: 18, offset: const Offset(0, 7))]),
        child: Center(child: child)));
}