import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import 'login_page.dart';

// ── Design tokens (selaras dengan home_page & main_nav) ────────────────────
const _bg        = Color(0xFFF4EAE1);
const _blue      = Color(0xFF2563EB);
const _blueDark  = Color(0xFF1E40AF);
const _blueLight = Color(0xFFDBEAFE);
const _ink       = Color(0xFF1E1B4B);
const _muted     = Color(0xFF6B7280);
const _card      = Color(0xFFFFFFFF);
const _green     = Color(0xFF1D9E75);
const _danger    = Color(0xFFE24B4A);
// ────────────────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  AppUser? currentUser;
  bool isLoading = true;
  Map<String, int> stats = {'reading': 0, 'finished': 0, 'reviews': 0};
  bool reminderEnabled = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 20, minute: 0);

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _init();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _init() async {
    final user = await SessionService.getCurrentUser();
    if (!mounted) return;
    setState(() => currentUser = user);

    if (user != null) {
      final s = await UserService().getReadingStats(user.id);
      final notif = await NotificationService.getSettings();
      if (!mounted) return;
      setState(() {
        stats = s;
        reminderEnabled = notif['enabled'];
        reminderTime =
            TimeOfDay(hour: notif['hour'], minute: notif['minute']);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }

    _fadeCtrl.forward();
  }

  // ── Reminder ──────────────────────────────────────────────────────────────

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) _snack('Izin notifikasi diperlukan untuk fitur ini');
        return;
      }
      await NotificationService.scheduleDaily(
          hour: reminderTime.hour, minute: reminderTime.minute);
    } else {
      await NotificationService.cancel();
    }
    if (mounted) setState(() => reminderEnabled = value);
  }

  Future<void> _pickReminderTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: reminderTime);
    if (picked == null) return;
    setState(() => reminderTime = picked);
    if (reminderEnabled) {
      await NotificationService.scheduleDaily(
          hour: picked.hour, minute: picked.minute);
    }
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<void> pickAndUploadAvatar() async {
    if (currentUser?.avatarUrl != null) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _avatarBottomSheet(),
      );
    } else {
      _pickImage();
    }
  }

  Widget _avatarBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              _sheetTile(
                icon: Icons.photo_library_outlined,
                iconColor: _blue,
                title: 'Ganti foto',
                onTap: () { Navigator.pop(context); _pickImage(); },
              ),
              const SizedBox(height: 8),
              _sheetTile(
                icon: Icons.delete_outline_rounded,
                iconColor: _danger,
                title: 'Hapus foto',
                titleColor: _danger,
                onTap: () { Navigator.pop(context); _removeAvatar(); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = _ink,
    Color titleColor = _ink,
  }) {
    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor)),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80);
    if (picked == null || currentUser == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final url = await UserService().uploadAvatar(
          userId: currentUser!.id,
          fileBytes: bytes,
          fileName: 'avatar.$ext');
      final updated = AppUser(
          id: currentUser!.id,
          email: currentUser!.email,
          username: currentUser!.username,
          avatarUrl: url);
      await SessionService.saveSession(updated);
      if (mounted) setState(() => currentUser = updated);
      if (mounted) _snack('Foto berhasil diperbarui', color: _green);
    } catch (e) {
      if (mounted) _snack('Gagal upload foto: $e', color: _danger);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await UserService().removeAvatar(currentUser!.id);
      final updated = AppUser(
          id: currentUser!.id,
          email: currentUser!.email,
          username: currentUser!.username,
          avatarUrl: null);
      await SessionService.saveSession(updated);
      if (mounted) setState(() => currentUser = updated);
      if (mounted) _snack('Foto profil dihapus');
    } catch (e) {
      if (mounted) _snack('Gagal menghapus foto: $e', color: _danger);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> showEditUsernameDialog() async {
    final ctrl = TextEditingController(text: currentUser?.username);
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _styledDialog(
        title: 'Ubah Username',
        icon: Icons.person_outline_rounded,
        content: _dialogTextField(
            controller: ctrl,
            label: 'Username baru',
            icon: Icons.person_outline_rounded),
        actions: [
          _dialogBtn('Batal', onTap: () => Navigator.pop(ctx)),
          _dialogBtn('Simpan', isPrimary: true, onTap: () async {
            Navigator.pop(ctx);
            try {
              final updated = await UserService().updateUser(
                  id: currentUser!.id,
                  username: ctrl.text.trim(),
                  email: currentUser!.email);
              await SessionService.saveSession(updated);
              if (mounted) setState(() => currentUser = updated);
              messenger.showSnackBar(
                  _buildSnackBar('Username berhasil diubah', color: _green));
            } catch (e) {
              messenger.showSnackBar(
                  _buildSnackBar('Gagal: $e', color: _danger));
            }
          }),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> showChangePasswordDialog() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final cfmCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _styledDialog(
        title: 'Ganti Password',
        icon: Icons.lock_outline_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogTextField(
                controller: oldCtrl,
                label: 'Password lama',
                icon: Icons.lock_outline_rounded,
                obscure: true),
            const SizedBox(height: 12),
            _dialogTextField(
                controller: newCtrl,
                label: 'Password baru',
                icon: Icons.lock_reset_rounded,
                obscure: true),
            const SizedBox(height: 12),
            _dialogTextField(
                controller: cfmCtrl,
                label: 'Konfirmasi password',
                icon: Icons.lock_reset_rounded,
                obscure: true),
          ],
        ),
        actions: [
          _dialogBtn('Batal', onTap: () => Navigator.pop(ctx)),
          _dialogBtn('Simpan', isPrimary: true, onTap: () async {
            if (newCtrl.text != cfmCtrl.text) {
              messenger.showSnackBar(
                  _buildSnackBar('Konfirmasi tidak sesuai', color: _danger));
              return;
            }
            if (newCtrl.text.length < 6) {
              messenger.showSnackBar(
                  _buildSnackBar('Password minimal 6 karakter', color: _danger));
              return;
            }
            Navigator.pop(ctx);
            try {
              await UserService().changePassword(
                  userId: currentUser!.id,
                  oldPassword: oldCtrl.text,
                  newPassword: newCtrl.text);
              messenger.showSnackBar(
                  _buildSnackBar('Password berhasil diubah', color: _green));
            } catch (e) {
              messenger.showSnackBar(
                  _buildSnackBar('Gagal: $e', color: _danger));
            }
          }),
        ],
      ),
    );
    oldCtrl.dispose();
    newCtrl.dispose();
    cfmCtrl.dispose();
  }

  Future<void> logout() async {
    await SessionService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  // ── Snackbar helpers ──────────────────────────────────────────────────────

  void _snack(String msg, {Color? color}) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(_buildSnackBar(msg, color: color));

  SnackBar _buildSnackBar(String msg, {Color? color}) => SnackBar(
        content:
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color ?? _ink,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: _blue, strokeWidth: 2.5))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                slivers: [
                  _buildSliverHeader(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildNameAndStats(),
                          const SizedBox(height: 28),
                          _sectionLabel('AKUN'),
                          const SizedBox(height: 10),
                          _menuItem(
                            icon: Icons.person_outline_rounded,
                            iconBg: _blue.withOpacity(.1),
                            iconColor: _blue,
                            label: 'Ubah Username',
                            onTap: showEditUsernameDialog,
                          ),
                          _menuItem(
                            icon: Icons.lock_outline_rounded,
                            iconBg: const Color(0xFFF0EBFF),
                            iconColor: const Color(0xFF7C3AED),
                            label: 'Ganti Password',
                            onTap: showChangePasswordDialog,
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel('PREFERENSI'),
                          const SizedBox(height: 10),
                          _reminderTile(),
                          const SizedBox(height: 20),
                          _sectionLabel('LAINNYA'),
                          const SizedBox(height: 10),
                          _menuItem(
                            icon: Icons.logout_rounded,
                            iconBg: _danger.withOpacity(.1),
                            iconColor: _danger,
                            label: 'Keluar',
                            labelColor: _danger,
                            onTap: logout,
                            showChevron: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Sliver Header ─────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient banner
          Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_blue, _blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(top: -30, right: -30,
                    child: _decorCircle(160, Colors.white.withOpacity(.06))),
                Positioned(top: 20, right: 60,
                    child: _decorCircle(60, Colors.white.withOpacity(.05))),
                Positioned(bottom: -20, left: -20,
                    child: _decorCircle(100, Colors.white.withOpacity(.05))),
                // Logo row
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.2),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.menu_book_rounded,
                            color: Colors.white, size: 18)),
                      const SizedBox(width: 10),
                      const Text('BookShelf',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -.3)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // White spacer below banner so avatar overlaps cleanly
          Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(height: 56, color: _bg)),

          // Avatar centred on the seam
          Positioned(
            bottom: 4, left: 0, right: 0,
            child: Center(
              child: Stack(
                children: [
                  Container(
                    width: 104, height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 4),
                      boxShadow: [
                        BoxShadow(
                            color: _ink.withOpacity(.14),
                            blurRadius: 20,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: ClipOval(
                      child: currentUser?.avatarUrl != null
                          ? Image.network(
                              currentUser!.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _avatarFallback(),
                            )
                          : _avatarFallback(),
                    ),
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 2, right: 2,
                    child: GestureDetector(
                      onTap: pickAndUploadAvatar,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_blue, _blueDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                          border: Border.all(color: _bg, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: _blue.withOpacity(.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    final initials = (currentUser?.username ?? 'U')[0].toUpperCase();
    return Container(
      color: _blueLight,
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: _blue)),
      ),
    );
  }

  Widget _decorCircle(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  // ── Name + Stats card ─────────────────────────────────────────────────────

  Widget _buildNameAndStats() {
    return Column(
      children: [
        Text(
          currentUser?.username ?? '-',
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -.4),
        ),
        const SizedBox(height: 4),
        Text(
          currentUser?.email ?? '-',
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 20),
        Container(
          padding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: _ink.withOpacity(.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _statCell(
                  value: '${stats['reading']}',
                  label: 'Sedang\nDibaca',
                  icon: Icons.menu_book_rounded,
                  color: _blue)),
              _vertDivider(),
              Expanded(child: _statCell(
                  value: '${stats['finished']}',
                  label: 'Selesai\nDibaca',
                  icon: Icons.check_circle_outline_rounded,
                  color: _green)),
              _vertDivider(),
              Expanded(child: _statCell(
                  value: '${stats['reviews']}',
                  label: 'Total\nReview',
                  icon: Icons.rate_review_outlined,
                  color: const Color(0xFFD97706))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCell({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(height: 8),
      Text(value,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 3),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, color: _muted, height: 1.35)),
    ]);
  }

  Widget _vertDivider() =>
      Container(width: 1, height: 60, color: Colors.grey.shade200);

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: 1.0)),
      );

  // ── Menu item ─────────────────────────────────────────────────────────────

  Widget _menuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    Color labelColor = _ink,
    bool showChevron = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _ink.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: labelColor))),
              if (showChevron)
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Reminder tile ─────────────────────────────────────────────────────────

  Widget _reminderTile() {
    final timeStr =
        '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _ink.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.notifications_outlined,
                    color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pengingat membaca',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _ink)),
                    const SizedBox(height: 2),
                    Text(
                      reminderEnabled
                          ? 'Setiap hari pukul $timeStr'
                          : 'Nonaktif',
                      style: TextStyle(
                          fontSize: 12,
                          color: reminderEnabled
                              ? const Color(0xFFD97706)
                              : _muted),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: .85,
                child: Switch(
                  value: reminderEnabled,
                  onChanged: _toggleReminder,
                  activeColor: _blue,
                  activeTrackColor: _blueLight,
                ),
              ),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: reminderEnabled
                ? Column(children: [
                    Divider(height: 1, thickness: 1,
                        color: Colors.grey.shade100),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickReminderTime,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          child: Row(children: [
                            const SizedBox(width: 52),
                            Icon(Icons.access_time_rounded,
                                size: 16,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Text('Ganti waktu pengingat',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: _blueLight,
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: Text(timeStr,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _blue)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ])
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Dialog helpers ────────────────────────────────────────────────────────

  Widget _styledDialog({
    required String title,
    required IconData icon,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: _blue.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: _blue, size: 20)),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
            ]),
            const SizedBox(height: 20),
            content,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions
                  .map((w) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: w))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14, color: _ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: _muted),
          prefixIcon:
              Icon(icon, size: 18, color: _blue.withOpacity(.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _dialogBtn(String label,
      {required VoidCallback onTap, bool isPrimary = false}) {
    if (isPrimary) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_blue, _blueDark],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: _blue.withOpacity(.35),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      );
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _muted,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}