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
      _selectedBrandId = brand.carBrandId;
      _selectedBrandName = brand.brandName;
      _selectedNameId = -1;
      _selectedNameName = 'Select Name';
      _modelAndVersionList.clear();
    });
    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider.getCarNames(brand.carBrandId);
  }

  void _handleNameSelected(Name name) {
    setState(() {
      _selectedNameId = name.carNameId;
      _selectedNameName = name.carName;
      _modelAndVersionList.clear();
    });
    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider.getCarModels(brandId: _selectedBrandId, nameId: name.carNameId);
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

    // Store locally (no API call) - will be created via main createCar API call
    // Matches KMP's behavior: carBrandId = -1, carBrandSt = name (line 379-380)
    setState(() {
      _selectedBrandId = -1; // Mark as new (not selected)
      _selectedBrandName = brandName; // Store brand name string
      _selectedNameId = -1; // Reset name selection
      _selectedNameName = 'Select Name'; // Reset name display
      _modelAndVersionList.clear(); // Clear models when brand changes
      _brandNameController.clear();
    });
    // Navigator.pop(context);
  }

  Future<void> _handleAddName() async {
    if (_selectedBrandId == -1 && _selectedBrandName == 'Select Brand') {
      _showError('Please select or create a brand first');
      return;
    }

    final carName = _carNameController.text.trim();
    if (carName.isEmpty) {
      _showError('Please enter car name');
      return;
    }

    final provider = Provider.of<CarsProvider>(context, listen: false);
    // Check existence only if brand is selected (has valid ID)
    // If brand is new (ID = -1), skip existence check (will be checked by backend)
    if (_selectedBrandId != -1) {
      final exists = await provider.checkCarNameExist(carName, _selectedBrandId);
      if (exists) {
        _showError('Car name already exists');
        return;
      }
    }

    // Store locally (no API call) - will be created via main createCar API call
    // Matches KMP's behavior: carNameId = -1, carNameSt = name (line 397-398)
    setState(() {
      _selectedNameId = -1; // Mark as new (not selected)
      _selectedNameName = carName; // Store car name string
      _modelAndVersionList.clear(); // Clear models when name changes
      _carNameController.clear();
    });
    // Navigator.pop(context);
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
          _selectedModelForVersion!.carModel.carModelId,
        )
        .then((exists) {
      if (exists) {
        _showError('Version already exists');
        return;
      }

      final newVersion = Version(
        carVersionId: -1,
        carBrandId: _selectedBrandId,
        carNameId: _selectedNameId,
        carModelId: _selectedModelForVersion!.carModel.carModelId,
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

    // Always send brand_name and car_name strings (matches KMP's createParams line 233, 235)
    // KMP always sends the name strings, even when IDs are selected
    final brandName = _selectedBrandName;
    final carName = _selectedNameName;

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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      context: context,
      builder: (context) => Consumer<CarsProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            itemCount: provider.brandList.length,
            itemBuilder: (context, index) {
              final brand = provider.brandList[index];
              final isSelected = _selectedBrandId == brand.carBrandId;
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
              final isSelected = _selectedNameId == name.carNameId;
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
    // Check if brand and name are set (not default placeholders)
    // IDs can be -1 if brand/name were created (not selected)
    // Matches KMP: passes carBrandId and carNameId which can be -1 (line 467-468)
    if (_selectedBrandName == 'Select Brand' || _selectedNameName == 'Select Name') {
      _showError('Please select or create brand and name first');
      return;
    }

    // Load models only if both brand and name have valid IDs (selected, not created)
    // If IDs are -1 (created), getCarModels will return empty list (handled in provider)
    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider.getCarModels(brandId: _selectedBrandId, nameId: _selectedNameId);

    showDialog(
      context: context,
      builder: (context) => _AddModelDialog(
        brandId: _selectedBrandId, // Can be -1 if brand was created
        nameId: _selectedNameId, // Can be -1 if name was created
        onConfirm: (carModelAndVersion) {
          // Check if model name already exists in list
          final modelNameExists = _modelAndVersionList.any(
            (item) => item.carModel.modelName == carModelAndVersion.carModel.modelName,
          );
          if (modelNameExists) {
            _showError('Model Name already added');
            return;
          }

          setState(() {
            _modelAndVersionList.add(carModelAndVersion);
          });
          Navigator.pop(context);
        },
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

/// Add Model Dialog
/// Matches KMP's AddModelDialog behavior
/// Allows selecting existing model OR typing new model name
/// Shows version field after model is selected/typed
/// Allows adding multiple versions before closing
class _AddModelDialog extends StatefulWidget {
  final int brandId;
  final int nameId;
  final Function(CarModelAndVersion) onConfirm;

  const _AddModelDialog({
    required this.brandId,
    required this.nameId,
    required this.onConfirm,
  });

  @override
  State<_AddModelDialog> createState() => _AddModelDialogState();
}

class _AddModelDialogState extends State<_AddModelDialog> {
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();

  bool _isSelectModel = true; // true = select mode, false = type mode
  int _selectedModelId = -1;
  Model? _selectedModel;
  final List<Version> _versionList = [];
  final List<String> _versionNameList = [];

  @override
  void initState() {
    super.initState();
    // Load models on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CarsProvider>(context, listen: false);
      provider.getCarModels(brandId: widget.brandId, nameId: widget.nameId);
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  bool _canShowVersionField() {
    // Show version field if:
    // - Model is selected (has valid ID) OR
    // - Model name is typed (not empty)
    return (_isSelectModel && _selectedModelId > -1) ||
        (!_isSelectModel && _modelController.text.isNotEmpty);
  }

  void _handleAddVersion() {
    final versionName = _versionController.text.trim();
    if (versionName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter version name')),
      );
      return;
    }

    if (_versionNameList.contains(versionName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already added')),
      );
      return;
    }

    final provider = Provider.of<CarsProvider>(context, listen: false);
    final modelId = _selectedModelId > -1 ? _selectedModelId : -1;

    // Check if version exists only if:
    // 1. Model ID is valid (selected existing model) AND
    // 2. Brand and name IDs are valid (selected, not created)
    // If brand/name IDs are -1 (created), skip existence check (they don't exist in DB yet)
    if (modelId > -1 && widget.brandId > -1 && widget.nameId > -1) {
      // Check if version exists in database
      provider
          .checkCarVersionExist(
            versionName,
            widget.brandId,
            widget.nameId,
            modelId,
          )
          .then((exists) {
        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already exist')),
          );
        } else {
          _addVersionToList(versionName, modelId);
        }
      });
    } else {
      // New model or new brand/name, no need to check database
      // Matches KMP: when brandId, nameId, or modelId is -1, skip existence check
      _addVersionToList(versionName, modelId);
    }
  }

  void _addVersionToList(String versionName, int modelId) {
    setState(() {
      final newVersion = Version(
        id: -1,
        carBrandId: widget.brandId,
        carNameId: widget.nameId,
        carModelId: modelId,
        versionName: versionName,
      );
      _versionList.add(newVersion);
      _versionNameList.add(versionName);
      _versionController.clear();
    });
  }

  void _handleRemoveVersion(int index) {
    setState(() {
      _versionNameList.removeAt(index);
      _versionList.removeAt(index);
    });
  }

  void _handleConfirm() {
    final modelName = _modelController.text.trim();

    if (_isSelectModel && _selectedModelId == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or enter model name')),
      );
      return;
    }

    if (!_isSelectModel && modelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter model name')),
      );
      return;
    }

    if (_selectedModelId > -1 && _versionList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add versions')),
      );
      return;
    }

    final provider = Provider.of<CarsProvider>(context, listen: false);

    if (_selectedModelId == -1) {
      // New model - check if exists only if brand and name IDs are valid (selected, not created)
      // If brand/name IDs are -1 (created), skip existence check (they don't exist in DB yet)
      if (widget.brandId > -1 && widget.nameId > -1) {
        provider
            .checkCarModelExist(modelName, widget.brandId, widget.nameId)
            .then((exists) {
          if (exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Already exist')),
            );
          } else {
            _createModelAndVersion(modelName);
          }
        });
      } else {
        // Brand or name is new (ID = -1), skip existence check
        // Matches KMP: when brandId or nameId is -1, model check is skipped
        _createModelAndVersion(modelName);
      }
    } else {
      // Existing model
      _createModelAndVersion(_selectedModel!.modelName);
    }
  }

  void _createModelAndVersion(String modelName) {
    final carModel = Model(
      carModelId: _selectedModelId > -1 ? _selectedModelId : -1,
      carBrandId: widget.brandId,
      carNameId: widget.nameId,
      modelName: modelName,
    );

    final carModelAndVersion = CarModelAndVersion(
      carModel: carModel,
      carVersionList: _versionList,
    );

    widget.onConfirm(carModelAndVersion);
    // Navigator.pop(context);
  }

  void _showModelSelectionDialog() {
    final provider = Provider.of<CarsProvider>(context, listen: false);
    if (provider.modelList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model not found')),
      );
      setState(() {
        _isSelectModel = false;
      });
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Model'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.modelList.length,
            itemBuilder: (context, index) {
              final model = provider.modelList[index];
              final isSelected = _selectedModelId == model.carModelId;
              return ListTile(
                title: Text(model.modelName),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() {
                    _selectedModelId = model.carModelId;
                    _selectedModel = model;
                    _modelController.text = model.modelName;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarsProvider>(
      builder: (context, provider, _) {
        return AlertDialog(
          title: const Text('Add Model'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Model field: Select OR Type
                if (_isSelectModel)
                  // Select mode: Clickable box
                  InkWell(
                    onTap: _showModelSelectionDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedModelId > -1
                                  ? _modelController.text
                                  : 'Select Model',
                              style: TextStyle(
                                color: _selectedModelId > -1 ? Colors.black : Colors.grey,
                              ),
                            ),
                          ),
                          if (_versionList.isEmpty)
                            IconButton(
                              icon: Icon(
                                _selectedModelId > -1 ? Icons.close : Icons.edit,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _modelController.clear();
                                  _selectedModelId = -1;
                                  _selectedModel = null;
                                  _isSelectModel = false;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  // Type mode: Text field
                  TextField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: 'Enter model',
                      border: const OutlineInputBorder(),
                      suffixIcon: provider.modelList.isNotEmpty && _versionList.isEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _modelController.clear();
                                  _selectedModelId = -1;
                                  _selectedModel = null;
                                  _isSelectModel = true;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        // Trigger rebuild to show/hide version field
                      });
                    },
                  ),
                // Version field (appears after model is selected/typed)
                if (_canShowVersionField()) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _versionController,
                    decoration: InputDecoration(
                      labelText: 'Enter Version',
                      border: const OutlineInputBorder(),
                      suffixIcon: _versionController.text.trim().isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _handleAddVersion,
                              tooltip: 'Add Version',
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        // Trigger rebuild to show/hide add button
                      });
                    },
                    onSubmitted: (_) {
                      if (_versionController.text.trim().isNotEmpty) {
                        _handleAddVersion();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Versions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Versions list
                  Container(
                    constraints: const BoxConstraints(minHeight: 100, maxHeight: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _versionList.isEmpty
                        ? const Center(
                            child: Text('No version added'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _versionList.length,
                            itemBuilder: (context, index) {
                              final version = _versionList[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(version.versionName),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _handleRemoveVersion(index),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if ((_selectedModelId > -1 && _versionList.isNotEmpty) ||
                (_selectedModelId == -1 && _modelController.text.isNotEmpty))
              TextButton(
                onPressed: _handleConfirm,
                child: const Text('Add'),
              ),
          ],
        );
      },
    );
  }
}
