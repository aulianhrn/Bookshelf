import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

const _bg       = Color(0xFFF4EAE1);
const _blue     = Color(0xFF2563EB);
const _blueDark = Color(0xFF1E40AF);
const _ink      = Color(0xFF1E1B4B);
const _muted    = Color(0xFF6B7280);
const _accent   = Color(0xFF9E421E);
const _card     = Color(0xFFFFFFFF);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _name    = TextEditingController();
  final _email   = TextEditingController();
  final _pass    = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePass    = true;
  bool _hideConfirm = true;
  bool _loading     = false;
  late final AnimationController _anim;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    for (final c in [_name, _email, _pass, _confirm]) c.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final u = _name.text.trim();
    final e = _email.text.trim();
    final p = _pass.text;
    final c = _confirm.text;
    if (u.isEmpty || e.isEmpty || p.isEmpty || c.isEmpty) {
      _snack('Semua field wajib diisi'); return;
    }
    if (p != c) { _snack('Konfirmasi kata sandi tidak sama'); return; }
    if (p.length < 6) { _snack('Password minimal 6 karakter'); return; }
    setState(() => _loading = true);
    try {
      await AuthService().register(username: u, email: e, password: p);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrasi berhasil! Silakan login.')));
    } catch (err) {
      _snack('Registrasi gagal: $err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: _accent, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        Positioned(top: -100, left: -80,
            child: _blob(_blue.withOpacity(.11), 260)),
        Positioned(bottom: -80, right: -60,
            child: _blob(_accent.withOpacity(.10), 220)),
        SafeArea(
          child: FadeTransition(opacity: _fade,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: _card, borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                              color: _ink.withOpacity(.06),
                              blurRadius: 12)]),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: _ink, size: 20))),
                    const SizedBox(height: 24),
                    const Text('Buat akun', style: TextStyle(fontSize: 28,
                        fontWeight: FontWeight.w800, color: _ink,
                        letterSpacing: -.5)),
                    const SizedBox(height: 6),
                    const Text('Mulai perjalanan literasimu hari ini.',
                        style: TextStyle(color: _muted, fontSize: 15)),
                    const SizedBox(height: 28),
                    // Form card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _card, borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: _ink.withOpacity(.06),
                            blurRadius: 30, offset: const Offset(0, 10))]),
                      child: Column(children: [
                        _field(_name,    'Nama lengkap',
                            Icons.person_outline_rounded),
                        const SizedBox(height: 14),
                        _field(_email,   'Email',
                            Icons.mail_outline_rounded,
                            type: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _field(_pass,    'Kata sandi',
                            Icons.lock_outline_rounded,
                            obscure: _hidePass,
                            suffix: _eye(_hidePass,
                                () => setState(() => _hidePass = !_hidePass))),
                        const SizedBox(height: 14),
                        _field(_confirm, 'Konfirmasi kata sandi',
                            Icons.lock_reset_rounded,
                            obscure: _hideConfirm,
                            suffix: _eye(_hideConfirm,
                                () => setState(
                                    () => _hideConfirm = !_hideConfirm))),
                        const SizedBox(height: 26),
                        _gradBtn(
                          onTap: _loading ? null : _register,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Daftar', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: Colors.white))),
                      ])),
                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Sudah punya akun? ',
                            style: TextStyle(color: _muted, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Masuk', style: TextStyle(
                              color: _blue, fontWeight: FontWeight.w700,
                              fontSize: 14))),
                      ]),
                  ])))
            ])))
      ]),
    );
  }

  Widget _blob(Color c, double s) => Container(width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(colors: [c, Colors.transparent])));

  Widget _eye(bool hidden, VoidCallback onTap) =>
    IconButton(icon: Icon(hidden
        ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20, color: _muted), onPressed: onTap);

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text,
      bool obscure = false, Widget? suffix}) =>
    TextField(controller: ctrl, keyboardType: type, obscureText: obscure,
      style: const TextStyle(color: _ink, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted, fontSize: 14),
        prefixIcon: Icon(icon, color: _blue, size: 20), suffixIcon: suffix,
        filled: true, fillColor: _bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _blue, width: 1.6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));

  Widget _gradBtn({required Widget child, VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_blue, _blueDark],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null ? [] : [BoxShadow(
              color: _blue.withOpacity(.30),
              blurRadius: 18, offset: const Offset(0, 7))]),
        child: Center(child: child)));
}