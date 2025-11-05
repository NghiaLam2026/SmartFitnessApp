import 'package:flutter/material.dart';
import 'package:flutter_health_connect/flutter_health_connect.dart';

class HealthConnectCheckScreen extends StatefulWidget{
  const HealthConnectCheckScreen({super.key});

  @override
  State<HealthConnectCheckScreen> createState() => _HealthConnectCheckScreenState();
}

class _HealthConnectCheckScreenState extends State<HealthConnectCheckScreen>{
  String _status = "Checking...";

  @override
  void initState(){
    super.initState();
    _checkHealthConnect();
  }
  Future<void> _checkHealthConnect() async {
    try{
      final available = await HealthConnectFactory.isAvailable();
      setState(() {
        
        _status = available
          ? "Health Connect is available and ready"
          : "Health Connect not found.";
      });
    } catch (e){
      setState((){
        _status = "Error checking Health Connect: $e";
      });
    }

  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Health Connect Status")),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          _status,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    ),
  );
}
///this flutter app itseld does not record or count steps in the background. instead health connect
/// and the apps connected to it, do the background tracking
///health connect is a data hub not a fitness tracker
///