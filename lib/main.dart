import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BluetoothScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(const MyApp());
}


class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  List<String> _receivedDataList = [];
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    await Future.delayed(Duration(seconds: 6));
    FlutterBluePlus.stopScan();

    setState(() {
      _isScanning = false;
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        _connectedDevice = device;
        _receivedDataList.add('Conectado a: ${device.platformName}');
      });
    } catch (e) {
      if (e.toString().contains('already connected')) {
        print('Ya conectado');
      } else {
        print('Error al conectar: $e');
        return;
      }
    }

    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.read) {
          var value = await characteristic.read();
          setState(() {
            _receivedDataList.add('Read: ${String.fromCharCodes(value)}');
          });
        }

        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((value) {
            setState(() {
              _receivedDataList.add('Notify: ${String.fromCharCodes(value)}');
            });
          });
        }
      }
    }
  }

  void _disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print('Desconectado de: ${device.platformName}');
      setState(() {
        _connectedDevice = null;
        _receivedDataList.add('Desconectado de: ${device.platformName}');
      });
    } catch (e) {
      print('Error al desconectar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bluetooth BLE')),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _startScan,
        child: Icon(Icons.refresh),
      ),
      body: Column(
        children: [
          Expanded(
            child: _scanResults.isEmpty
                ? Center(child: Text('No se encontraron dispositivos.'))
                : ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final device = result.device;
                final name = result.advertisementData.advName.isNotEmpty
                    ? result.advertisementData.advName
                    : (device.platformName.isNotEmpty
                    ? device.platformName
                    : 'Dispositivo sin nombre');

                final isConnected = _connectedDevice?.remoteId == device.remoteId;

                return ListTile(
                  title: Text(name),
                  subtitle: Text(device.remoteId.toString()),
                  trailing: isConnected
                      ? IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _disconnectFromDevice(device),
                  )
                      : null,
                  onTap: () => _connectToDevice(device),
                );
              },
            ),
          ),
          Divider(),
          Expanded(
            child: _receivedDataList.isEmpty
                ? Center(child: Text('Sin datos aún.'))
                : ListView.builder(
              itemCount: _receivedDataList.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(8),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(_receivedDataList[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}