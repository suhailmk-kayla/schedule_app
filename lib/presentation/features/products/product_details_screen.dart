import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/presentation/features/products/products_screen.dart';
import '../../provider/products_provider.dart';
import '../../../models/product_api.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Product? _product;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<ProductsProvider>(context, listen: false);
      final p = await provider.loadProductById(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = p;
        _loading = false;
        _error = p == null ? 'Product not found' : null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _buildDetails(context),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final p = _product!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 200,
                width: 200,
                child: ProductImage(url: p.photo)),
              // Container(
              //   width: 96,
              //   height: 96,
              //   decoration: BoxDecoration(
              //     color: Colors.grey.shade200,
              //     borderRadius: BorderRadius.circular(8),
              //   ),
              //   child: const Icon(Icons.image, size: 40, color: Colors.grey),
              // ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('${p.code} • ${p.brand}'),
                    if (p.sub_name.isNotEmpty) Text(p.sub_name),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text('Pricing', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _kv('Price', p.price.toStringAsFixed(2)),
          _kv('MRP', p.mrp.toStringAsFixed(2)),
          _kv('Retail Price', p.retail_price.toStringAsFixed(2)),
          _kv('Fitting Charge', p.fitting_charge.toStringAsFixed(2)),

          const SizedBox(height: 24),
          const Text('Classification', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _kv('Category ID', p.category_id.toString()),
          _kv('Sub Category ID', p.sub_category_id.toString()),
          _kv('Default Supplier ID', p.default_supp_id.toString()),

          const SizedBox(height: 24),
          const Text('Units', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _kv('Base Unit ID', p.base_unit_id.toString()),
          _kv('Default Unit ID', p.default_unit_id.toString()),

          const SizedBox(height: 24),
          if (p.note.isNotEmpty) ...[
            const Text('Note', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(p.note),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
