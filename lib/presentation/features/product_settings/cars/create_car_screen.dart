import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/car_api.dart';
import '../../../../models/cars.dart';
import '../../../provider/cars_provider.dart';

/// Create Car Screen
/// Form for creating new cars with brand, name, models, and versions
/// Converted from KMP's CreateCarScreen.kt
class CreateCarScreen extends StatefulWidget {
  const CreateCarScreen({super.key});

  @override
  State<CreateCarScreen> createState() => _CreateCarScreenState();
}

class _CreateCarScreenState extends State<CreateCarScreen> {
  // Form state
  int _selectedBrandId = -1;
  String _selectedBrandName = 'Select Brand';
  int _selectedNameId = -1;
  String _selectedNameName = 'Select Name';
  final List<CarModelAndVersion> _modelAndVersionList = [];


  // Text controllers
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _carNameController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  final TextEditingController _versionNameController = TextEditingController();

  // Selected model for adding version
  CarModelAndVersion? _selectedModelForVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CarsProvider>(context, listen: false);
      provider.getAllCarBrands();
    });
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _carNameController.dispose();
    _modelNameController.dispose();
    _versionNameController.dispose();
    super.dispose();
  }


  bool _hasChanges() {
    return _selectedBrandId != -1 ||
        _selectedNameId != -1 ||
        _modelAndVersionList.isNotEmpty ||
        _brandNameController.text.isNotEmpty ||
        _carNameController.text.isNotEmpty;
  }

  void _handleBrandSelected(Brand brand) {
    setState(() {
      _selectedBrandId = brand.id;
      _selectedBrandName = brand.brandName;
      _selectedNameId = -1;
      _selectedNameName = 'Select Name';
      _modelAndVersionList.clear();
    });
    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider.getCarNames(brand.id);
  }

  void _handleNameSelected(Name name) {
    setState(() {
      _selectedNameId = name.id;
      _selectedNameName = name.carName;
      _modelAndVersionList.clear();
    });
    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider.getCarModels(brandId: _selectedBrandId, nameId: name.id);
  }

  Future<void> _handleAddBrand() async {
    final brandName = _brandNameController.text.trim();
    if (brandName.isEmpty) {
      _showError('Please enter brand name');
      return;
    }

    final provider = Provider.of<CarsProvider>(context, listen: false);
    final exists = await provider.checkCarBrandExist(brandName);
    if (exists) {
      _showError('Brand already exists');
      return;
    }

    final result = await provider.createCarBrand(brandName);
    result.fold(
      (failure) {
        _showError(failure.message);
      },
      (brand) {
        setState(() {
          _selectedBrandId = brand.id;
          _selectedBrandName = brand.brandName;
          _brandNameController.clear();
        });
        Navigator.pop(context);
      },
    );
  }

  Future<void> _handleAddName() async {
    if (_selectedBrandId == -1) {
      _showError('Please select a brand first');
      return;
    }

    final carName = _carNameController.text.trim();
    if (carName.isEmpty) {
      _showError('Please enter car name');
      return;
    }

    final provider = Provider.of<CarsProvider>(context, listen: false);
    final exists = await provider.checkCarNameExist(carName, _selectedBrandId);
    if (exists) {
      _showError('Car name already exists');
      return;
    }

    // Car name will be created via the main createCar API call
    setState(() {
      _selectedNameName = carName;
      _carNameController.clear();
    });
    Navigator.pop(context);
  }

  void _handleAddModel() {
    final modelName = _modelNameController.text.trim();
    if (modelName.isEmpty) {
      _showError('Please enter model name');
      return;
    }

    if (_selectedBrandId == -1 || _selectedNameId == -1) {
      _showError('Please select brand and name first');
      return;
    }

    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider.checkCarModelExist(modelName, _selectedBrandId, _selectedNameId).then((exists) {
      if (exists) {
        _showError('Model already exists');
        return;
      }

      final newModel = Model(
        id: -1,
        carBrandId: _selectedBrandId,
        carNameId: _selectedNameId,
        modelName: modelName,
      );

      setState(() {
        _modelAndVersionList.add(
          CarModelAndVersion(
            carModel: newModel,
            carVersionList: [],
          ),
        );
        _modelNameController.clear();
      });
      Navigator.pop(context);
    });
  }

  void _handleAddVersion() {
    if (_selectedModelForVersion == null) {
      _showError('Please select a model first');
      return;
    }

    final versionName = _versionNameController.text.trim();
    if (versionName.isEmpty) {
      _showError('Please enter version name');
      return;
    }

    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider
        .checkCarVersionExist(
          versionName,
          _selectedBrandId,
          _selectedNameId,
          _selectedModelForVersion!.carModel.id,
        )
        .then((exists) {
      if (exists) {
        _showError('Version already exists');
        return;
      }

      final newVersion = Version(
        id: -1,
        carBrandId: _selectedBrandId,
        carNameId: _selectedNameId,
        carModelId: _selectedModelForVersion!.carModel.id,
        versionName: versionName,
      );

      setState(() {
        final index = _modelAndVersionList.indexOf(_selectedModelForVersion!);
        final updatedModel = _modelAndVersionList[index];
        final updatedVersions = List<Version>.from(updatedModel.carVersionList)..add(newVersion);
        _modelAndVersionList[index] = CarModelAndVersion(
          carModel: updatedModel.carModel,
          carVersionList: updatedVersions,
        );
        _versionNameController.clear();
        _selectedModelForVersion = null;
      });
      Navigator.pop(context);
    });
  }

  void _handleRemoveModel(int index) {
    setState(() {
      _modelAndVersionList.removeAt(index);
    });
  }

  void _handleRemoveVersion(int modelIndex, int versionIndex) {
    setState(() {
      final model = _modelAndVersionList[modelIndex];
      final updatedVersions = List<Version>.from(model.carVersionList)..removeAt(versionIndex);
      _modelAndVersionList[modelIndex] = CarModelAndVersion(
        carModel: model.carModel,
        carVersionList: updatedVersions,
      );
    });
  }

  Future<void> _handleSubmit() async {
    if (_selectedBrandId == -1 && _selectedBrandName == 'Select Brand') {
      _showError('Please select or create a brand');
      return;
    }

    if (_selectedNameId == -1 && _selectedNameName == 'Select Name') {
      _showError('Please select or create a car name');
      return;
    }

    final brandName = _selectedBrandId == -1 ? _selectedBrandName : '';
    final carName = _selectedNameId == -1 ? _selectedNameName : '';

    final provider = Provider.of<CarsProvider>(context, listen: false);
    final result = await provider.createCar(
      carBrandId: _selectedBrandId,
      brandName: brandName,
      carNameId: _selectedNameId,
      carName: carName,
      carModels: _modelAndVersionList,
    );

    result.fold(
      (failure) {
        _showError(failure.message);
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Car created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showBrandBottomSheet() {
    final provider = Provider.of<CarsProvider>(context, listen: false);
    if (provider.brandList.isEmpty && _selectedBrandName == 'Select Brand') {
      _showError('No car brands found');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer<CarsProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            itemCount: provider.brandList.length,
            itemBuilder: (context, index) {
              final brand = provider.brandList[index];
              final isSelected = _selectedBrandId == brand.id;
              return ListTile(
                title: Text(brand.brandName),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  _handleBrandSelected(brand);
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showNameBottomSheet() {
    if (_selectedBrandId == -1) {
      _showError('Please select a brand first');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer<CarsProvider>(
        builder: (context, provider, _) {
          if (provider.nameList.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No car names found'),
            );
          }
          return ListView.builder(
            itemCount: provider.nameList.length,
            itemBuilder: (context, index) {
              final name = provider.nameList[index];
              final isSelected = _selectedNameId == name.id;
              return ListTile(
                title: Text(name.carName),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  _handleNameSelected(name);
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAddBrandDialog() {
    _brandNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Brand Name'),
        content: TextField(
          controller: _brandNameController,
          decoration: const InputDecoration(
            labelText: 'Brand Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAddBrand();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddNameDialog() {
    _carNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Car Name'),
        content: TextField(
          controller: _carNameController,
          decoration: const InputDecoration(
            labelText: 'Car Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAddName();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddModelDialog() {
    _modelNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Model'),
        content: TextField(
          controller: _modelNameController,
          decoration: const InputDecoration(
            labelText: 'Model Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAddModel();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddVersionDialog(CarModelAndVersion model) {
    _versionNameController.clear();
    _selectedModelForVersion = model;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Version'),
        content: TextField(
          controller: _versionNameController,
          decoration: const InputDecoration(
            labelText: 'Version Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _selectedModelForVersion = null;
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAddVersion();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges(),
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop && _hasChanges()) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('Are you sure you want to discard your changes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          if (shouldDiscard == true) {
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Car'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_hasChanges()) {
                final shouldDiscard = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Discard Changes?'),
                    content: const Text('Are you sure you want to discard your changes?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
                if (shouldDiscard == true && context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Consumer<CarsProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Selection
                  _buildSelectableField(
                    label: 'Brand',
                    value: _selectedBrandName,
                    onTap: _showBrandBottomSheet,
                    onAdd: () => _showAddBrandDialog(),
                    enabled: true,
                  ),
                  const SizedBox(height: 16),

                  // Car Name Selection
                  _buildSelectableField(
                    label: 'Car Name',
                    value: _selectedNameName,
                    onTap: _showNameBottomSheet,
                    onAdd: () => _showAddNameDialog(),
                    enabled: _selectedBrandId != -1 || _selectedBrandName != 'Select Brand',
                  ),
                  const SizedBox(height: 24),

                  // Models Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Models',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: (_selectedBrandId != -1 || _selectedBrandName != 'Select Brand') &&
                                (_selectedNameId != -1 || _selectedNameName != 'Select Name')
                            ? () => _showAddModelDialog()
                            : null,
                        tooltip: 'Add Model',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Models List
                  if (_modelAndVersionList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No models added yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._modelAndVersionList.asMap().entries.map((entry) {
                      final index = entry.key;
                      final model = entry.value;
                      return _buildModelCard(model, index);
                    }),

                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Create Car'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Widget _buildSelectableField({
    required String label,
    required String value,
    required VoidCallback onTap,
    required VoidCallback onAdd,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: enabled ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (enabled)
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: onAdd,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelCard(CarModelAndVersion model, int modelIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    model.carModel.modelName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _showAddVersionDialog(model),
                      tooltip: 'Add Version',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _handleRemoveModel(modelIndex),
                      tooltip: 'Remove Model',
                    ),
                  ],
                ),
              ],
            ),
            if (model.carVersionList.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Versions:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              ...model.carVersionList.asMap().entries.map((entry) {
                final versionIndex = entry.key;
                final version = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(version.versionName),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _handleRemoveVersion(modelIndex, versionIndex),
                        tooltip: 'Remove Version',
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
