import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/models.dart';

class VaRequestScreen extends StatefulWidget {
  const VaRequestScreen({super.key});

  @override
  State<VaRequestScreen> createState() => _VaRequestScreenState();
}

class _VaRequestScreenState extends State<VaRequestScreen> {
  final _notesCtrl = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  VaRequestModel? _existingVa;
  String? _error;
  late CustomerModel _customer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _customer = ModalRoute.of(context)!.settings.arguments as CustomerModel;
      _loadVaStatus();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVaStatus({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await ApiClient().get('/api/va/${_customer.id}');
      if (mounted) {
        setState(() {
          _existingVa = VaRequestModel.fromJson(response.data);
          _loading = false;
        });

        // Start auto-refresh if status is still pending
        if (_existingVa?.status == 'pending') {
          _startPolling();
        } else {
          _pollingTimer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _existingVa = null;
          _loading = false;
        });
      }
    }
  }

  void _startPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _loadVaStatus(isBackground: true);
    });
  }

  Future<void> _requestVa() async {
    setState(() => _submitting = true);
    try {
      await ApiClient().post('/api/va/request', data: {
        'customer_id': _customer.id,
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ VA request berhasil dikirim'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ));
        await _loadVaStatus();
      }
    } catch (e) {
      String msg = 'Gagal request VA';
      final raw = e.toString();
      if (raw.contains('pending')) msg = 'Sudah ada VA request yang pending';
      if (raw.contains('aktif')) msg = 'Customer sudah memiliki VA aktif';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Virtual Account'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child:
                  SpinKitFadingCircle(color: AppColors.primary, size: 48))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withOpacity(0.1),
                          child: Text(
                            _customer.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_customer.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(_customer.phone ?? '-',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_existingVa != null) ...[
                    // Existing VA info
                    _VaStatusCard(va: _existingVa!),
                  ] else ...[
                    // Request form
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.credit_card,
                                  color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Request Virtual Account',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Request VA untuk payment customer ini. Admin akan membuatkan VA.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const Divider(height: 24),
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Catatan (opsional)...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: AppColors.surface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _requestVa,
                              icon: _submitting
                                  ? const SizedBox()
                                  : const Icon(Icons.send_rounded),
                              label: _submitting
                                  ? const SpinKitThreeBounce(
                                      color: Colors.white, size: 18)
                                  : const Text('Kirim Request VA'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _VaStatusCard extends StatelessWidget {
  final VaRequestModel va;
  const _VaStatusCard({required this.va});

  @override
  Widget build(BuildContext context) {
    final isCompleted = va.status == 'completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
        border: Border.all(
          color: isCompleted
              ? AppColors.secondary.withOpacity(0.4)
              : AppColors.warning.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle
                    : Icons.hourglass_empty,
                color: isCompleted ? AppColors.secondary : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                isCompleted ? 'VA Aktif' : 'Menunggu Admin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isCompleted ? AppColors.secondary : AppColors.warning,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (isCompleted && va.vaNumber != null) ...[
            const Divider(height: 20),
            _VaRow('Nomor VA', va.vaNumber!, isCopyable: true),
            _VaRow('Bank', va.vaBank ?? '-'),
            if (va.vaAmount != null)
              _VaRow('Jumlah',
                  'Rp ${va.vaAmount!.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}'),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Request VA telah dikirim. Tunggu admin untuk membuatkan nomor VA.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _VaRow extends StatelessWidget {
  final String label, value;
  final bool isCopyable;
  const _VaRow(this.label, this.value, {this.isCopyable = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          const Text(': '),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          if (isCopyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
              tooltip: 'Salin Nomor VA',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Nomor VA berhasil disalin!'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.secondary,
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
        ],
      ),
    );
  }
}
