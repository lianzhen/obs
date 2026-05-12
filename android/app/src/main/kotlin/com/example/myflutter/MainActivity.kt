package com.example.myflutter

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 与 Flutter SystemUiMode.edgeToEdge 配合，内容可绘制到状态栏/刘海区域；否则系统仍把根布局截在状态栏下。
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
    // 1. 通道名称：必须和 Flutter 端完全一致
    private val CHANNEL = "com.example.native_channel"
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        // 2. 创建 MethodChannel 并监听方法调用
        methodChannel.setMethodCallHandler { call, result ->
            // 3. 判断 Flutter 调用的方法名
            if (call.method == "getNativeInfo") {
                //接受参数
                val name = call.argument<String>("name") ?: "未知"
                val age = call.argument<Int>("age") ?: 0
                val nativeData = "收到参数：$name，年龄：$age"
                sendMsgToFlutter()
                result.success(nativeData)
            } else {
                // 方法名不匹配
                result.notImplemented()
            }
        }
    }


    // 原生主动发消息给 Flutter
    private fun sendMsgToFlutter() {
        // 调用Flutter定义的方法名：androidSendMsg
        methodChannel.invokeMethod(
            "androidSendMsg",
            "我是Android原生主动发送的内容：${System.currentTimeMillis()}",
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    // 接收Flutter回执
                    println("Flutter回执：$result")
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            }
        )
    }

}
