import 'package:flutter/material.dart';
// 导入dart:io库
import 'dart:io';
import 'dart:convert'; // 用于编码和解码数据
import 'package:flutter/services.dart'; // 导入系统服务库，用于剪贴板操作。
import 'dart:async'; // 导入异步库

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // 创建一个变量,用来存储剪贴板历史记录
  final List<String> _clipboardHistory = [];

  @override
  void initState() {
    super.initState();
    discover();
    //定期获取剪贴板内容
    Timer.periodic(const Duration(seconds: 1), (timer) {
      getClipboardData();
    });
  }

  // 获取剪贴板内容
  void getClipboardData() async {
    // 获取剪贴板数据
    ClipboardData? data = (await Clipboard.getData('text/plain'));

    // 如果剪贴板数据不为空且不同于历史记录中最后一条
    if (data != null &&
        (_clipboardHistory.isEmpty || _clipboardHistory.last != data.text)) {
      setState(() {
        _clipboardHistory.add(data.text!);
      });
      broadcast(); // 仅在需要时触发广播
    }
  }

  // 更新剪贴板内容，并避免重复设置
  void updateClipboardData(String newContent) async {
    ClipboardData? currentData = await Clipboard.getData('text/plain');
    if (currentData?.text != newContent) {
      await Clipboard.setData(ClipboardData(text: newContent));
      setState(() {
        // 如果需要更新UI的内容或状态，可以在这里执行
        _clipboardHistory.add(newContent);
      });
      broadcast(); // 仅在需要时触发广播
    }
  }

  void broadcast() async {
    // 获取所有网络接口
    List<NetworkInterface> interfaces = await NetworkInterface.list();
    // 选择适当的接口（例如Wi-Fi接口）
    NetworkInterface? selectedInterface = interfaces.firstWhere(
      (interface) =>
          interface.name.contains('WLAN') || interface.name.contains('en0'),
      orElse: () => interfaces.first,
    );

    // 获取当前网络的广播地址
    String? broadcastAddress;
    for (var address in selectedInterface.addresses) {
      if (address.type == InternetAddressType.IPv4) {
        // 计算广播地址
        List<String> parts = address.address.split('.');
        // broadcastAddress = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        broadcastAddress = '255.255.255.255'; // 广播地址255.255.255.255代表所有设备
        break;
      }
    }
    print(broadcastAddress);

    if (broadcastAddress == null) {
      print('无法找到合适的广播地址');
      return;
    }

    // 绑定到所选接口的IP地址
    RawDatagramSocket socket = await RawDatagramSocket.bind(
      selectedInterface.addresses.first,
      0,
    );
    socket.broadcastEnabled = true;

    if (_clipboardHistory.isNotEmpty) {
      String message = _clipboardHistory.last;
      List<int> data = utf8.encode(message);
      socket.send(data, InternetAddress(broadcastAddress), 3000);
      print('广播消息: $message');
      socket.close();
    }
  }

  void discover() async {
    // 绑定到指定端口，监听所有地址
    RawDatagramSocket socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, 3000);
    socket.listen((RawSocketEvent event) async {
      if (event == RawSocketEvent.read) {
        Datagram? datagram = socket.receive();
        if (datagram != null) {
          String message = utf8.decode(datagram.data).trim();
          //UI弹出显示接收到的广播消息以及对方的地址和端口
          ScaffoldMessenger.of(context).clearSnackBars(); // 清除所有等待的 SnackBar
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '接收到广播消息: $message ，来自 ${datagram.address.address}:${datagram.port}'),
            action: SnackBarAction(
              label: '复制',
              onPressed: () {
                updateClipboardData(message);
              },
            ),
          ));
          // 获取当前剪贴板内容
          ClipboardData? currentData = await Clipboard.getData('text/plain');
          String? clipboardContent = currentData?.text?.trim();

          // 如果收到的广播消息和剪贴板内容不一样,则添加到剪贴板历史记录中并更新剪贴板
          if (clipboardContent != message) {
            updateClipboardData(message); // 更新剪贴板数据
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                '剪贴板历史记录',
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _clipboardHistory.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      child: ListTile(
                        title: Text(_clipboardHistory[
                            _clipboardHistory.length - 1 - index]),
                        subtitle: const Text('来自本机'),
                        subtitleTextStyle: const TextStyle(
                            color: Color.fromARGB(255, 221, 30, 247)),
                        onTap: () {
                          ScaffoldMessenger.of(context)
                              .clearSnackBars(); // 清除所有等待的 SnackBar
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                          updateClipboardData(_clipboardHistory[
                              _clipboardHistory.length - 1 - index]); // 更新剪贴板内容
                        },
                        trailing: const Icon(Icons.copy),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end, // 将浮动按钮行对齐到底部。
          children: [
            FloatingActionButton(
              onPressed: broadcast,
              tooltip: '广播',
              child: const Icon(Icons.wifi),
            ),
          ],
        ));
  }
}
