import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_fitness_app/features/tracking/badges/badge_repository.dart';
import 'package:smart_fitness_app/features/tracking/badges/domain/badge_service.dart';
import 'progress_repository.dart';

class HealthTrackerScreen extends StatefulWidget{
  const HealthTrackerScreen({super.key});

  @override
  State<HealthTrackerScreen> createState() => _HealthTrackerScreenState();
}

enum AppState{
  DATA_NOT_FETCHED,
  FETCHING_DATA,
  NO_DATA,
  STEPS_READY,
  AUTH_NOT_GRANTED,
  AUTHORIZED,
  PERMISSIONS_REVOKED,
  PERMISSIONS_NOT_REVOKED,
  PERMISSIONS_REVOKING,
  HEALTH_CONNECT_STATUS,
  WEIGHT,
}

class _HealthTrackerScreenState extends State<HealthTrackerScreen>{
  final Health _health = Health();
  final ProgressRepository _progressRepo = ProgressRepository();
  final BadgeRepository _badgeRepo = BadgeRepository();
  late final BadgeService _badgeService = BadgeService(badgeRepo: _badgeRepo);

  final List<HealthDataPoint> _healthData = [];
  int _totalSteps = 0;
  double? _latestWeight;
  //adding a new variable caloriesBurned
  double? _caloriesBurned;
  bool _isSyncing = false;
  bool _isFetching = false;
  AppState _state = AppState.DATA_NOT_FETCHED; 

  //ADD POPUP METHOD
  void _showBadgePopup(BuildContext context, Map<String, dynamic> badge){
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Badge Unlocked!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              badge['icon_url'],
              height: 120,
              width: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              badge['badge_name'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badge['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  badge['description'],
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(  
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _intializeHealth();
    });
  }
  Future<void> _intializeHealth() async{
    setState(() => _state = AppState.FETCHING_DATA);

    await _health.configure();

    //request necessary runtime permissions
    await Permission.activityRecognition.request();
    await Permission.location.request();

    //health data types you want
    final types = [HealthDataType.STEPS, HealthDataType.WEIGHT, HealthDataType.ACTIVE_ENERGY_BURNED];
    final permissions = [HealthDataAccess.READ, HealthDataAccess.READ, HealthDataAccess.READ];

    //ask for authorization
    bool authorized = 
    await _health.requestAuthorization(types, permissions: permissions);

    setState((){
      _state = 
      authorized ? AppState.AUTHORIZED : AppState.AUTH_NOT_GRANTED;
    });
  }
  //safelt fetches step count data from health connect or google git
  //and updates the ui state accordingly
  Future<void> _fetchSteps() async{
    int? steps;
    double? weight;
    List<HealthDataPoint> weightData = [];

    final now = DateTime.now();
    final midnight = DateTime(now.year,now.month,now.day);

    setState(() {
      _isFetching = true;
      _state = AppState.FETCHING_DATA;
    });
    //ensure android runtime permission for activity recognition
    try{
      if (await Permission.activityRecognition.isDenied){
        await Permission.activityRecognition.request();
      }
    } catch (e){
      debugPrint('Runtime permission request failed: $e');
    }

    try{
      await _health.configure();
    } catch(e){
      debugPrint('Error configuring health plugin: $e');
      setState((){
        _state = AppState.DATA_NOT_FETCHED;
        _isFetching=false;
      });
      return;
    }

 

    //verify health connect sdk availbility
    final status = await _health.getHealthConnectSdkStatus();
    if (status != HealthConnectSdkStatus.sdkAvailable){
      debugPrint(
        'health connect not installed or unavailable (Status: $status)');
      setState((){
        _state = AppState.DATA_NOT_FETCHED;
        _isFetching = false;
      });
      return;
    }
    //request permission for steps + weight
    final types = [HealthDataType.STEPS, HealthDataType.WEIGHT, HealthDataType.ACTIVE_ENERGY_BURNED];
    final permissions = [HealthDataAccess.READ, HealthDataAccess.READ, HealthDataAccess.READ];
    bool? hasPermission = await _health.hasPermissions(types, permissions: permissions);
    if (hasPermission != true){
      final granted = await _health.requestAuthorization(types, permissions: permissions);
      if (!granted){
        debugPrint('Health permissions not granted.');
        setState((){
          _state = AppState.AUTH_NOT_GRANTED;
          _isFetching = false;
        });
        return;
      }
    }
    try{
      //fetch total steps
      steps = await _health.getTotalStepsInInterval(midnight,now);
      debugPrint('Total steps today: $steps');
      //fetch weight data points
      weightData = await _health.getHealthDataFromTypes(startTime: midnight, endTime: now, types: [HealthDataType.WEIGHT]);
      if (weightData.isNotEmpty){
        final latest = weightData.last;
        final HealthValue value = latest.value;

        if (value is NumericHealthValue){
          weight = value.numericValue.toDouble();
          debugPrint('Current weight: ${weight.toStringAsFixed(1)} kg');
        } else{
          debugPrint('Unexpected weight value type: ${value.runtimeType}');
        }

        final List<HealthDataPoint> caloriesData = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        );
        if(caloriesData.isNotEmpty){
          final latest = caloriesData.last;
          final HealthValue value = latest.value;

          if (value is NumericHealthValue){
            _caloriesBurned = value.numericValue.toDouble();
            debugPrint('Calories burned today: ${_caloriesBurned!.toStringAsFixed(1)} kcal');
          }else{
            debugPrint('Unexpected calories value type: ${value.runtimeType}');
          }
        } else {
          debugPrint('Unexpected calories value type: ${value.runtimeType}');
        }
      } else {
        _caloriesBurned = null;
        debugPrint('No calories data found for today.');
      }
    } catch (error){
      debugPrint("exception in getTotalStepsInInterval: $error and $weight");
    }

    setState((){
      _totalSteps = (steps ?? 0);
      _healthData
        ..clear()
        ..addAll(weightData);
      _latestWeight = weight;
      _state = (steps == null)
        ? AppState.NO_DATA
        : AppState.STEPS_READY;
      _isFetching = false;
    });
  }

  //NEW sync to supabase

  Future<void> _syncToSupabase() async{
    setState(() => _isSyncing = true);
    try{
      //1. sync with supabase
      await _progressRepo.synchHealthDataToSupabase();
      //2.Check badges AFTER SYNCHING
      await _badgeService.checkAllProgressBadges(
        stepsToday: _totalSteps,
        caloriesToday: (_caloriesBurned ?? 0).round(),
      );
      //3. show popup if a badge was earned
      final newBadge = await _badgeRepo.getLatestBadge();
      if(!mounted) return;
      if (newBadge != null){
        _showBadgePopup(context, newBadge);
      }
      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Synch data to Supabase!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }catch (e){
      debugPrint("Error syncing: $e");
      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      
    } finally {
      setState(()=> _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context){
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Health Tracker'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //STATUS
            Text('Status: $_state',
            style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            //
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk,
                    size: 36, color: Colors.blueAccent),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Steps Today',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_totalSteps steps',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],  
                ),
              ),
            ),
            const SizedBox(height: 16),
            //WEIGHT CARD
            //Show Weight
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.monitor_weight,
                    size: 36, color: Colors.blueAccent),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'weight',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _latestWeight !=null
                            ? '${_latestWeight!.toStringAsFixed(1)} kg'
                            : 'N/A',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                    size: 36, color: Colors.blueAccent),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calories Burned',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _caloriesBurned != null
                            ? '${_caloriesBurned!.toStringAsFixed(1)} kcal'
                            : 'N/A',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            //ACTION BUTTONS
            


            //fetch + sync buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.directions_walk),
                    onPressed: _isFetching ? null : _fetchSteps,
                    label: Text(_isFetching ? 'Fetching...' : 'Fetch Steps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    onPressed: _isSyncing ? null : _syncToSupabase,
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync to supabase'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary),
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadiusGeometry.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _healthData.length,
                itemBuilder: (context, index){
                  final point = _healthData[index];
                  final value = point.value;
                  final numeric = 
                    value is NumericHealthValue ? value.numericValue : value.toString();
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        '${point.typeString}: $numeric ${point.unitString}'),
                      subtitle: Text(
                        '${point.dateFrom} -> ${point.dateTo}\nSource: ${point.sourceName}\nRecording Method: ${point.recordingMethod}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
