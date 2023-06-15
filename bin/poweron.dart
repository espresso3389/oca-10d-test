import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:synchronized/extension.dart';

Future<void> main() async {
  final ocac = OCAPowerControl(InternetAddress.tryParse('192.168.10.206')!);

  await ocac.powerOn(true);

  await Future.delayed(Duration(seconds: 1));

  await ocac.anyError();

  await ocac.powerOn(false);

  await Future.delayed(Duration(seconds: 5));

  await ocac.anyError();
}

enum _BufferState {
  seekingSyncValue,
  readingData,
}

class OCAPowerControl {
  final InternetAddress address;
  final int port;
  final String label;
  OCAPowerControl(this.address, {this.port = 30013, String? label})
      : label = label ?? address.address;

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;
  Completer<List<int>>? _comp;
  Timer? _keepAliveTimer;

  Future<void> _disconnect() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _socket?.close();
    _socket = null;
  }

  Future<void> _ensureInit() async {
    if (_sub != null) return;
    await synchronized(() async {
      if (_sub != null) return;
      _socket = await Socket.connect(address, port);
      var buf = <int>[];
      var state = _BufferState.seekingSyncValue;
      var dataSize = 0;
      try {
        _sub = _socket!.listen((event) {
          try {
            buf.addAll(event);
            for (;;) {
              if (state == _BufferState.seekingSyncValue) {
                if (buf.length < 7) return;
                if (buf[0] == 0x3b && buf[1] == 0x00 && buf[2] == 0x01) {
                  dataSize = buf[3] * 0x1000000 +
                      buf[4] * 0x10000 +
                      buf[5] * 0x100 +
                      buf[6] -
                      6;
                  buf = buf.sublist(7);
                  state = _BufferState.readingData;
                  continue;
                } else {
                  print(
                      'OCAPowerControl: $label: unknown sequence: len=${buf.length}: ${buf.map((b) => b.toRadixString(16).padLeft(2, '0')).join(',')}');
                  _disconnect();
                }
              } else if (state == _BufferState.readingData) {
                if (buf.length < dataSize) return;
                final data = buf.sublist(0, dataSize);
                buf = buf.sublist(dataSize);
                state = _BufferState.seekingSyncValue;
                print(
                    'OCAPowerControl: $label: data: len=${data.length}: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(',')}');
                if (data.isNotEmpty &&
                    data[0] == 0x03 &&
                    _comp?.isCompleted == false) {
                  _comp?.complete(data);
                }
                continue;
              }
            }
          } catch (e, s) {
            print('OCAPowerControl: $label: $e,$s');
          }
        }, onError: (e, s) {
          print('OCAPowerControl: $label: $e,$s');
        }, onDone: () {
          print('OCAPowerControl: $label: disconnected');
        });
      } catch (e, s) {
        print('OCAPowerControl: $label: $e,$s');
      }
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _socket!.add(_keepAlive);
      });
      try {
        anyError();
      } catch (e, s) {
        print('$e,$s');
      }
    });
  }

  Future<List<int>?> _send(
    List<int> command, {
    bool needResponse = true,
    Duration? timeout,
  }) async {
    await _ensureInit();
    if (needResponse) {
      _comp = Completer();
    }
    try {
      _socket!.add(command);
      if (needResponse) {
        return await _comp!.future
            .timeout(timeout ?? const Duration(milliseconds: 600));
      }
    } catch (e, s) {
      print('OCAPowerControl: $label: $e,$s');
    }
    return null;
  }

  Future<void> powerOn(bool power) =>
      _send([..._powerCmd, 0, power ? 1 : 0], needResponse: false);

  Future<bool> anyError() async {
    final result = await _send(_error_GnrlErr);
    return result != null && result[result.length - 1] == 1;
  }
}

const _powerCmd = [
  0x3B, // SyncValue
  0x00, 0x01, // ProtocolVersion; OCP.1 protocol
  0x00, 0x00, 0x00, 0x1C, // MessageSize=28 (Not including SyncValue)
  0x01, // MessageType=1 command message; response required
  0x00, 0x01, // MessageCount=1
  0x00, 0x00, 0x00, 0x13, // CommandSize=19 (including this field)
  0x00, 0x00, 0x00, 0x1C, // Handle=28
  0x10, 0x00, 0x01, 0x00, // TargetONo=0x10000100=Settings PowerOn/Standby
  0x00, 0x04, // MethodID: treeLevel = 4
  0x00, 0x02, //           methodIndex = 2 = OcaSwitch::SET_POSITION
  0x01, // parameterCount = 1
  // 0x00, 0x00, // 0x0001 = PowerOn, 0x0000 = Standby
];

const _error_GnrlErr = [
  0x3B, // SyncValue
  0x00, 0x01, // ProtocolVersion; OCP.1 protocol
  0x00, 0x00, 0x00, 0x1a, // MessageSize=26 (Not including SyncValue)
  0x01, // MessageType=1 command message; response required
  0x00, 0x01, // messageCount=1
  0x00, 0x00, 0x00, 0x11, // CommandSize=17
  0x00, 0x00, 0x00, 0x1a, // Handle=26
  0x10, 0x00, 0x05, 0x00, // TargetONo=0x10000500=Error_GnrlErr
  0x00, 0x05, // MethodID: treeLevel = 5
  0x00, 0x01, //           methodIndex = 1 = GET_READING
  0x00, // parameterCount = 0
];

const _keepAlive = [
  0x3B, // SyncValue
  0x00, 0x01, // ProtocolVersion; OCP.1 protocol
  0x00, 0x00, 0x00, 0x0b, // MessageSize=11 (Not including SyncValue)
  0x04, // MessageType=4; Keep-Alive
  0x00, 0x01, // messageCount=1
  0x00, 0x05, // Heartbeat time: 5 sec
];

final _ocaDevices = [
  OCAPowerControl(InternetAddress.tryParse('192.168.10.203')!),
  OCAPowerControl(InternetAddress.tryParse('192.168.10.204')!),
  OCAPowerControl(InternetAddress.tryParse('192.168.10.205')!),
  OCAPowerControl(InternetAddress.tryParse('192.168.10.206')!),
  OCAPowerControl(InternetAddress.tryParse('192.168.10.207')!),
  OCAPowerControl(InternetAddress.tryParse('192.168.10.208')!),
];

Future<void> powerOCADevices(bool power) =>
    Future.wait(_ocaDevices.map((d) => d.powerOn(power)));
