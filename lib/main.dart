import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProductApp());
}

class ProductApp extends StatelessWidget {
  const ProductApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Autumn Product Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const ProductPage(),
    );
  }
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('products');
  late final _productStream = _products.snapshots(includeMetadataChanges: true);
  final _search = TextEditingController();
  final _minimum = TextEditingController();
  final _maximum = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  String? _rangeError() {
    final minText = _minimum.text.trim();
    final maxText = _maximum.text.trim();
    final min = minText.isEmpty ? null : double.tryParse(minText);
    final max = maxText.isEmpty ? null : double.tryParse(maxText);
    if (minText.isNotEmpty && (min == null || !min.isFinite || min < 0)) {
      return 'Minimum must be a valid number of zero or more.';
    }
    if (maxText.isNotEmpty && (max == null || !max.isFinite || max < 0)) {
      return 'Maximum must be a valid number of zero or more.';
    }
    if (min != null && max != null && min > max) {
      return 'Minimum cannot be greater than maximum.';
    }
    return null;
  }

  void _reset() {
    _search.clear();
    _minimum.clear();
    _maximum.clear();
    setState(() {});
  }

  void _openEditor([QueryDocumentSnapshot<Map<String, dynamic>>? document]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ProductEditor(products: _products, document: document),
    );
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "$name"?\nDocument ID: $id'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _products.doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "$name" ($id).')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed (${error.code}). Check permissions or connection.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _rangeError();
    final min = _minimum.text.trim().isEmpty
        ? null
        : double.tryParse(_minimum.text.trim());
    final max = _maximum.text.trim().isEmpty
        ? null
        : double.tryParse(_maximum.text.trim());
    final searchTerm = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Autumn Product Manager')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search product names',
                    hintText: 'Try cEdAr or tea',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minimum,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Minimum price',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maximum,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Maximum price',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Products could not load. Check internet, Firebase project, and Firestore rules.'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allDocs = snapshot.data!.docs;
                if (allDocs.isEmpty) {
                  return const Center(child: Text('No products yet. Tap + to add one.'));
                }
                if (error != null) {
                  return const Center(child: Text('Correct the price filters to show products.'));
                }
                final matches = allDocs.where((doc) {
                  final data = doc.data();
                  final name = data['name'];
                  final price = data['price'];
                  if (name is! String || name.trim().isEmpty ||
                      price is! num || !price.isFinite || price < 0) {
                    // Keep malformed records visible when the filters are clear.
                    return searchTerm.isEmpty && min == null && max == null;
                  }
                  return name.trim().toLowerCase().contains(searchTerm) &&
                      (min == null || price >= min) &&
                      (max == null || price <= max);
                }).toList();
                final fromCache = snapshot.data!.metadata.isFromCache;
                final pending = snapshot.data!.metadata.hasPendingWrites;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Text('${matches.length} of ${allDocs.length} products'),
                          const Spacer(),
                          Text(
                            pending ? 'Pending writes' : (fromCache ? 'Cached' : 'Server'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: matches.isEmpty
                          ? const Center(child: Text('No products found'))
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final doc = matches[index];
                                final data = doc.data();
                                final name = data['name'];
                                final price = data['price'];
                                if (name is! String || name.trim().isEmpty ||
                                    price is! num || !price.isFinite || price < 0) {
                                  return Card(
                                    child: ListTile(
                                      title: const Text('Invalid product data'),
                                      subtitle: Text('ID: ${doc.id}\nCheck name and price types in Firestore.'),
                                      isThreeLine: true,
                                    ),
                                  );
                                }
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  child: ListTile(
                                    title: Text(name),
                                    subtitle: Text('\$${price.toStringAsFixed(2)}\nID: ${doc.id}'),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit product',
                                          onPressed: () => _openEditor(doc),
                                          icon: const Icon(Icons.edit),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete product',
                                          onPressed: () => _deleteProduct(doc.id, name),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Add product',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.products, this.document});

  final CollectionReference<Map<String, dynamic>> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.document?.data()['name'] is String
        ? widget.document!.data()['name'] as String
        : '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.document?.data()['price']?.toString() ?? '',
  );
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final data = <String, Object>{
      'name': _name.text.trim(),
      'price': double.parse(_price.text.trim()),
    };
    try {
      if (widget.document == null) {
        await widget.products.add(data);
      } else {
        await widget.products.doc(widget.document!.id).update(data);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed (${error.code}). Check internet and Firestore rules.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.document == null ? 'Add product' : 'Edit product',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a product name.'
                        : null,
                  ),
                  TextFormField(
                    controller: _price,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      return amount == null || !amount.isFinite || amount < 0
                          ? 'Enter a valid price of zero or more.'
                          : null;
                    },
                  ),
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_saveError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Saving to Firestore. Reconnect if offline.'),
                    ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
