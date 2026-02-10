import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../../core/failures.dart';
import '../domain/factory_repository.dart';
import '../domain/factory_entity.dart';
import '../domain/report_entity.dart';
import '../domain/measurement_v2.dart';
import 'storage_service.dart';

// V1 Services
import '../../../core/services/data_merge_service.dart';
import '../../../services/calculation_engine.dart';
import '../../../models/chemistry_models.dart';
import '../../../models/assessment_models.dart';
import '../../../core/services/excel/universal_excel_parser.dart';

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
  Future<Either<Failure, void>> deleteFactory(String factoryId) async {
    try {
       // Delete related reports first (safe guard if no cascade)
       await supabase.from('reports').delete().eq('factory_id', factoryId);
       
       // Delete factory
       await supabase.from('factories').delete().eq('id', factoryId);
       return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete factory: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReport(String reportId, String filePath) async {
    try {
      // 1. Delete from DB
      await supabase.from('reports').delete().eq('id', reportId);
      
      // 2. Delete from Storage (try-catch as it might not be critical or already gone)
      try {
        await supabase.storage.from('factories').remove([filePath]);
      } catch (e) {
        if (kDebugMode) {
          print('DEBUG: Failed to delete file from storage (might already be gone): $e');
        }
      }
      
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete report: $e'));
    }
  }


  @override
  Future<Either<Failure, SyncSummary>> syncWithDrive() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return const Left(AuthFailure('No authenticated user'));
      final email = user.email ?? '';

      SyncSummary totalSummary = SyncSummary();

      // 1. Fetch Factories (Folders) from Storage
      if (kDebugMode) {
        print('DEBUG: Syncing for email: $email');
      }
      final storageObjects = await storageService.listFactories(email);

      if (storageObjects.isEmpty) {
      if (kDebugMode) {
        print('DEBUG: No factories found in storage for $email');
      }
      }

      for (final object in storageObjects) {
        if (object.name == null) continue;
        final factoryName = object.name;

        // Skip potential placeholder files if using empty folder marker
        if (factoryName == '.emptyFolderPlaceholder') continue; 
        
        if (kDebugMode) {
          print('DEBUG: Processing factory: $factoryName');
        }

        // 2. Upsert Factory to Supabase DB
        
        final storagePath = 'user_${email.split('@')[0]}/$factoryName';

        try {
          // ... (Factory upsert logic remains same, omitting detailed check for brevity as it is stable)
           final existingFactory = await supabase
              .from('factories')
              .select('id')
              .eq('user_id', user.id)
              .eq('name', factoryName)
              .maybeSingle();

          String factoryId;
          if (existingFactory == null) {
            final res = await supabase.from('factories').insert({
              'user_id': user.id,
              'name': factoryName,
              'drive_folder_id': storagePath,
              'status': 'good',
              'last_sync_at': DateTime.now().toIso8601String(),
            }).select().single();
            factoryId = res['id'];
          } else {
            factoryId = existingFactory['id'];
            await supabase.from('factories').update({
              'last_sync_at': DateTime.now().toIso8601String(),
               'drive_folder_id': storagePath,
            }).eq('id', factoryId);
          }
          
           // 3. Process Excel Files
          final factorySummary = await _processFactoryFiles(factoryId, email, factoryName);
          totalSummary = totalSummary + factorySummary;

        } catch (e, stack) {
        if (kDebugMode) {
          print('DEBUG: DB/Sync Error for $factoryName: $e');
          print(stack);
        }
          // Count as failure? Or just log?
          // Since we might have processed some files, we can't easily add to summary unless we catch deeper.
          // But here, factory level failure implies 0 files processed from it?
        }
      }
      return Right(totalSummary);
    } catch (e) {
      return Left(ServerFailure('Sync failed: $e'));
    }
  }

  Future<SyncSummary> _processFactoryFiles(String factoryId, String email, String factoryName) async {
    final files = await storageService.listFactoryFiles(email, factoryName);
    
    // START PRUNING LOGIC
    // Get all file paths that currently exist in storage
    final Set<String> activeFilePaths = files.map((f) => 'user_${email.split('@')[0]}/$factoryName/${f.name}').toSet();
    
    // Fetch all report paths currently in DB for this factory
    final existingReports = await supabase
        .from('reports')
        .select('id, file_id')
        .eq('factory_id', factoryId); // Ensure we scope to this factory
        
    for (final report in existingReports as List) {
      final String? dbPath = report['file_id'];
      if (dbPath != null && !activeFilePaths.contains(dbPath)) {
        if (kDebugMode) {
          print('DEBUG: Pruning orphaned report: $dbPath');
        }
        await supabase.from('reports').delete().eq('id', report['id']);
      }
    }
    // END PRUNING LOGIC

    int processed = 0;
    int success = 0;
    int failure = 0;
    List<String> errors = [];
    Map<String, List<String>> missingData = {};

    for (final file in files) {
       final filePath = 'user_${email.split('@')[0]}/$factoryName/${file.name}';
       
       // Incremental Sync Check
       final String? currentEtag = file.metadata?['eTag'];
       
       final existingReport = await supabase
           .from('reports')
           .select()
           .eq('file_id', filePath) 
           .maybeSingle();

       if (existingReport != null && currentEtag != null) {
          final Map<String, dynamic> data = (existingReport['data'] as Map<String, dynamic>?) ?? {};
          final String? storedEtag = data['file_metadata']?['etag'];
          
          if (storedEtag == currentEtag) {
             if (kDebugMode) {
               print('DEBUG: Skipping unchanged file: ${file.name}');
             }
             processed++;
             continue; // Skip
          }
       }

      try {
        final bytes = await storageService.downloadFile(email, factoryName, file.name);

        CoolingTowerData? ctData;
        ROData? roData;
        List<CoolingTowerData> allCTData = [];
        List<ROData> allROData = [];
        List<String> fileMissingParams = [];
        
        try {
          final result = await UniversalExcelParser.parse(bytes);
          
          allCTData = (result['allCTData'] as List<dynamic>?)?.cast<CoolingTowerData>() ?? [];
          allROData = (result['allROData'] as List<dynamic>?)?.cast<ROData>() ?? [];
          fileMissingParams = (result['missingParameters'] as List<dynamic>?)?.cast<String>() ?? [];
          
          ctData = result['coolingTower'] as CoolingTowerData?;
          roData = result['ro'] as ROData?;
          
          if (fileMissingParams.isNotEmpty) {
             missingData[file.name!] = fileMissingParams;
          }
          
        } catch (e) {
          if (kDebugMode) {
            print('DEBUG: [UniversalParser] Error processing file ${file.name}: $e');
          }
          failure++;
          errors.add('Failed to parse ${file.name}: $e');
          continue; 
        }

        if (allCTData.isEmpty && ctData == null && roData == null) {
           failure++;
           errors.add('${file.name} yielded no data');
           continue;
        }

        // ──────────────────────────────────────────────────────────
        // Phase 2: Unified Data Pipeline (V2 + V1)
        // ──────────────────────────────────────────────────────────
        
        try {
           // 1. Prepare V2 Records (Measurements)
           final mergeService = DataMergeService(supabase);
           List<MeasurementV2> v2Records = [];
           
           for (int i = 0; i < allCTData.length; i++) {
             final ct = allCTData[i];
             final ro = i < allROData.length ? allROData[i] : null;
             final indices = CalculationEngine.calculateIndices(ct);
             
             // Infer Granularity
             final periodType = _inferGranularity(allCTData);

              v2Records.add(MeasurementV2(
                 factoryId: factoryId,
                 periodType: periodType,
                 startDate: ct.timestamp,
                 endDate: ct.timestamp,
                 data: {
                   'ph': ct.ph.value,
                   'alkalinity': ct.alkalinity.value,
                   'conductivity': ct.conductivity.value,
                   'hardness': ct.totalHardness.value,
                   'chloride': ct.chloride.value,
                   'zinc': ct.zinc.value,
                   'iron': ct.iron.value,
                   'phosphates': ct.phosphates.value,
                   if (ro != null) ...{
                     'free_chlorine': ro.freeChlorine.value,
                     'silica': ro.silica.value,
                     'ro_conductivity': ro.roConductivity.value,
                   }
                 },
                 indices: {
                   'lsi': indices.lsi,
                   'rsi': indices.rsi,
                   'psi': indices.psi,
                 },
                 uploadId: null, // Optional
               ));
           }

           // 2. Prepare V1 Records (Reports)
           // Recalculating indices/risk for V1 single report (latest data)
           final indices = ctData != null ? CalculationEngine.calculateIndices(ctData) : CalculatedIndices(lsi: 0, rsi: 0, psi: 0, stiffDavis: 0, larsonSkold: 0, coc: 0, adjustedPsi: 0, tdsEstimation: 0, chlorideSulfateRatio: 0, timestamp: DateTime.now(), usedTemperature: 0, sulfateEstimated: false);
           final risk = ctData != null ? CalculationEngine.assessRisk(indices, ctData) : RiskAssessment(scalingScore: 0, corrosionScore: 0, foulingScore: 0, scalingRisk: RiskLevel.low, corrosionRisk: RiskLevel.low, foulingRisk: RiskLevel.low, timestamp: DateTime.now());
           
           final reportData = {
              'file_metadata': {
                'etag': currentEtag,
                'size': file.metadata?['size'],
                'last_modified': file.metadata?['lastModified'],
                'processed_at': DateTime.now().toIso8601String(),
              },
              'cooling_tower': ctData != null ? {
                'pH': {'value': ctData.ph.value, 'unit': ctData.ph.unit},
                'Alkalinity': {'value': ctData.alkalinity.value, 'unit': ctData.alkalinity.unit},
                'Conductivity': {'value': ctData.conductivity.value, 'unit': ctData.conductivity.unit},
                'Total Hardness': {'value': ctData.totalHardness.value, 'unit': ctData.totalHardness.unit},
                'Chloride': {'value': ctData.chloride.value, 'unit': ctData.chloride.unit},
                'Zinc': {'value': ctData.zinc.value, 'unit': ctData.zinc.unit},
                'Iron': {'value': ctData.iron.value, 'unit': ctData.iron.unit},
                'Phosphates': {'value': ctData.phosphates.value, 'unit': ctData.phosphates.unit},
                'timestamp': ctData.timestamp.toIso8601String(),
              } : null, 
              'reverse_osmosis': roData != null ? {
                 'Free Chlorine': {'value': roData.freeChlorine.value, 'unit': roData.freeChlorine.unit},
                 'Silica': {'value': roData.silica.value, 'unit': roData.silica.unit},
                 'RO Conductivity': {'value': roData.roConductivity.value, 'unit': roData.roConductivity.unit},
                 'timestamp': roData.timestamp.toIso8601String(),
               } : null,
              'indices': {
                'lsi': indices.lsi,
                'rsi': indices.rsi,
                'psi': indices.psi,
              },
              'risk_scaling': risk.scalingScore,
              'risk_corrosion': risk.corrosionScore,
              'risk_fouling': risk.foulingScore,
           };

           // 3. EXECUTE WRITES (Sequential)
           
           // Write V2
           if (v2Records.isNotEmpty) {
             await mergeService.mergeMeasurements(v2Records);
           }

           // Write V1
           final existingReportV1 = await supabase.from('reports').select('id').eq('file_id', filePath).maybeSingle();

           if (existingReportV1 != null) {
              await supabase.from('reports').update({
                'factory_id': factoryId,
                'file_name': file.name,
                'risk_scaling': risk.scalingScore,
                'risk_corrosion': risk.corrosionScore,
                'risk_fouling': risk.foulingScore,
                'data': reportData,
                // 'analyzed_at': DateTime.now().toIso8601String(), // Keep original analysis time? No, update.
                'analyzed_at': DateTime.now().toIso8601String(),
              }).eq('id', existingReportV1['id']);
           } else {
              await supabase.from('reports').insert({
                'factory_id': factoryId,
                'file_id': filePath,
                'file_name': file.name,
                'risk_scaling': risk.scalingScore,
                'risk_corrosion': risk.corrosionScore,
                'risk_fouling': risk.foulingScore,
                'data': reportData,
                'analyzed_at': DateTime.now().toIso8601String(),
              });
           }
           
           success++;
           processed++;

        } catch (e) {
           failure++;
           errors.add('Failed to save data for ${file.name}: $e');
           if (kDebugMode) {
             print('DEBUG: Save Error: $e');
           }
        }
      } catch (e) {
         failure++;
         errors.add('Error processing file ${file.name}: $e');
         if (kDebugMode) {
           print('DEBUG: Outer processing error for ${file.name}: $e');
         }
      }
    }
    
    return SyncSummary(
      processedFiles: processed,
      successCount: success,
      failureCount: failure,
      errorMessages: errors,
      missingDataFiles: missingData,
    );
  }

  PeriodType _inferGranularity(List<CoolingTowerData> data) {
    if (data.length < 2) return PeriodType.daily; // Default to daily for single points

    // Sort to be sure
    final sorted = List<CoolingTowerData>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Check average gap
    double totalDays = 0;
    int gaps = 0;
    
    for (int i = 0; i < sorted.length - 1; i++) {
       final diff = sorted[i+1].timestamp.difference(sorted[i].timestamp).inDays;
       if (diff > 0) { // Ignore duplicates or same-day
         totalDays += diff;
         gaps++;
       }
    }
    
    if (gaps == 0) return PeriodType.daily;
    
    final avgGap = totalDays / gaps;
    
    // If average gap is > 20 days, it's likely monthly
    if (avgGap > 20) {
      return PeriodType.monthly;
    }
    
    return PeriodType.daily;
  }
}
