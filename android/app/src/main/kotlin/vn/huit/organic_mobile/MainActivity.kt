package vn.huit.organic_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var returns: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        returns = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "vn.huit.organic_mobile/payment-return").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "initialLink") {
                    val link = intent?.dataString
                    intent?.data = null
                    result.success(link)
                } else { result.notImplemented() }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { returns?.invokeMethod("open", it) }
        intent.data = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        returns?.setMethodCallHandler(null)
        returns = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
