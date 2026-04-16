import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/app_provider.dart';
import '../core/constants.dart';
import '../models/models.dart';

class SubmitCollectionScreen extends StatefulWidget {
  const SubmitCollectionScreen({super.key});

  @override
  State<SubmitCollectionScreen> createState() => _SubmitCollectionScreenState();
}

class _SubmitCollectionScreenState extends State<SubmitCollectionScreen> {
  final _notesCtrl = TextEditingController();
  Position? _position;
  XFile? _photo;
  bool _gettingGps = false;
  bool _submitting = false;
  bool _gpsEnabled = false;

  late CustomerModel _customer;
  late String _status;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _customer = args['customer'] as CustomerModel;
      _status = args['status'] as String;
      _initialized = true;
      _tryGetLocation();
    }
  }

  Future<void> _tryGetLocation() async {
    setState(() => _gettingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _gettingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gettingGps = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _gettingGps = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _position = pos;
        _gpsEnabled = true;
        _gettingGps = false;
      });
    } catch (e) {
      setState(() => _gettingGps = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Wajib menyalakan lokasi/GPS sebelum submit hasil kunjungan!'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Wajib melampirkan foto bukti kunjungan!'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<AppProvider>();

    try {
      final collectionId = await provider.submitCollection(
        customerId: _customer.id,
        status: _status,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        gpsLat: _position?.latitude,
        gpsLng: _position?.longitude,
      );

      if (collectionId != null && mounted) {
        // Upload photo if selected
        if (_photo != null && collectionId > 0) {
          try {
            await provider.collectionService.uploadPhoto(
              collectionId: collectionId,
              filePath: _photo!.path,
              gpsLat: _position?.latitude,
              gpsLng: _position?.longitude,
            );
          } catch (e) {
            // Silently handle if photo fails but data saved,
            // or we could show another warning.
            debugPrint('Failed to upload photo: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.pendingCount > 0
              ? 'Disimpan offline. Foto tidak didukung di mode offline saat ini.'
              : '✓ Kunjungan dan Foto berhasil disimpan'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color get _statusColor => AppColors.statusColor(_status);
  String get _statusLabel => AppColors.statusLabel(_status);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: _statusColor,
        foregroundColor: Colors.white,
        title: const Text('Input Kunjungan'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _status == 'bayar'
                        ? Icons.check_circle
                        : _status == 'janji_bayar'
                            ? Icons.schedule
                            : Icons.person_off,
                    color: _statusColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customer.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Status: $_statusLabel',
                          style: TextStyle(
                              color: _statusColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // GPS status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8)
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _gpsEnabled
                        ? Icons.location_on
                        : Icons.location_off,
                    color: _gpsEnabled ? AppColors.secondary : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _gettingGps
                        ? Row(children: [
                            const SpinKitThreeBounce(
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            const Text('Mendapatkan lokasi...'),
                          ])
                        : Text(
                            _gpsEnabled && _position != null
                                ? 'GPS: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'
                                : 'GPS tidak tersedia',
                            style: TextStyle(
                              color: _gpsEnabled
                                  ? AppColors.textPrimary
                                  : Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  if (!_gettingGps)
                    TextButton(
                      onPressed: _tryGetLocation,
                      child: const Text('Refresh'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8)
                ],
              ),
              child: TextField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Catatan kunjungan (opsional)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Photo
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      style: BorderStyle.solid),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8)
                  ],
                ),
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_photo!.path),
                            fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              size: 36, color: AppColors.primary.withOpacity(0.6)),
                          const SizedBox(height: 8),
                          Text('Foto Bukti (wajib)',
                              style: TextStyle(
                                  color: AppColors.primary.withOpacity(0.6),
                                  fontSize: 13)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 28),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _statusColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SpinKitThreeBounce(color: Colors.white, size: 22)
                    : Text('Simpan Kunjungan — $_statusLabel',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
