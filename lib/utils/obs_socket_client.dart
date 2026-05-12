import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ObsSocketClient {
  ObsSocketClient._();
  static final ObsSocketClient instance = ObsSocketClient._();

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSub;
  final StreamController<Uint8List> _incomingController = StreamController.broadcast();
  final StreamController<String> _linkEventController = StreamController.broadcast();

  Stream<Uint8List> get incomingDataStream => _incomingController.stream;
  Stream<String> get linkEventStream => _linkEventController.stream;

  bool get isConnected => _socket != null;

  String? _host;
  int? _port;
  Duration _connectTimeout = const Duration(seconds: 8);

  Future<void> connect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await disconnect();
    _host = host;
    _port = port;
    _connectTimeout = timeout;

    final socket = await Socket.connect(host, port, timeout: timeout);
    _socket = socket;
    _linkEventController.add('connected:$host:$port');

    _socketSub = socket.listen(
      (data) {
        _incomingController.add(Uint8List.fromList(data));
      },
      onError: (e, s) {
        _incomingController.addError(e, s);
        _linkEventController.add('error:$e');
      },
      onDone: () {
        _linkEventController.add('disconnected');
        _socketSub?.cancel();
        _socketSub = null;
        _socket = null;
      },
      cancelOnError: false,
    );
  }

  Future<void> reconnect() async {
    final host = _host;
    final port = _port;
    if (host == null || port == null) {
      throw Exception('尚未建立过连接，无法重连');
    }
    await connect(host: host, port: port, timeout: _connectTimeout);
  }

  Future<void> sendBytes(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) throw Exception('WiFi 通道未连接');
    socket.add(bytes);
    await socket.flush();
  }

  Future<void> sendText(String text, {Encoding encoding = utf8}) async {
    await sendBytes(encoding.encode(text));
  }

  Future<void> disconnect() async {
    await _socketSub?.cancel();
    _socketSub = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
      await socket.done.catchError((_) {});
      _linkEventController.add('disconnected');
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _incomingController.close();
    await _linkEventController.close();
  }
}
