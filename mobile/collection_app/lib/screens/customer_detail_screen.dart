import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Daftar VoIP app yang dikenali (urutan = prioritas) ──────────────────────
// App pertama yang terinstall akan dipakai sebagai "Telepon VoIP".
// Tambahkan entry baru di sini untuk mendukung app VoIP lain.
const _knownVoipApps = [
  _VoipApp(label: 'PortSIP UC',  package: 'com.portgo'),
  _VoipApp(label: 'PortSIP UC',  package: 'com.portsip.portsipuc'),
  _VoipApp(label: 'Zoiper',      package: 'com.zoiper.android.app'),
  _VoipApp(label: 'Linphone',    package: 'org.linphone'),
];

class _VoipApp {
  final String label;
  final String package;
  const _VoipApp({required this.label, required this.package});
}
// ────────────────────────────────────────────────────────────────────────────

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  /// VoIP app pertama yang terinstall, null = tidak ada / belum selesai deteksi
  _VoipApp? _activeVoipApp;
  bool _voipDetected = false; // true setelah deteksi selesai

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetail();
      _detectVoipApp();
    });
  }

  Future<void> _loadDetail() async {
    final customer =
        ModalRoute.of(context)!.settings.arguments as CustomerModel;
    try {
      await context.read<AppProvider>().collectionService.uploadPhoto;
      setState(() {
        _detail = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Cari VoIP app pertama yang terinstall dari daftar _knownVoipApps
  Future<void> _detectVoipApp() async {
    for (final app in _knownVoipApps) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: app.package,
        );
        await intent.canResolveActivity();
        // Kalau tidak throw = package terinstall
        if (mounted) {
          setState(() {
            _activeVoipApp = app;
            _voipDetected = true;
          });
        }
        return;
      } catch (_) {
        continue;
      }
    }
    // Tidak ada VoIP terinstall
    if (mounted) setState(() => _voipDetected = true);
  }

  /// Minta permission CALL_PHONE jika belum diberikan
  Future<bool> _ensureCallPermission(BuildContext ctx) async {
    final status = await Permission.phone.status;
    if (status.isGranted) return true;

    final result = await Permission.phone.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text(
              'Izin telepon ditolak. Buka Pengaturan untuk mengaktifkan.'),
          action: SnackBarAction(
            label: 'Pengaturan',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return false;
  }

  /// Telepon biasa via tel: scheme → Android App Chooser (dialer, GetContact, dll)
  Future<void> _dialNormal(BuildContext ctx, String rawPhone) async {
    if (!await _ensureCallPermission(ctx)) return;
    try {
      await launchUrl(
        Uri.parse('tel:$rawPhone'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
              content: Text('Tidak dapat membuka aplikasi telepon.')),
        );
      }
    }
  }

  /// Telepon VoIP langsung via package name
  Future<void> _dialVoip(BuildContext ctx, String rawPhone) async {
    if (_activeVoipApp == null) return;
    if (!await _ensureCallPermission(ctx)) return;
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.CALL',
        data: 'tel:$rawPhone',
        package: _activeVoipApp!.package,
      );
      await intent.launch();
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
                '${_activeVoipApp!.label} tidak bisa dibuka. '
                'Pastikan aplikasi aktif.'),
          ),
        );
      }
    }
  }

  void _showPhoneOptions(BuildContext context, String rawPhone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih Metode Telepon',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Divider(height: 1),

            // Opsi 1 — Telepon Biasa (selalu tampil)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.call, color: Colors.blueAccent),
              ),
              title: const Text('Telepon Biasa'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _dialNormal(context, rawPhone);
              },
            ),

            // Opsi 2 — Telepon VoIP (hanya tampil kalau ada VoIP terinstall)
            if (!_voipDetected)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_activeVoipApp != null) ...[
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade50,
                  child: const Icon(Icons.phone_in_talk, color: Colors.purple),
                ),
                title: const Text('Telepon VoIP'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _dialVoip(context, rawPhone);
                },
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer =
        ModalRoute.of(context)!.settings.arguments as CustomerModel;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(customer.name, overflow: TextOverflow.ellipsis),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header card
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        customer.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.statusColor(customer.status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              AppColors.statusLabel(customer.status),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  _SectionCard(
                    title: 'Informasi Customer',
                    icon: Icons.person_outline,
                    children: [
                      _InfoRow(Icons.phone, 'Telepon', customer.phone ?? '-'),
                      _InfoRow(Icons.location_on_outlined, 'Alamat',
                          customer.address ?? '-'),
                      if (customer.notes != null && customer.notes!.isNotEmpty)
                        _InfoRow(Icons.notes, 'Catatan', customer.notes!),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Call & WhatsApp ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (customer.phone != null &&
                                  customer.phone!.isNotEmpty &&
                                  customer.phone != '-')
                              ? () =>
                                  _showPhoneOptions(context, customer.phone!)
                              : null,
                          icon: const Icon(Icons.call),
                          label: const Text('Telepon'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (customer.phone != null &&
                                  customer.phone!.isNotEmpty &&
                                  customer.phone != '-')
                              ? () async {
                                  String waNum = customer.phone!
                                      .replaceAll(RegExp(r'[^0-9+]'), '');
                                  if (waNum.startsWith('0')) {
                                    waNum = '62${waNum.substring(1)}';
                                  } else if (waNum.startsWith('+')) {
                                    waNum = waNum.substring(1);
                                  }
                                  final url = Uri.parse(
                                      'whatsapp://send?phone=$waNum');
                                  try {
                                    if (!await launchUrl(url,
                                        mode: LaunchMode.externalApplication)) {
                                      final fallback =
                                          Uri.parse('https://wa.me/$waNum');
                                      await launchUrl(fallback,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  } catch (e) {
                                    final fallback =
                                        Uri.parse('https://wa.me/$waNum');
                                    await launchUrl(fallback,
                                        mode: LaunchMode.externalApplication);
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.message),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Google Maps ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (customer.lat != null && customer.lng != null)
                          ? () async {
                              final url = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=${customer.lat},${customer.lng}');
                              if (!await launchUrl(url,
                                  mode: LaunchMode.externalApplication)) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Tidak dapat membuka Gmaps')),
                                  );
                                }
                              }
                            }
                          : null,
                      icon: const Icon(Icons.map),
                      label: Text(
                          (customer.lat != null && customer.lng != null)
                              ? 'Buka di Google Maps'
                              : 'Koordinat GPS Tidak Tersedia'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Input Kunjungan ──────────────────────────────────────
                  _SectionCard(
                    title: 'Input Kunjungan',
                    icon: Icons.assignment_outlined,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _ActionButton(
                            label: 'Bayar',
                            icon: Icons.check_circle_outline,
                            color: AppColors.secondary,
                            onTap: () =>
                                _showSubmitDialog(context, customer, 'bayar'),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            label: 'Janji Bayar',
                            icon: Icons.schedule,
                            color: AppColors.warning,
                            onTap: () => _showSubmitDialog(
                                context, customer, 'janji_bayar'),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            label: 'Tdk Ketemu',
                            icon: Icons.person_off_outlined,
                            color: AppColors.danger,
                            onTap: () => _showSubmitDialog(
                                context, customer, 'tidak_ketemu'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── VA Request ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/va-request',
                        arguments: customer,
                      ),
                      icon: const Icon(Icons.credit_card),
                      label: const Text('Request VA (Virtual Account)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmitDialog(
      BuildContext context, CustomerModel customer, String status) {
    Navigator.pushNamed(context, '/submit-collection', arguments: {
      'customer': customer,
      'status': status,
    }).then((_) => Navigator.pop(context));
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}