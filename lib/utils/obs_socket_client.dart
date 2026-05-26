import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// WiFi（TCP Socket）与 OBS 设备通信的客户端。
///
/// 使用场景：
/// - 手机已连上设备的 WiFi 热点（例如 SSID 为 GeXing888）
/// - 知道设备的数据通道 IP 和端口（常见如 192.168.4.1:9000）
/// - 通过 TCP 发送/接收二进制数据（与蓝牙通道 [BluetoothTransferUtil] 二选一或并行监听）
///
/// 典型用法：
/// ```dart
/// final wifi = ObsSocketClient.instance;
/// await wifi.connect(host: '192.168.4.1', port: 9000);
/// wifi.incomingDataStream.listen((data) { /* 处理设备回包 */ });
/// await wifi.sendBytes(ObsHostProtocol.encodeCommand(0x60));
/// ```
///
/// 本类采用 **单例**：全 App 共用一条 WiFi 连接，避免多处各自 connect 互相抢占。
class ObsSocketClient {
  // 私有构造，外部不能直接 new ObsSocketClient()。
  ObsSocketClient._();

  /// 全局唯一实例。页面里统一写：ObsSocketClient.instance
  static final ObsSocketClient instance = ObsSocketClient._();

  // ---------------------------------------------------------------------------
  // 连接状态相关
  // ---------------------------------------------------------------------------

  /// 底层 TCP 套接字。为 null 表示当前没有连上设备。
  Socket? _socket;

  /// 监听「设备发来的数据」的订阅句柄。disconnect 时要 cancel，防止泄漏。
  StreamSubscription<Uint8List>? _socketSub;

  /// 最近一次 connect 用的 IP，供 [reconnect] 自动重连。
  String? _host;

  /// 最近一次 connect 用的端口。
  int? _port;

  /// 连接超时时间，reconnect 时会复用。
  Duration _connectTimeout = const Duration(seconds: 8);

  // ---------------------------------------------------------------------------
  // 对外暴露的数据流（多个页面可以同时 listen）
  // ---------------------------------------------------------------------------

  /// **收到的原始字节流**（广播 Stream）。
  ///
  /// - 设备每发来一包 TCP 数据，这里就 push 一次 [Uint8List]。
  /// - 各页面（通信页、GPS 页、配置页）可分别 `.listen`，互不影响。
  /// - 内容可能是 OBS 协议帧（帧头 0x3A），也可能是 NMEA 文本等，由上层自行解析。
  Stream<Uint8List> get incomingDataStream => _incomingController.stream;

  /// **链路状态事件**（字符串，便于打日志或 UI 提示）。
  ///
  /// 常见取值示例：
  /// - `connected:192.168.4.1:9000` — 连接成功
  /// - `disconnected` — 连接断开（对端关闭或网络中断）
  /// - `error:...` — 发生错误
  Stream<String> get linkEventStream => _linkEventController.stream;

  /// 广播控制器：允许多个监听者同时订阅 [incomingDataStream]。
  final StreamController<Uint8List> _incomingController =
      StreamController.broadcast();

  /// 广播控制器：链路事件。
  final StreamController<String> _linkEventController =
      StreamController.broadcast();

  /// 是否已建立 TCP 连接。仅判断 [_socket] 是否为 null（不探测网络是否真的通）。
  bool get isConnected => _socket != null;

  // ---------------------------------------------------------------------------
  // 连接 / 重连
  // ---------------------------------------------------------------------------

  /// 连接到 OBS 设备的 TCP 服务。
  ///
  /// [host] 设备 IP，例如连设备热点后常见的 `192.168.4.1`。
  /// [port] 设备端口，需与固件约定（如 9000）。
  /// [timeout] 建立连接的最长等待时间，超时则抛异常。
  ///
  /// 流程说明：
  /// 1. 若之前已连接，先 [disconnect] 干净再连新的，避免旧 socket 残留。
  /// 2. [Socket.connect] 发起 TCP 三次握手。
  /// 3. 对 socket 注册 listen：有数据 → 转发到 [incomingDataStream]；
  ///    出错 / 对端关闭 → 更新状态并清空 [_socket]。
  Future<void> connect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await disconnect();

    _host = host;
    _port = port;
    _connectTimeout = timeout;

    // dart:io 的 TCP 客户端连接
    final socket = await Socket.connect(host, port, timeout: timeout);
    _socket = socket;

    // 通知所有订阅了 linkEventStream 的页面：已连接
    _linkEventController.add('connected:$host:$port');

    // 持续监听：设备随时可能下发数据
    _socketSub = socket.listen(
      (data) {
        // data 是 List<int>，转成 Uint8List 便于协议解析
        _incomingController.add(Uint8List.fromList(data));
      },
      onError: (e, s) {
        // 将错误传给 incoming 流的监听者（若他们监听了 onError）
        _incomingController.addError(e, s);
        _linkEventController.add('error:$e');
      },
      onDone: () {
        // 对端关闭连接或网络断开时触发
        _linkEventController.add('disconnected');
        _socketSub?.cancel();
        _socketSub = null;
        _socket = null;
      },
      // false：某次 onError 后仍保持订阅，由 onDone 统一收尾
      cancelOnError: false,
    );
  }

  /// 使用上次成功的 host/port 再次连接（自动重连场景）。
  ///
  /// 若从未调用过 [connect]，会抛异常。
  Future<void> reconnect() async {
    final host = _host;
    final port = _port;
    if (host == null || port == null) {
      throw Exception('尚未建立过连接，无法重连');
    }
    await connect(host: host, port: port, timeout: _connectTimeout);
  }

  // ---------------------------------------------------------------------------
  // 发送数据
  // ---------------------------------------------------------------------------

  /// 向设备发送一段**原始字节**（已组好的协议帧直接传入即可）。
  ///
  /// 例如发「读舱温」：
  /// `await sendBytes(ObsHostProtocol.encodeCommand(ObsHostCommand.cmdGetT));`
  ///
  /// [flush] 确保数据立刻从发送缓冲区推到网络，减少「发了但设备没收到」的情况。
  Future<void> sendBytes(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) throw Exception('WiFi 通道未连接');
    socket.add(bytes);
    await socket.flush();
  }

  /// 发送**文本**（内部按 UTF-8 编码成字节再 [sendBytes]）。
  ///
  /// 若设备协议是纯二进制，请优先用 [sendBytes]。
  Future<void> sendText(String text, {Encoding encoding = utf8}) async {
    await sendBytes(encoding.encode(text));
  }

  // ---------------------------------------------------------------------------
  // 断开与销毁
  // ---------------------------------------------------------------------------

  /// 主动断开 TCP 连接。
  ///
  /// - 取消数据监听
  /// - 关闭 socket
  /// - 通过 [linkEventStream] 发出 `disconnected`（若 socket 曾经存在）
  Future<void> disconnect() async {
    await _socketSub?.cancel();
    _socketSub = null;

    final socket = _socket;
    _socket = null;

    if (socket != null) {
      await socket.close();
      // 等待关闭完成；忽略关闭过程中的异常
      await socket.done.catchError((_) {});
      _linkEventController.add('disconnected');
    }
  }

  /// 应用退出或不再需要 WiFi 模块时调用：断开连接并关闭两个广播流。
  ///
  /// 关闭后不应再使用 [incomingDataStream] / [linkEventStream]。
  Future<void> dispose() async {
    await disconnect();
    await _incomingController.close();
    await _linkEventController.close();
  }
}
