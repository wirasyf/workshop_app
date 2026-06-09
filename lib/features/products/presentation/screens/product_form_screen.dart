import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dnd_markasban_app/features/pos/presentation/widgets/barcode_scanner_dialog.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/utils/app_toast.dart';
import 'package:uuid/uuid.dart';
import '../providers/product_provider.dart';
import '../../data/product_repository.dart';
import '../../../../core/models/product_model.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
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
  final _workerPriceCtrl = TextEditingController();
  final _stockQtyCtrl = TextEditingController();
  final _stockMinCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  String? _selectedCategoryId;
  String? _imagePath;
  File? _imageFile;
  bool _isLoading = false;
  DateTime? _originalCreatedAt;
  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final repo = ref.read(productRepositoryProvider);
      final product = await repo.getProductById(widget.productId!).first;
      if (product != null) {
        _nameCtrl.text = product.name;
        _skuCtrl.text = product.sku ?? '';
        _barcodeCtrl.text = product.barcode ?? '';
        _brandCtrl.text = product.brand ?? '';
        _motorTypeCtrl.text = product.motorType ?? '';
        _costPriceCtrl.text = CurrencyFormatter.formatNumber(product.costPrice);
        _sellPriceCtrl.text = CurrencyFormatter.formatNumber(product.sellPrice);
        _workerPriceCtrl.text = CurrencyFormatter.formatNumber(
          product.workerPrice,
        );
        _stockQtyCtrl.text = product.stockQty.toString();
        _stockMinCtrl.text = product.stockMin.toString();
        _unitCtrl.text = product.unit;
        _selectedCategoryId = product.categoryId;
        _imagePath = product.imageUrl;
        _originalCreatedAt = product.createdAt;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading product: $e');
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
        imageQuality: 40,
        maxWidth: 400,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imagePath = null;
        });
      }
    }
  }

  Future<String?> _uploadProductImage(String productName) async {
    if (_imageFile == null) return _imagePath;
    try {
      // Upload ke Firebase Storage
      return await FileStorageService.saveProductImage(_imageFile!);
    } catch (e) {
      debugPrint('Error uploading product image: $e');
      throw Exception('Gagal mengunggah foto produk: $e');
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
      _workerPriceCtrl,
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
      final repo = ref.read(productRepositoryProvider);
      final finalImagePath = await _uploadProductImage(_nameCtrl.text);
      final uuid = const Uuid();
      final id = _isEditing ? widget.productId! : uuid.v4();

      final product = ProductModel(
        id: id,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        motorType: _motorTypeCtrl.text.trim().isEmpty
            ? null
            : _motorTypeCtrl.text.trim(),
        costPrice: CurrencyFormatter.parse(_costPriceCtrl.text),
        sellPrice: CurrencyFormatter.parse(_sellPriceCtrl.text),
        workerPrice: CurrencyFormatter.parse(_workerPriceCtrl.text),
        stockQty: int.tryParse(_stockQtyCtrl.text) ?? 0,
        stockMin: int.tryParse(_stockMinCtrl.text) ?? 5,
        unit: _unitCtrl.text.trim(),
        imageUrl: finalImagePath,
        updatedAt: DateTime.now(),
        createdAt: _originalCreatedAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await repo.updateProduct(product);
      } else {
        await repo.addProduct(product);
      }

      if (mounted) {
        AppToast.show(
          context,
          _isEditing ? 'Produk diperbarui' : 'Produk ditambahkan',
          type: ToastType.success,
        );
        final from = GoRouterState.of(context).uri.queryParameters['from'];
        context.go(
          widget.productId != null
              ? '/products/${widget.productId}${from == 'dashboard' ? '?from=dashboard' : ''}'
              : '/products${from == 'dashboard' ? '?from=dashboard' : ''}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target = widget.productId != null
        ? '/products/${widget.productId}${from == 'dashboard' ? '?from=dashboard' : ''}'
        : '/products${from == 'dashboard' ? '?from=dashboard' : ''}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(target);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Produk' : 'Tambah Produk'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go(target),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                            child: _imagePath!.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(_imagePath!.split(',').last),
                                    fit: BoxFit.cover,
                                  )
                                : _imagePath!.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: _imagePath!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.error_rounded),
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
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                        ),
                        onPressed: () async {
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BarcodeScannerDialog(),
                            ),
                          );
                          if (code != null)
                            setState(() => _barcodeCtrl.text = code);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              categoriesAsync.when(
                data: (cats) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: cats
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
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
                      prefix: 'Rp ',
                      formatters: [RupiahInputFormatter()],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib';
                        if (CurrencyFormatter.parse(v) <= 0) return 'Harus > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _sellPriceCtrl,
                      'Harga Jual *',
                      keyboard: TextInputType.number,
                      prefix: 'Rp ',
                      formatters: [RupiahInputFormatter()],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib';
                        if (CurrencyFormatter.parse(v) <= 0) return 'Harus > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _workerPriceCtrl,
                      'Harga Karyawan',
                      keyboard: TextInputType.number,
                      prefix: 'Rp ',
                      formatters: [RupiahInputFormatter()],
                    ),
                  ),
                ],
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
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib';
                        if ((int.tryParse(v) ?? -1) < 0) return 'Harus >= 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _stockMinCtrl,
                      'Stok Minimum',
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib';
                        if ((int.tryParse(v) ?? -1) < 0) return 'Harus >= 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _unitCtrl,
                      'Satuan',
                      validator: (v) => v!.isEmpty ? 'Wajib' : null,
                    ),
                  ),
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
    String? prefix,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        validator: validator,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffix,
          prefixText: prefix,
        ),
      ),
    );
  }
}
