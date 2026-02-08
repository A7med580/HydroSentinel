import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart';
import '../../../core/failures.dart';
import '../../auth/domain/user_entity.dart';
import '../domain/factory_repository.dart';
import '../domain/factory_entity.dart';
import '../domain/report_entity.dart';
import '../domain/measurement_v2.dart'; // NEW
import 'storage_service.dart';

// V1 Services
import '../../../services/excel_service.dart';
import '../../../services/calculation_engine.dart';
import '../../../models/chemistry_models.dart';
import '../../../models/assessment_models.dart'; // For CalculatedIndices, RiskAssessment
import '../../../core/services/excel/universal_excel_parser.dart'; // NEW

// V2 Services
import '../../../core/services/excel_parser_v2.dart';
import '../../../core/services/data_merge_service.dart';

class FactoryRepositoryImpl implements FactoryRepository {
  final SupabaseClient supabase;
  final StorageService storageService;

  FactoryRepositoryImpl(this.supabase, this.storageService);

  @override
  Stream<List<FactoryEntity>> watchFactories() {
    return supabase.from('factories').stream(primaryKey: ['id']).map((data) {
      return data.map((json) => FactoryEntity.fromMap(json)).toList();
    });
  }

  @override
  Future<Either<Failure, List<ReportEntity>>> getReportsForFactory(String factoryId) async {
    try {
      final response = await supabase
          .from('reports')
          .select()
          .eq('factory_id', factoryId)
          .order('analyzed_at', ascending: false);
      
      final reports = (response as List).map((json) => ReportEntity.fromMap(json)).toList();
      return Right(reports);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch reports: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> syncWithDrive() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return const Left(AuthFailure('No authenticated user'));
      final email = user.email ?? '';


      // 1. Fetch Factories (Folders) from Storage
      print('DEBUG: Syncing for email: $email');
      final storageObjects = await storageService.listFactories(email);

      if (storageObjects.isEmpty) {
        print('DEBUG: No factories found in storage for $email');
      }

      for (final object in storageObjects) {
        // In Supabase storage, folders often appear as objects with null metadata or ID implies it is a folder?
        // Actually, list returns items. If it's a folder, we treat it as a factory.
        // We will assume any "name" returned at this level is a factory folder.
        if (object.name == null) continue;
        final factoryName = object.name;

        // Skip potential placeholder files if using empty folder marker
        if (factoryName == '.emptyFolderPlaceholder') continue; 
        
        print('DEBUG: Processing factory: $factoryName');

        // 2. Upsert Factory to Supabase DB
        
        final storagePath = 'user_${email.split('@')[0]}/$factoryName';

        try {
          print('DEBUG: Checking existence of $factoryName in DB...');
          final existingFactory = await supabase
              .from('factories')
              .select()
              .eq('user_id', user.id)
              .eq('name', factoryName) // Check by name since we don't have stable IDs in storage
              .maybeSingle();

          String factoryId;
          if (existingFactory == null) {
            print('DEBUG: Inserting new factory: $factoryName');
            final res = await supabase.from('factories').insert({
              'user_id': user.id,
              'name': factoryName,
              'drive_folder_id': storagePath, // Storing path as the ID
              'status': 'good',
              'last_sync_at': DateTime.now().toIso8601String(),
            }).select().single();
            factoryId = res['id'];
            print('DEBUG: Insert success. ID: $factoryId');
          } else {
            print('DEBUG: Updating existing factory: $factoryName');
            factoryId = existingFactory['id'];
            await supabase.from('factories').update({
              'last_sync_at': DateTime.now().toIso8601String(),
               'drive_folder_id': storagePath,
            }).eq('id', factoryId);
          }
          
           // 3. Process Excel Files
          await _processFactoryFiles(factoryId, email, factoryName);

        } catch (e, stack) {
          print('DEBUG: DB Error for $factoryName: $e');
          print(stack);
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Sync failed: $e'));
    }
  }

  Future<void> _processFactoryFiles(String factoryId, String email, String factoryName) async {
    final files = await storageService.listFactoryFiles(email, factoryName);

    // --- PRUNING DISABLED FOR PRODUCTION DEBUGGING ---
    // If storage list fails or RLS hides files, we shouldn't wipe the DB.
    /*
    // 1. Identify all valid file paths currently in storage
    final storageFilePaths = files.map((f) => 
      'user_${email.split('@')[0]}/$factoryName/${f.name}'
    ).toSet();

    // 2. Fetch all report file_ids currently in DB for this factory
    final dbReportsResponse = await supabase
        .from('reports')
        .select('file_id')
        .eq('factory_id', factoryId); 
    
    final dbFileIds = (dbReportsResponse as List).map((e) => e['file_id'] as String).toSet();

    // 3. Find orphans (in DB but not in Storage)
    print('DEBUG: --- PRUNING CHECK ---');
    print('DEBUG: Storage has ${storageFilePaths.length} files: $storageFilePaths');
    // ...
    if (orphans.isNotEmpty) {
       // ... delete ...
    }
    print('DEBUG: --- PRUNING END ---');
    */
    // --- PRUNING END ---

    for (final file in files) {
       // Using file name as ID for duplication check
       // Or better, file path
       final filePath = 'user_${email.split('@')[0]}/$factoryName/${file.name}';
       
      // Check if already analyzed
      final existingReport = await supabase
          .from('reports')
          .select()
          .eq('file_id', filePath) // Using path as file_id
          .maybeSingle();

      // if (existingReport != null) continue; // Skip if already exists force update for now

      // Download & Analyze
      try {
        final bytes = await storageService.downloadFile(email, factoryName, file.name);

        // --- UNIVERSAL PARSER PIPELINE ---
        CoolingTowerData? ctData;
        ROData? roData;
        
        try {
          print('DEBUG: [UniversalParser] Processing file: ${file.name}');
          final result = await UniversalExcelParser.parse(bytes);
          
          ctData = result['coolingTower'] as CoolingTowerData?;
          roData = result['ro'] as ROData?;
          
          if (ctData == null) {
             print('Warning: No Cooling Tower data found in ${file.name}');
             // We could continue, but let's allow partial data (RO only) if valid
          }

          print('DEBUG: [UniversalParser] Success. pH: ${ctData?.ph.value}');
          
        } catch (e, stack) {
          print('DEBUG: [UniversalParser] Error processing file ${file.name}: $e');
          print(stack);
          // If detailed parsing fails, we could potentially suppress or log error,
          // but we shouldn't insert a blank report unless we want to signal failure?
          // For now, let's skip processing this file to avoid bad data.
          continue; 
        }

        if (ctData == null && roData == null) {
           print('DEBUG: File ${file.name} yielded no data.');
           continue;
        }

        // --- V2 PERSISTENCE BRIDGE ---
        // We map the Universal results to MeasurementV2 to keep the V2 table populated.
        try {
           if (ctData != null) {
              final indices = CalculationEngine.calculateIndices(ctData);
              // Calculate Risk? Risk is calculated later for ReportEntity.
              
              final v2Record = MeasurementV2(
                factoryId: factoryId,
                periodType: PeriodType.daily, // Assume daily for now, or detect from filename?
                startDate: ctData.timestamp,
                endDate: ctData.timestamp,
                data: {
                  'ph': ctData.ph.value,
                  'alkalinity': ctData.alkalinity.value,
                  'conductivity': ctData.conductivity.value,
                  'hardness': ctData.totalHardness.value,
                  'chloride': ctData.chloride.value,
                  'zinc': ctData.zinc.value,
                  'iron': ctData.iron.value,
                  'phosphates': ctData.phosphates.value,
                  // RO Data if available
                  if (roData != null) ...{
                    'free_chlorine': roData.freeChlorine.value,
                    'silica': roData.silica.value,
                    'ro_conductivity': roData.roConductivity.value,
                  }
                },
                indices: {
                  'lsi': indices.lsi,
                  'rsi': indices.rsi,
                  'psi': indices.psi,
                },
              );
              
              final mergeService = DataMergeService(supabase);
              await mergeService.mergeMeasurements([v2Record]);
              print('DEBUG: [Universal->V2] Bridged data to measurements_v2 table.');
           }
        } catch (e, stack) {
           print('DEBUG: [V2 Bridge] Failed to save V2 record: $e');
           print(stack);
           // Non-fatal, continue to V1 persistence so UI still works
        }

        // Calculate Risks if CT Data exists
        final indices = ctData != null 
            ? CalculationEngine.calculateIndices(ctData) 
            : CalculatedIndices(
                lsi: 0, rsi: 0, psi: 0, 
                stiffDavis: 0, larsonSkold: 0, coc: 0, 
                adjustedPsi: 0, tdsEstimation: 0, chlorideSulfateRatio: 0,
                timestamp: DateTime.now(),
              );
        final risk = ctData != null 
            ? CalculationEngine.assessRisk(indices, ctData) 
            : RiskAssessment(
                scalingScore: 0, corrosionScore: 0, foulingScore: 0,
                scalingRisk: RiskLevel.low, corrosionRisk: RiskLevel.low, foulingRisk: RiskLevel.low,
                timestamp: DateTime.now(),
              );
        
        // Manual Serialization of CoolingTowerData since no toJson exists
        Map<String, dynamic>? ctJson;
        if (ctData != null) {
          ctJson = {
            'pH': {'value': ctData.ph.value, 'unit': ctData.ph.unit},
            'Alkalinity': {'value': ctData.alkalinity.value, 'unit': ctData.alkalinity.unit},
            'Conductivity': {'value': ctData.conductivity.value, 'unit': ctData.conductivity.unit},
            'Total Hardness': {'value': ctData.totalHardness.value, 'unit': ctData.totalHardness.unit},
            'Chloride': {'value': ctData.chloride.value, 'unit': ctData.chloride.unit},
            'Zinc': {'value': ctData.zinc.value, 'unit': ctData.zinc.unit},
            'Iron': {'value': ctData.iron.value, 'unit': ctData.iron.unit},
            'Phosphates': {'value': ctData.phosphates.value, 'unit': ctData.phosphates.unit},
            'timestamp': ctData.timestamp.toIso8601String(),
          };
        }

        // Serialize RO Data if available
        Map<String, dynamic>? roJson;
        // roData is already extracted above from result['ro']
        if (roData != null) {
           roJson = {
             'Free Chlorine': {'value': roData.freeChlorine.value, 'unit': roData.freeChlorine.unit},
             'Silica': {'value': roData.silica.value, 'unit': roData.silica.unit},
             'RO Conductivity': {'value': roData.roConductivity.value, 'unit': roData.roConductivity.unit},
             'timestamp': roData.timestamp.toIso8601String(),
           };
        }

        // Save to Supabase
        // Check if report exists for this file path
        final existingReport = await supabase
            .from('reports')
            .select('id')
            .eq('file_id', filePath)
            .maybeSingle();

        if (existingReport != null) {
          // Tier 2 Fix: Duplicate Hunter
          // If we found a report but there might be others (clones), delete ALL and then update/re-insert.
          // Or simpler: Update the one we found, and delete any OTHERS.
          print('DEBUG: [Duplicate Hunter] Cleaning clones for $filePath');
          await supabase.from('reports')
              .delete()
              .eq('file_id', filePath)
              .neq('id', existingReport['id']); // Delete everywhere ELSE
          
          // UPDATE
          print('DEBUG: Updating existing report for $filePath');
          await supabase.from('reports').update({
            'factory_id': factoryId,
            'file_name': file.name,
            'risk_scaling': risk.scalingScore,
            'risk_corrosion': risk.corrosionScore,
            'risk_fouling': risk.foulingScore,
            'data': {
              'cooling_tower': ctJson, 
              'reverse_osmosis': roJson,
              'indices': {
                'lsi': indices.lsi,
                'rsi': indices.rsi,
                'psi': indices.psi,
              },
              'risk_scaling': risk.scalingScore,
              'risk_corrosion': risk.corrosionScore,
              'risk_fouling': risk.foulingScore,
            },
            'analyzed_at': DateTime.now().toIso8601String(),
          }).eq('id', existingReport['id']);
        } else {
          // Even if no report found, double check for clones before inserting
          await supabase.from('reports').delete().eq('file_id', filePath);
          
          // INSERT
          print('DEBUG: Inserting new report for $filePath');
          await supabase.from('reports').insert({
            'factory_id': factoryId,
            'file_id': filePath,
            'file_name': file.name,
            'risk_scaling': risk.scalingScore,
            'risk_corrosion': risk.corrosionScore,
            'risk_fouling': risk.foulingScore,
            'data': {
              'cooling_tower': ctJson, 
              'reverse_osmosis': roJson,
              'indices': {
                'lsi': indices.lsi,
                'rsi': indices.rsi,
                'psi': indices.psi,
              },
              'risk_scaling': risk.scalingScore,
              'risk_corrosion': risk.corrosionScore,
              'risk_fouling': risk.foulingScore,
            },
            'analyzed_at': DateTime.now().toIso8601String(),
          });
        }
        
        print('DEBUG: Processed ${file.name} - Scaling: ${risk.scalingScore}, Corrosion: ${risk.corrosionScore}');
        
      } catch (e, stack) {
        print('Error processing file ${file.name}: $e');
        print(stack);
      }
    }
  }
}
