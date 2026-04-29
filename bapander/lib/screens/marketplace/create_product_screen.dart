import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/marketplace_service.dart';
import '../../models/marketplace_models.dart';
import '../../utils/app_theme.dart';

class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  ProductCategory _category = ProductCategory.lainnya;
  ProductCondition _condition = ProductCondition.baru;
  bool _anonymous = false;
  bool _isLoading = false;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final svc = context.read<MarketplaceService>();
    final userData = await auth.getUserData(auth.currentUid ?? '');

    try {
      final productId = await svc.createProduct(
        sellerId: auth.currentUid ?? '',
        sellerName: userData?['name'] ?? '',
        sellerPhoto: userData?['photo'] ?? '',
        sellerAnonymous: _anonymous,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.replaceAll('.', '')),
        category: _category,
        condition: _condition,
        location: _locationCtrl.text.trim(),
        imageFiles: _images,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil dipasang!'),
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
        title: const Text('Jual Produk'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Pasang',
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

            // ── IMAGE PICKER ──────────────────────────────────
            const _SectionLabel('Foto Produk (maks. 5)'),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add button
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppTheme.primaryLight, width: 1.5,
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.primaryBg,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_rounded,
                              color: AppTheme.primaryGreen, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            '${_images.length}/5',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Previews
                  ..._images.asMap().entries.map((e) => Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                  image: FileImage(e.value),
                                  fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 10,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _images.removeAt(e.key)),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle),
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
            const SizedBox(height: 16),

            // ── TITLE ─────────────────────────────────────────
            const _SectionLabel('Judul Produk'),
            TextFormField(
              controller: _titleCtrl,
              decoration:
                  const InputDecoration(hintText: 'Contoh: HP Samsung A54 5G'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 14),

            // ── CATEGORY ──────────────────────────────────────
            const _SectionLabel('Kategori'),
            DropdownButtonFormField<ProductCategory>(
              value: _category,
              decoration: const InputDecoration(),
              items: ProductCategory.values
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(_categoryLabel(c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 14),

            // ── CONDITION ─────────────────────────────────────
            const _SectionLabel('Kondisi'),
            Row(
              children: ProductCondition.values
                  .map((c) => Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _condition = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _condition == c
                                  ? AppTheme.primaryGreen
                                  : Colors.white,
                              border: Border.all(
                                color: _condition == c
                                    ? AppTheme.primaryGreen
                                    : const Color(0xFFDDDDD8),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _conditionLabel(c),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _condition == c
                                    ? Colors.white
                                    : const Color(0xFF888780),
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),

            // ── PRICE ─────────────────────────────────────────
            const _SectionLabel('Harga (Rp)'),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '150000',
                prefixText: 'Rp ',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan harga' : null,
            ),
            const SizedBox(height: 14),

            // ── DESCRIPTION ───────────────────────────────────
            const _SectionLabel('Deskripsi'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Jelaskan kondisi, spesifikasi, dan detail produk...',
              ),
              validator: (v) =>
                  v == null || v.length < 10 ? 'Minimal 10 karakter' : null,
            ),
            const SizedBox(height: 14),

            // ── LOCATION ──────────────────────────────────────
            const _SectionLabel('Lokasi'),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: 'Contoh: Banjarmasin, Kalimantan Selatan',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // ── ANONYMOUS TOGGLE ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDDDD8), width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _anonymous
                          ? const Color(0xFF1A1A2E)
                          : AppTheme.primaryBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _anonymous
                          ? Icons.person_off_rounded
                          : Icons.person_rounded,
                      color: _anonymous
                          ? Colors.white70
                          : AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Jual Anonim',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          _anonymous
                              ? 'Identitasmu tersembunyi dari pembeli'
                              : 'Namamu akan terlihat oleh pembeli',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888780)),
                        ),
                      ],
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
                icon: const Icon(Icons.storefront_rounded, size: 20),
                label: const Text('Pasang Iklan Sekarang'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(ProductCategory c) {
    const labels = {
      ProductCategory.elektronik: 'Elektronik',
      ProductCategory.fashion: 'Fashion',
      ProductCategory.makanan: 'Makanan',
      ProductCategory.kendaraan: 'Kendaraan',
      ProductCategory.properti: 'Properti',
      ProductCategory.jasa: 'Jasa',
      ProductCategory.seni: 'Seni',
      ProductCategory.lainnya: 'Lainnya',
    };
    return labels[c] ?? c.name;
  }

  String _conditionLabel(ProductCondition c) {
    switch (c) {
      case ProductCondition.baru: return 'Baru';
      case ProductCondition.bekasLayak: return 'Bekas';
      case ProductCondition.bekasRusak: return 'Rusak';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF888780),
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
