import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/auction_service.dart';
import '../../models/marketplace_models.dart';
import '../../utils/app_theme.dart';

class CreateAuctionScreen extends StatefulWidget {
  const CreateAuctionScreen({super.key});

  @override
  State<CreateAuctionScreen> createState() => _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends State<CreateAuctionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _startPriceCtrl = TextEditingController();
  final _incrementCtrl = TextEditingController(text: '10000');
  final _buyNowCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  ProductCategory _category = ProductCategory.lainnya;
  ProductCondition _condition = ProductCondition.baru;
  bool _anonymous = false;
  bool _hasBuyNow = false;
  bool _isLoading = false;

  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);

  final List<File> _images = [];
  final _picker = ImagePicker();

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(limit: 5);
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.map((x) => File(x.path)));
      if (_images.length > 5) _images.length = 5;
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now().add(const Duration(hours: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _endDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _endTime);
    if (time != null) setState(() => _endTime = time);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final svc = context.read<AuctionService>();
    final userData = await auth.getUserData(auth.currentUid ?? '');

    final endDateTime = DateTime(
      _endDate.year, _endDate.month, _endDate.day,
      _endTime.hour, _endTime.minute,
    );

    try {
      await svc.createAuction(
        sellerId: auth.currentUid ?? '',
        sellerName: userData?['name'] ?? '',
        sellerPhoto: userData?['photo'] ?? '',
        sellerAnonymous: _anonymous,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startPrice: double.parse(_startPriceCtrl.text.replaceAll('.', '')),
        minBidIncrement: double.parse(_incrementCtrl.text.replaceAll('.', '')),
        buyNowPrice: _hasBuyNow && _buyNowCtrl.text.isNotEmpty
            ? double.parse(_buyNowCtrl.text.replaceAll('.', ''))
            : null,
        category: _category,
        condition: _condition,
        endTime: endDateTime,
        location: _locationCtrl.text.trim(),
        imageFiles: _images,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lelang berhasil dibuat!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Lelang'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Mulai',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── IMAGES ───────────────────────────────────────
            _label('Foto Barang'),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 90, height: 90,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryLight, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.primaryBg,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded,
                              color: AppTheme.primaryGreen, size: 28),
                          Text('${_images.length}/5',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.primaryGreen)),
                        ],
                      ),
                    ),
                  ),
                  ..._images.asMap().entries.map((e) => Stack(
                    children: [
                      Container(
                        width: 90, height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                              image: FileImage(e.value), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2, right: 10,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(e.key)),
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── TITLE ────────────────────────────────────────
            _label('Nama Barang Lelang'),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Contoh: Keris Antik Jawa Abad 18'),
              validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 14),

            // ── CATEGORY & CONDITION ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Kategori'),
                      DropdownButtonFormField<ProductCategory>(
                        value: _category,
                        decoration: const InputDecoration(),
                        items: ProductCategory.values.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(_catLabel(c), style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Kondisi'),
                      DropdownButtonFormField<ProductCondition>(
                        value: _condition,
                        decoration: const InputDecoration(),
                        items: ProductCondition.values.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(_condLabel(c), style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        onChanged: (v) => setState(() => _condition = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── PRICING ──────────────────────────────────────
            Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Harga Awal (Rp)'),
                    TextFormField(
                      controller: _startPriceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '50000', prefixText: 'Rp '),
                      validator: (v) => v == null || v.isEmpty ? 'Wajib' : null,
                    ),
                  ],
                )),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Min. Kenaikan (Rp)'),
                    TextFormField(
                      controller: _incrementCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(prefixText: 'Rp '),
                      validator: (v) => v == null || v.isEmpty ? 'Wajib' : null,
                    ),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 14),

            // ── BUY NOW ──────────────────────────────────────
            Row(
              children: [
                Switch(
                  value: _hasBuyNow,
                  onChanged: (v) => setState(() => _hasBuyNow = v),
                  activeColor: AppTheme.accentAmber,
                ),
                const SizedBox(width: 8),
                const Text('Aktifkan Harga Beli Langsung',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            if (_hasBuyNow) ...[
              TextFormField(
                controller: _buyNowCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'Harga beli langsung',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.bolt_rounded, color: AppTheme.accentAmber),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // ── END TIME ─────────────────────────────────────
            _label('Waktu Berakhir Lelang'),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16,
                              color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16,
                              color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            '${_endTime.hour.toString().padLeft(2,'0')}:${_endTime.minute.toString().padLeft(2,'0')}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── DESCRIPTION ──────────────────────────────────
            _label('Deskripsi'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ceritakan kondisi, sejarah, dan keunikan barang...',
              ),
              validator: (v) => v == null || v.length < 10 ? 'Min. 10 karakter' : null,
            ),
            const SizedBox(height: 14),

            // ── LOCATION ─────────────────────────────────────
            _label('Lokasi'),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: 'Kota/Kabupaten',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // ── ANONYMOUS ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDDDD8), width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(_anonymous ? Icons.person_off_rounded : Icons.person_rounded,
                      color: _anonymous ? Colors.grey : AppTheme.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _anonymous
                          ? 'Identitasmu tersembunyi dari penawar'
                          : 'Lelang sebagai anonim',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Switch(
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                    activeColor: AppTheme.primaryGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: const Icon(Icons.gavel_rounded, size: 20),
                label: const Text('Mulai Lelang Sekarang'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(),
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: Color(0xFF888780), letterSpacing: 0.7)),
  );

  String _catLabel(ProductCategory c) {
    const m = {
      ProductCategory.elektronik: 'Elektronik',
      ProductCategory.fashion: 'Fashion',
      ProductCategory.makanan: 'Makanan',
      ProductCategory.kendaraan: 'Kendaraan',
      ProductCategory.properti: 'Properti',
      ProductCategory.jasa: 'Jasa',
      ProductCategory.seni: 'Seni',
      ProductCategory.lainnya: 'Lainnya',
    };
    return m[c] ?? c.name;
  }

  String _condLabel(ProductCondition c) {
    switch (c) {
      case ProductCondition.baru: return 'Baru';
      case ProductCondition.bekasLayak: return 'Bekas Layak';
      case ProductCondition.bekasRusak: return 'Rusak';
    }
  }
}
