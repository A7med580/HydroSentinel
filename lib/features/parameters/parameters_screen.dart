import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_styles.dart';
import '../../services/state_provider.dart';
import '../../models/chemistry_models.dart';
import '../../services/excel_service.dart';
import '../../services/calculation_engine.dart';

class ParametersScreen extends ConsumerWidget {
  const ParametersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WATER CHEMISTRY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () => _showManualEntryDialog(context, ref),
            tooltip: 'Virtual Entry',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _handleFileUpload(context, ref),
            tooltip: 'Upload Excel',
          ),
        ],
      ),
      body: state.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppStyles.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.coolingTowerData != null) ...[
                    _buildSectionHeader('COOLING TOWER (ENTRY)'),
                    _buildParameterGrid([
                      state.coolingTowerData!.ph,
                      state.coolingTowerData!.alkalinity,
                      state.coolingTowerData!.conductivity,
                      state.coolingTowerData!.totalHardness,
                      state.coolingTowerData!.chloride,
                      state.coolingTowerData!.zinc,
                      state.coolingTowerData!.iron,
                      state.coolingTowerData!.phosphates,
                    ]),
                    const SizedBox(height: AppStyles.paddingL),
                  ],
                  if (state.roData != null) ...[
                    _buildSectionHeader('REVERSE OSMOSIS (RO)'),
                    _buildParameterGrid([
                      state.roData!.freeChlorine,
                      state.roData!.silica,
                      state.roData!.roConductivity,
                    ]),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppStyles.paddingS),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildParameterGrid(List<WaterParameter> parameters) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: AppStyles.paddingS,
        mainAxisSpacing: AppStyles.paddingS,
      ),
      itemCount: parameters.length,
      itemBuilder: (context, index) => _buildParameterCard(parameters[index]),
    );
  }

  Widget _buildParameterCard(WaterParameter param) {
    Color statusColor = _getQualityColor(param.quality);
    
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(param.name, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                param.value.toStringAsFixed(param.value < 1 ? 2 : 1),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
              ),
              const SizedBox(width: 4),
              Text(param.unit, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          if (param.optimalMin != null || param.optimalMax != null)
            Text(
              'Range: ${param.optimalMin ?? 0}–${param.optimalMax ?? '∞'}',
              style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Color _getQualityColor(DataQuality quality) {
    switch (quality) {
      case DataQuality.good: return AppColors.riskLow;
      case DataQuality.warning: return AppColors.riskMedium;
      case DataQuality.suspect: return AppColors.riskHigh;
      case DataQuality.invalid: return AppColors.riskCritical;
    }
  }

  Future<void> _handleFileUpload(BuildContext context, WidgetRef ref) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      try {
        final data = await ExcelService.parseExcel(result.files.single.path!);
        if (!context.mounted) return;
        ref.read(systemProvider.notifier).updateData(
          data['coolingTower'] as CoolingTowerData?,
          data['ro'] as ROData?,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data updated successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing Excel: $e')),
        );
      }
    }
  }

  void _showManualEntryDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(systemProvider);
    
    // Controllers for CT parameters
    final phController = TextEditingController(text: state.coolingTowerData?.ph.value.toString() ?? '7.8');
    final alkController = TextEditingController(text: state.coolingTowerData?.alkalinity.value.toString() ?? '250');
    final condController = TextEditingController(text: state.coolingTowerData?.conductivity.value.toString() ?? '2400');
    final hardController = TextEditingController(text: state.coolingTowerData?.totalHardness.value.toString() ?? '320');
    final clController = TextEditingController(text: state.coolingTowerData?.chloride.value.toString() ?? '450');
    final zincController = TextEditingController(text: state.coolingTowerData?.zinc.value.toString() ?? '1.2');
    final ironController = TextEditingController(text: state.coolingTowerData?.iron.value.toString() ?? '0.1');
    final phosController = TextEditingController(text: state.coolingTowerData?.phosphates.value.toString() ?? '8.0');

    // Controllers for RO parameters
    final freeClController = TextEditingController(text: state.roData?.freeChlorine.value.toString() ?? '0.02');
    final silicaController = TextEditingController(text: state.roData?.silica.value.toString() ?? '45.0');
    final roCondController = TextEditingController(text: state.roData?.roConductivity.value.toString() ?? '15.0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('VIRTUAL DATA ENTRY (Acqua Guard Standard)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogHeading('COOLING TOWER (ENTRY)'),
                _buildEntryField('pH Level', phController),
                _buildEntryField('Alkalinity (mg/L)', alkController),
                _buildEntryField('Conductivity (uS/cm)', condController),
                _buildEntryField('Total Hardness (mg/L)', hardController),
                _buildEntryField('Chloride (mg/L)', clController),
                _buildEntryField('Zinc (mg/L)', zincController),
                _buildEntryField('Iron (mg/L)', ironController),
                _buildEntryField('Phosphates (mg/L)', phosController),
                const SizedBox(height: 16),
                _buildDialogHeading('REVERSE OSMOSIS (RO)'),
                _buildEntryField('Free Chlorine (mg/L)', freeClController),
                _buildEntryField('Silica (mg/L)', silicaController),
                _buildEntryField('RO Conductivity (uS/cm)', roCondController),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final ct = CoolingTowerData(
                ph: WaterParameter(
                  name: 'pH', 
                  value: double.tryParse(phController.text) ?? 0, 
                  unit: 'pH',
                  optimalMin: 7.0, optimalMax: 8.5,
                  quality: CalculationEngine.validateParameter(double.tryParse(phController.text) ?? 0, 7.0, 8.5),
                ),
                alkalinity: WaterParameter(
                  name: 'Alkalinity', 
                  value: double.tryParse(alkController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 100, optimalMax: 500,
                  quality: CalculationEngine.validateParameter(double.tryParse(alkController.text) ?? 0, 100, 500),
                ),
                conductivity: WaterParameter(
                  name: 'Conductivity', 
                  value: double.tryParse(condController.text) ?? 0, 
                  unit: 'µS/cm',
                  optimalMin: 500, optimalMax: 3000,
                  quality: CalculationEngine.validateParameter(double.tryParse(condController.text) ?? 0, 500, 3000),
                ),
                totalHardness: WaterParameter(
                  name: 'Total Hardness', 
                  value: double.tryParse(hardController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 50, optimalMax: 400,
                  quality: CalculationEngine.validateParameter(double.tryParse(hardController.text) ?? 0, 50, 400),
                ),
                chloride: WaterParameter(
                  name: 'Chloride', 
                  value: double.tryParse(clController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 0, optimalMax: 250,
                  quality: CalculationEngine.validateParameter(double.tryParse(clController.text) ?? 0, 0, 250),
                ),
                zinc: WaterParameter(
                  name: 'Zinc', 
                  value: double.tryParse(zincController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 0.5, optimalMax: 2.0,
                  quality: CalculationEngine.validateParameter(double.tryParse(zincController.text) ?? 0, 0.5, 2.0),
                ),
                iron: WaterParameter(
                  name: 'Iron', 
                  value: double.tryParse(ironController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 0, optimalMax: 0.5,
                  quality: CalculationEngine.validateParameter(double.tryParse(ironController.text) ?? 0, 0, 0.5),
                ),
                phosphates: WaterParameter(
                  name: 'Phosphates', 
                  value: double.tryParse(phosController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 5, optimalMax: 15,
                  quality: CalculationEngine.validateParameter(double.tryParse(phosController.text) ?? 0, 5, 15),
                ),
                timestamp: DateTime.now(),
              );

              final ro = ROData(
                freeChlorine: WaterParameter(
                  name: 'Free Chlorine', 
                  value: double.tryParse(freeClController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 0, optimalMax: 0.1,
                  quality: CalculationEngine.validateParameter(double.tryParse(freeClController.text) ?? 0, 0, 0.1),
                ),
                silica: WaterParameter(
                  name: 'Silica', 
                  value: double.tryParse(silicaController.text) ?? 0, 
                  unit: 'ppm',
                  optimalMin: 0, optimalMax: 150,
                  quality: CalculationEngine.validateParameter(double.tryParse(silicaController.text) ?? 0, 0, 150),
                ),
                roConductivity: WaterParameter(
                  name: 'RO Conductivity', 
                  value: double.tryParse(roCondController.text) ?? 0, 
                  unit: 'µS/cm',
                  optimalMin: 0, optimalMax: 50,
                  quality: CalculationEngine.validateParameter(double.tryParse(roCondController.text) ?? 0, 0, 50),
                ),
                timestamp: DateTime.now(),
              );

              ref.read(systemProvider.notifier).updateData(ct, ro);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Virtual data applied successfully')));
            },
            child: const Text('APPLY VIRTUAL DATA', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildEntryField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}
