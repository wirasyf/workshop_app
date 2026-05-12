import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spareart_app/features/pos/presentation/widgets/barcode_scanner_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/utils/app_toast.dart';
import '../providers/product_provider.dart';

/// Form tambah/edit produk
class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _motorTypeCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  final _wholesalePriceCtrl = TextEditingController();
  final _stockQtyCtrl = TextEditingController();
  final _stockMinCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  int? _selectedCategoryId;
  String? _imagePath;
  File? _imageFile;
  bool _isLoading = false;
  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    final db = ref.read(databaseProvider);
    final product = await db.getProductById(widget.productId!);
    if (product != null) {
      _nameCtrl.text = product.name;
      _skuCtrl.text = product.sku ?? '';
      _barcodeCtrl.text = product.barcode ?? '';
      _brandCtrl.text = product.brand ?? '';
      _motorTypeCtrl.text = product.motorType ?? '';
      _costPriceCtrl.text = product.costPrice.toStringAsFixed(0);
      _sellPriceCtrl.text = product.sellPrice.toStringAsFixed(0);
      _wholesalePriceCtrl.text =
          product.sellPriceWholesale?.toStringAsFixed(0) ?? '';
      _stockQtyCtrl.text = product.stockQty.toString();
      _stockMinCtrl.text = product.stockMin.toString();
      _unitCtrl.text = product.unit;
      _selectedCategoryId = product.categoryId;
      _imagePath = product.imageUrl;
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imagePath = null; // Prioritaskan file baru
        });
      }
    }
  }

  Future<String?> _uploadProductImage(String productName) async {
    if (_imageFile == null) return _imagePath;

    try {
      final client = SupabaseService.client;
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await client.storage.from('products').upload(
        fileName,
        _imageFile!,
        fileOptions: const FileOptions(upsert: true),
      );

      return client.storage.from('products').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading product image: $e');
      // Jika gagal upload ke cloud, simpan lokal saja sebagai cadangan
      return await FileStorageService.saveProductImage(_imageFile!);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _skuCtrl,
      _barcodeCtrl,
      _brandCtrl,
      _motorTypeCtrl,
      _costPriceCtrl,
      _sellPriceCtrl,
      _wholesalePriceCtrl,
      _stockQtyCtrl,
      _stockMinCtrl,
      _unitCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);

      // 1. Upload ke Supabase Storage
      final finalImagePath = await _uploadProductImage(_nameCtrl.text);

      final companion = ProductsCompanion(
        id: _isEditing ? Value(widget.productId!) : const Value.absent(),
        name: Value(_nameCtrl.text.trim()),
        sku: Value.absentIfNull(
          _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        ),
        barcode: Value.absentIfNull(
          _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        ),
        categoryId: Value(_selectedCategoryId),
        brand: Value.absentIfNull(
          _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        ),
        motorType: Value.absentIfNull(
          _motorTypeCtrl.text.trim().isEmpty ? null : _motorTypeCtrl.text.trim(),
        ),
        costPrice: Value(double.tryParse(_costPriceCtrl.text) ?? 0),
        sellPrice: Value(double.tryParse(_sellPriceCtrl.text) ?? 0),
        sellPriceWholesale: Value.absentIfNull(
          _wholesalePriceCtrl.text.isEmpty
              ? null
              : double.tryParse(_wholesalePriceCtrl.text),
        ),
        stockQty: Value(int.tryParse(_stockQtyCtrl.text) ?? 0),
        stockMin: Value(int.tryParse(_stockMinCtrl.text) ?? 5),
        unit: Value(_unitCtrl.text.trim()),
        imageUrl: Value.absentIfNull(finalImagePath),
        updatedAt: Value(DateTime.now()),
      );

      int id;
      if (_isEditing) {
        id = widget.productId!;
        await db.updateProduct(companion);
      } else {
        id = await db.insertProduct(companion);
      }

      // Enqueue sync
      final syncService = ref.read(syncServiceProvider);
      await syncService.enqueue(
        tableName: 'products',
        recordId: id,
        operation: _isEditing ? 'update' : 'create',
        data: {
          'id': id,
          'name': _nameCtrl.text.trim(),
          'sku': _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
          'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
          'category_id': _selectedCategoryId,
          'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          'motor_type': _motorTypeCtrl.text.trim().isEmpty ? null : _motorTypeCtrl.text.trim(),
          'cost_price': double.tryParse(_costPriceCtrl.text) ?? 0,
          'sell_price': double.tryParse(_sellPriceCtrl.text) ?? 0,
          'sell_price_wholesale': _wholesalePriceCtrl.text.isEmpty ? null : double.tryParse(_wholesalePriceCtrl.text),
          'stock_qty': int.tryParse(_stockQtyCtrl.text) ?? 0,
          'stock_min': int.tryParse(_stockMinCtrl.text) ?? 5,
          'unit': _unitCtrl.text.trim(),
          'image_url': finalImagePath,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      ref.invalidate(productsProvider);
      if (_isEditing) {
        ref.invalidate(productDetailProvider(widget.productId!));
      }
      
      if (mounted) {
        AppToast.show(
          context, 
          _isEditing ? 'Produk diperbarui' : 'Produk ditambahkan',
          type: ToastType.success
        );
        context.go('/products');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Produk' : 'Tambah Produk'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => context.go('/products'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image Picker Section
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _imagePath!.startsWith('http') 
                            ? CachedNetworkImage(
                                imageUrl: _imagePath!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => const Icon(Icons.error_rounded),
                              )
                            : Image.file(
                                File(_imagePath!),
                                fit: BoxFit.cover,
                              ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tambah Foto',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                              ),
                            ),
                            ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Informasi Dasar'),
            _field(
              _nameCtrl,
              'Nama Produk *',
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            Row(
              children: [
                Expanded(child: _field(_skuCtrl, 'SKU')),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _barcodeCtrl,
                    'Barcode',
                    suffix: IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      onPressed: () async {
                        final code = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BarcodeScannerDialog(),
                          ),
                        );
                        if (code != null) {
                          setState(() => _barcodeCtrl.text = code);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            // Kategori dropdown
            categories.when(
              data: (cats) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: cats
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
            _field(_brandCtrl, 'Merek'),
            _field(_motorTypeCtrl, 'Tipe Motor'),

            const SizedBox(height: 8),
            _sectionTitle('Harga'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _costPriceCtrl,
                    'Harga Beli *',
                    keyboard: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Wajib' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _sellPriceCtrl,
                    'Harga Jual *',
                    keyboard: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Wajib' : null,
                  ),
                ),
              ],
            ),
            _field(
              _wholesalePriceCtrl,
              'Harga Grosir (opsional)',
              keyboard: TextInputType.number,
            ),

            const SizedBox(height: 8),
            _sectionTitle('Stok'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _stockQtyCtrl,
                    'Stok Awal',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _stockMinCtrl,
                    'Stok Minimum',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _field(_unitCtrl, 'Satuan')),
              ],
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Simpan Perubahan' : 'Tambah Produk'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(labelText: label, suffixIcon: suffix),
      ),
    );
  }
}
