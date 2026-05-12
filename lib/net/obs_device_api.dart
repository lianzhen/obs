import 'http_util.dart';

class ObsDeviceApi {
  ObsDeviceApi._();

  static String _fileSeg(String fileName) => Uri.encodeComponent(fileName);

  static Future<Map<String, dynamic>?> getDeviceInfo({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/device/info',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<void> saveConfigs(
    Map<String, Object?> maps, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.post<dynamic>(
      '/api/device/configs/save',
      data: maps,
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }

  static Future<Map<String, dynamic>?> getConfigs({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/device/configs',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<void> updateConfigs(
    Map<String, Object?> maps, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.post<dynamic>(
      '/api/device/configs',
      data: maps,
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }

  static Future<Map<String, dynamic>?> getWorkStatus({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/device/work/status',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<void> startWork({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.get<dynamic>(
      '/api/device/work/start',
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }

  static Future<void> stopWork({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.get<dynamic>(
      '/api/device/work/stop',
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }

  static Future<void> recoveryWork({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.get<dynamic>(
      '/api/device/work/recovery',
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }

  static Future<void> startWorkByTime(
    Map<String, dynamic> deviceTimerDto, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.post<dynamic>(
      '/api/device/work/start/by/time',
      data: deviceTimerDto,
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }

  static Future<Map<String, dynamic>?> getTimerStatus({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/device/work/timer/status',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<void> clearTimer({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.get<dynamic>(
      '/api/device/work/timer/clear',
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }

  static Future<Map<String, dynamic>?> getLocation({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/device/location',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<Map<String, dynamic>?> getAttitude({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/device/attitude',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<List<dynamic>?> listFiles(
    String path,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<List<dynamic>>(
        '/api/files',
        params: {'path': path, 'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<Map<String, dynamic>?> getFileInfo(
    String fileName, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/file/${_fileSeg(fileName)}/info',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<List<int>?> downloadFile(
    String fileName,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.getBytes(
        '/api/file/${_fileSeg(fileName)}/download',
        params: {'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<int?> getFileState(
    String fileName,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<int>(
        '/api/file/${_fileSeg(fileName)}/state',
        params: {'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<int?> getFileSize(
    String fileName,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<int>(
        '/api/file/${_fileSeg(fileName)}/size',
        params: {'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<String?> getFileMd5(
    String fileName,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<String>(
        '/api/file/${_fileSeg(fileName)}/md5',
        params: {'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<List<int>?> downloadChunk(
    String fileName,
    int start,
    int size,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.getBytes(
        '/api/file/chunk',
        params: {
          'fileName': fileName,
          'start': start,
          'size': size,
          'action': action,
        },
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<List<int>?> mergeFile(
    String fileName,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.getBytes(
        '/api/file/merge',
        params: {'fileName': fileName, 'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<bool?> verifyFile(
    String fileName,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<bool>(
        '/api/file/verify',
        params: {'fileName': fileName, 'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<bool?> verifyFileMd5(
    String fileName,
    String hash,
    int action, {
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<bool>(
        '/api/file/verify/md5',
        params: {'fileName': fileName, 'hash': hash, 'action': action},
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<Map<String, dynamic>?> getUpdatePackageInfo({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.get<Map<String, dynamic>>(
        '/api/update/package/info',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<List<int>?> downloadUpdatePackage({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) =>
      HttpUtil.getBytes(
        '/api/update/package/download',
        isShowLoading: isShowLoading,
        onStart: onStart,
        onError: onError,
        skipAuth: skipAuth,
      );

  static Future<void> installUpdatePackage({
    bool isShowLoading = true,
    RequestStartCallback? onStart,
    RequestErrorCallback? onError,
    bool skipAuth = false,
  }) async {
    await HttpUtil.post<dynamic>(
      '/api/update/package/install',
      isShowLoading: isShowLoading,
      onStart: onStart,
      onError: onError,
      skipAuth: skipAuth,
    );
  }
}
