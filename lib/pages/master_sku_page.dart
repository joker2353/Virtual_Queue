import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/master_sku.dart';
import '../providers/master_sku_provider.dart';
import '../widgets/loading_indicator.dart';

class MasterSKUPage extends StatefulWidget {
  const MasterSKUPage({super.key});

  @override
  State<MasterSKUPage> createState() => _MasterSKUPageState();
}

class _MasterSKUPageState extends State<MasterSKUPage> {
  String _searchQuery = '';
  String _selectedCategory = '';
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<MasterSKUProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<File?> _pickImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        final imageFile = File(pickedImage.path);
        // Validate file size (max 5MB)
        final fileSize = await imageFile.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size must be less than 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
        return imageFile;
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _showAddEditDialog([MasterSKU? sku]) async {
    final nameController = TextEditingController(text: sku?.name);
    final descController = TextEditingController(text: sku?.description);
    final priceController = TextEditingController(
      text: sku?.price?.toString() ?? '',
    );
    final categoryController = TextEditingController(text: sku?.category);
    File? selectedImageFile;
    String? currentImageUrl = sku?.imageUrl;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(sku == null ? 'Add New SKU' : 'Edit SKU'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Image preview/upload section
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (selectedImageFile != null)
                                Image.file(
                                  selectedImageFile!,
                                  fit: BoxFit.cover,
                                  width: 200,
                                  height: 200,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                      'Error displaying local image: $error',
                                    );
                                    debugPrint('Stack trace: $stackTrace');
                                    return const Icon(
                                      Icons.error,
                                      color: Colors.red,
                                    );
                                  },
                                )
                              else if (currentImageUrl?.isNotEmpty ?? false)
                                Image.network(
                                  currentImageUrl!,
                                  fit: BoxFit.cover,
                                  width: 200,
                                  height: 200,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                      'Error loading image URL: $error',
                                    );
                                    debugPrint('URL was: $currentImageUrl');
                                    debugPrint('Stack trace: $stackTrace');
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                )
                              else
                                const Icon(
                                  Icons.image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: FloatingActionButton.small(
                                  onPressed: () async {
                                    final pickedFile = await _pickImage();
                                    if (pickedFile != null) {
                                      setState(() {
                                        selectedImageFile = pickedFile;
                                        currentImageUrl = null;
                                      });
                                    }
                                  },
                                  child: const Icon(Icons.edit),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                          ),
                        ),
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: 'Description *',
                          ),
                          maxLines: 2,
                        ),
                        TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price (Optional)',
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        TypeAheadField<String>(
                          suggestionsCallback: (pattern) {
                            return context
                                .read<MasterSKUProvider>()
                                .categories
                                .where(
                                  (category) => category.toLowerCase().contains(
                                    pattern.toLowerCase(),
                                  ),
                                )
                                .toList();
                          },
                          builder: (context, controller, focusNode) {
                            return TextField(
                              controller: categoryController,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                              ),
                            );
                          },
                          itemBuilder: (context, String suggestion) {
                            return ListTile(title: Text(suggestion));
                          },
                          onSelected: (String suggestion) {
                            categoryController.text = suggestion;
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty ||
                            descController.text.isEmpty ||
                            categoryController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please fill in all required fields',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final price =
                            priceController.text.isNotEmpty
                                ? double.tryParse(priceController.text)
                                : null;

                        if (priceController.text.isNotEmpty && price == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid price'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (context) => const Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child: Center(
                                    child: Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 16),
                                            Text('Saving SKU...'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          );

                          if (sku == null) {
                            // Create new SKU
                            await context.read<MasterSKUProvider>().createSKU(
                              name: nameController.text,
                              description: descController.text,
                              price: price,
                              category: categoryController.text,
                              imageFile: selectedImageFile,
                            );
                          } else {
                            // Update existing SKU
                            final updatedSku = sku.copyWith(
                              name: nameController.text,
                              description: descController.text,
                              price: price,
                              category: categoryController.text,
                            );
                            await context.read<MasterSKUProvider>().updateSKU(
                              updatedSku,
                              newImageFile: selectedImageFile,
                            );
                          }

                          if (mounted) {
                            // Close loading indicator
                            Navigator.pop(context);
                            // Close dialog
                            Navigator.pop(context);
                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  sku == null
                                      ? 'SKU created successfully'
                                      : 'SKU updated successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error saving SKU: $e');
                          if (mounted) {
                            // Close loading indicator
                            Navigator.pop(context);
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: 'Dismiss',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                  },
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(sku == null ? 'Add' : 'Update'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master SKU List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search SKUs',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory.isEmpty ? null : _selectedCategory,
                    hint: const Text('Filter by Category'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All Categories'),
                      ),
                      ...context.watch<MasterSKUProvider>().categories.map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged:
                        (value) =>
                            setState(() => _selectedCategory = value ?? ''),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MasterSKU>>(
              stream: context.watch<MasterSKUProvider>().streamSKUs(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: LoadingIndicator());
                }

                final skus =
                    snapshot.data!
                        .where(
                          (sku) =>
                              (_selectedCategory.isEmpty ||
                                  sku.category == _selectedCategory) &&
                              (sku.name.toLowerCase().contains(
                                    _searchQuery.toLowerCase(),
                                  ) ||
                                  sku.description.toLowerCase().contains(
                                    _searchQuery.toLowerCase(),
                                  )),
                        )
                        .toList();

                return DataTable2(
                  columns: const [
                    DataColumn2(label: Text('Image'), size: ColumnSize.S),
                    DataColumn2(label: Text('Name'), size: ColumnSize.L),
                    DataColumn2(label: Text('Category'), size: ColumnSize.M),
                    DataColumn2(label: Text('Price'), size: ColumnSize.S),
                    DataColumn2(label: Text('Actions'), size: ColumnSize.S),
                  ],
                  rows:
                      skus.map((sku) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 50,
                                height: 50,
                                child:
                                    sku.imageUrl != null
                                        ? Image.network(
                                          sku.imageUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return const LoadingIndicator();
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(Icons.error),
                                        )
                                        : const Icon(
                                          Icons.image,
                                          color: Colors.grey,
                                        ),
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(sku.name),
                                  Text(
                                    sku.description,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              onTap: () => _showAddEditDialog(sku),
                            ),
                            DataCell(Text(sku.category)),
                            DataCell(
                              Text(sku.price?.toStringAsFixed(2) ?? '-'),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showAddEditDialog(sku),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text(
                                                'Confirm Delete',
                                              ),
                                              content: const Text(
                                                'Are you sure you want to delete this SKU?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (confirm == true) {
                                        await context
                                            .read<MasterSKUProvider>()
                                            .deleteSKU(sku.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
