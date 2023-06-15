import 'dart:io';

const inputSwitch = [
  0x3B, // SyncValue
  0x00, 0x01, // ProtocolVersion
  0x00, 0x00, 0x00, 0x1C, // MessageSize=28
  0x01, // MessageType=1
  0x00, 0x01, // MessageCount = 1
  0x00, 0x00, 0x00, 0x13, // CommandSize=19
  0x00, 0x00, 0x00, 0x1C, // Handle=28
  // address=0x12
  0x10, 0x00, 0x82, 0x20, // TargetONo=0x10008220 =Analog Input 1, channel A
  0x00, 0x04, // MethodID: treeLevel=4
  0x00, 0x02, //           methodIndex=2=OcaSwitch::SET_POSITION
  0x01, // parameterCount = 1
  //0x00, 0x00, // 0x0001 = Enable, 0x0000 = Disable
];

enum Channel { a, b, c, d }

enum Input {
  analog1,
  analog2,
  analog3,
  analog4,
  digital1,
  digital2,
  digital3,
  digital4,
}

const _channelAddresses = [
  [0x10, 0x00, 0x82],
  [0x10, 0x01, 0x02],
  [0x10, 0x01, 0x82],
  [0x10, 0x02, 0x02],
];

// 20=input analog 1
// 21=input analog 2
// ...
// 24=input digital 1
// 25=input digital 2
// ...

List<int> _cmd(Channel channel, Input input, bool enable) {
  final cmd = [...inputSwitch, 0, enable ? 1 : 0];
  final c = _channelAddresses[channel.index];
  cmd[0x12] = c[0];
  cmd[0x13] = c[1];
  cmd[0x14] = c[2];
  cmd[0x15] = 0x20 + input.index;

  //print(cmd.map((e) => e.toRadixString(16)).join(','));
  return cmd;
}

extension SocketExt on Socket {
  void sendCmd(Channel channel, Input input, bool enable) {
    add(_cmd(channel, input, enable));
  }
}

Future<void> main() async {
  final s = await Socket.connect('192.168.10.206', 30013);

  void enableAnalogA(bool enable) {
    s.sendCmd(Channel.a, Input.analog2, enable);
    s.sendCmd(Channel.a, Input.digital1, !enable);
    s.sendCmd(Channel.c, Input.analog1, enable);
    s.sendCmd(Channel.c, Input.digital3, !enable);
  }

  void enableAnalogB(bool enable) {
    s.sendCmd(Channel.a, Input.analog1, enable);
    s.sendCmd(Channel.a, Input.digital1, !enable);
    s.sendCmd(Channel.c, Input.analog2, enable);
    s.sendCmd(Channel.c, Input.digital3, !enable);
  }

  print('funcA(true)');
  enableAnalogA(true);
  await Future.delayed(Duration(seconds: 10));

  print('funcA(false)');
  enableAnalogA(false);
  await Future.delayed(Duration(seconds: 10));

  print('funcB(true)');
  enableAnalogB(true);
  await Future.delayed(Duration(seconds: 10));

  print('funcB(false)');
  enableAnalogB(false);
  await Future.delayed(Duration(seconds: 10));
}
