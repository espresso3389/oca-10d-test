import 'dart:io';

const powerCmd = [
  0x3B, // SyncValue
  0x00, 0x01, // ProtocolVersion
  0x00, 0x00, 0x00,
  0x1C, // MessageSize: 28 (Header + Data incl., but excl. Sync)
  0x01, // MsgType: Command response required message
  0x00, 0x01, // messageCount = 1
  0x00, 0x00, 0x00, 0x13, //commandSize = 19 (including the size field)
  0x00, 0x00, 0x00,
  0x1C, // Command handle = 28 (for relating answer from device, value of handle can be specified by the controller)
  0x10, 0x00, 0x01,
  0x00, // Destination Ono 0x10000100 = Settings PowerOn/Standby
  0x00, 0x04, // Method ID: treeLevel = 4
  0x00, 0x02, // Method ID: methodIndex = 2 = OcaSwitch::SET_POSITION
  0x01, // parameterCount = 1
//0x00, 0x00, // 0x0001 = PowerOn, 0x0000 = Standby
];

Future<void> main() async {
  final s = await Socket.connect('192.168.10.206', 30013);

  // Standby
  print('Standby.');
  s.add([...powerCmd, 0, 0]);

  await Future.delayed(Duration(seconds: 5));

  // Standby
  print('PowerOn.');
  s.add([...powerCmd, 0, 1]);
}
