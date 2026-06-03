import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? currentUser;
  bool isLoading = true;
  Map<String, int> stats = {'reading': 0, 'finished': 0, 'reviews': 0};
  bool reminderEnabled = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await SessionService.getCurrentUser();
    if (!mounted) return;
    setState(() => currentUser = user);

    if (user != null) {
      final s = await UserService().getReadingStats(user.id);
      final notifSettings = await NotificationService.getSettings();
      if (!mounted) return;
      setState(() {
        stats = s;
        reminderEnabled = notifSettings['enabled'];
        reminderTime = TimeOfDay(
          hour: notifSettings['hour'],
          minute: notifSettings['minute'],
        );
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Izin notifikasi diperlukan untuk fitur ini"),
            ),
          );
        }
        return;
      }
      await NotificationService.scheduleDaily(
        hour: reminderTime.hour,
        minute: reminderTime.minute,
      );
    } else {
      await NotificationService.cancel();
    }
    if (mounted) setState(() => reminderEnabled = value);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminderTime,
    );
    if (picked == null) return;

    setState(() => reminderTime = picked);

    if (reminderEnabled) {
      await NotificationService.scheduleDaily(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  Future<void> pickAndUploadAvatar() async {
    // Tampilkan pilihan jika sudah ada foto
    if (currentUser?.avatarUrl != null) {
      await showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Ganti foto"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  "Hapus foto",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      // Langsung buka gallery jika belum ada foto
      _pickImage();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null || currentUser == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final url = await UserService().uploadAvatar(
        userId: currentUser!.id,
        fileBytes: bytes,
        fileName: 'avatar.$ext',
      );
      final updated = AppUser(
        id: currentUser!.id,
        email: currentUser!.email,
        username: currentUser!.username,
        avatarUrl: url,
      );
      await SessionService.saveSession(updated);
      if (mounted) setState(() => currentUser = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Foto berhasil diperbarui"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal upload foto: $e")));
      }
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await UserService().removeAvatar(currentUser!.id);
      final updated = AppUser(
        id: currentUser!.id,
        email: currentUser!.email,
        username: currentUser!.username,
        avatarUrl: null,
      );
      await SessionService.saveSession(updated);
      if (mounted) setState(() => currentUser = updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Foto profil dihapus")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal menghapus foto: $e")));
      }
    }
  }

  Future<void> showEditUsernameDialog() async {
    final controller = TextEditingController(text: currentUser?.username);
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Ubah Username"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Username baru",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final updated = await UserService().updateUser(
                  id: currentUser!.id,
                  username: controller.text.trim(),
                  email: currentUser!.email,
                );
                await SessionService.saveSession(updated);
                if (mounted) setState(() => currentUser = updated);
                messenger.showSnackBar(
                  const SnackBar(content: Text("Username berhasil diubah")),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text("Gagal: $e")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> showChangePasswordDialog() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Ganti Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password lama",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password baru",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Konfirmasi password baru",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Konfirmasi password tidak sesuai"),
                  ),
                );
                return;
              }
              if (newController.text.length < 6) {
                messenger.showSnackBar(
                  const SnackBar(content: Text("Password minimal 6 karakter")),
                );
                return;
              }
              Navigator.pop(dialogContext);
              try {
                await UserService().changePassword(
                  userId: currentUser!.id,
                  oldPassword: oldController.text,
                  newPassword: newController.text,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Password berhasil diubah"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text("Gagal: $e")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
    oldController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Future<void> logout() async {
    await SessionService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFBF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xffFBF9F5),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Color(0xff031632)),
            SizedBox(width: 8),
            Text(
              "BookShelf",
              style: TextStyle(
                color: Color(0xff031632),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: currentUser?.avatarUrl != null
                            ? NetworkImage(currentUser!.avatarUrl!)
                            : null,
                        child: currentUser?.avatarUrl == null
                            ? Text(
                                (currentUser?.username ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff031632),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xff185FA5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Username
                  Text(
                    currentUser?.username ?? '-',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff031632),
                    ),
                  ),
                  Text(
                    currentUser?.email ?? '-',
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 28),

                  // Statistik
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItem(
                          icon: Icons.menu_book,
                          value: '${stats['reading']}',
                          label: 'Sedang\nDibaca',
                          color: const Color(0xff185FA5),
                        ),
                        _divider(),
                        _statItem(
                          icon: Icons.check_circle_outline,
                          value: '${stats['finished']}',
                          label: 'Selesai\nDibaca',
                          color: const Color(0xff1D9E75),
                        ),
                        _divider(),
                        _statItem(
                          icon: Icons.rate_review_outlined,
                          value: '${stats['reviews']}',
                          label: 'Total\nReview',
                          color: const Color(0xff9E421E),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Menu aksi
                  _menuItem(
                    icon: Icons.person_outline,
                    label: "Ubah Username",
                    onTap: showEditUsernameDialog,
                  ),
                  _menuItem(
                    icon: Icons.lock_outline,
                    label: "Ganti Password",
                    onTap: showChangePasswordDialog,
                  ),
                  // Pengingat membaca
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xff031632),
                          ),
                          title: const Text("Pengingat membaca"),
                          subtitle: reminderEnabled
                              ? Text(
                                  "Setiap hari pukul ${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(fontSize: 12),
                                )
                              : const Text(
                                  "Nonaktif",
                                  style: TextStyle(fontSize: 12),
                                ),
                          trailing: Switch(
                            value: reminderEnabled,
                            onChanged: _toggleReminder,
                            activeColor: const Color(0xff185FA5),
                          ),
                        ),
                        // Tombol ganti waktu — hanya muncul jika aktif
                        if (reminderEnabled)
                          InkWell(
                            onTap: _pickReminderTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Ganti waktu pengingat",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff185FA5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _menuItem(
                    icon: Icons.logout,
                    label: "Keluar",
                    color: const Color(0xffE24B4A),
                    onTap: logout,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(height: 50, width: 1, color: Colors.grey.shade200);
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xff031632),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }
}
