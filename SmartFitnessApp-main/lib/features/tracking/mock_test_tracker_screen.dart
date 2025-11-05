import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

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
  HEALTH_CONNECT_STATUS
}

class _HealthTrackerScreenState extends State<HealthTrackerScreen>{
  final Health _health = Health();

  List<HealthDataPoint> _healthData = [];
  int _totalSteps = 0;
  bool _isFetching = false;
  AppState _state = AppState.DATA_NOT_FETCHED; 

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _intializeHealth();
    });
  }
  Future<void> _intializeHealth() async{
    setState(() => AppState.FETCHING_DATA);

    await _health.configure();

    //request necessary runtime permissions
    await Permission.activityRecognition.request();
    await Permission.location.request();

    //health data types you want
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

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
    bool? hasPermission = await _health.hasPermissions(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );
    if (hasPermission != true){
      bool granted = false;
      try{
        granted = await _health.requestAuthorization(
          [HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ],
        );
      } catch (e) {
        debugPrint('Error requesting authorization: $e');
      }
      if (!granted){
        debugPrint('Step permission not granted by user.');
        setState((){
          _state=AppState.DATA_NOT_FETCHED;
          _isFetching = false;
        });
        return;
      }
    }
    try{
      steps = await _health.getTotalStepsInInterval(midnight,now);
      debugPrint('Total steps today: $steps');
    } catch (error){
      debugPrint("exception in getTotalStepsInInterval: $error");
    }
    setState((){
      _totalSteps = (steps ?? 0);
      _state = (steps == null)
        ? AppState.NO_DATA
        : AppState.STEPS_READY;
      _isFetching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('State: $_state'),
            const SizedBox(height: 8),
            Text(
              'Total Steps (since midnight): $_totalSteps',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isFetching ? null : _fetchSteps,
              child: const Text('Fetch Health Data'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _healthData.length,
                itemBuilder: (context, index) {
                  final point = _healthData[index];
                  final value = point.value;
                  final numeric = value is NumericHealthValue
                      ? value.numericValue
                      : value;
                  debugPrint('Source: ${point.sourceName}, Method: ${point.recordingMethod}');

                  return ListTile(
                    title: Text('${point.typeString}: $numeric ${point.unitString}'),
                    subtitle: Text(
                        '${point.dateFrom} → ${point.dateTo}\n'
                            'Source: ${point.sourceName}\n'
                            'Recording Method: ${point.recordingMethod}'),
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
