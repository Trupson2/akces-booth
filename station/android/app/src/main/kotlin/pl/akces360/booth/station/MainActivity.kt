package pl.akces360.booth.station

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "pl.akces360.booth.station/shutter"
    }

    private var shutterChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shutterChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
    }

    /**
     * Przechwytujemy klawisze z BT shutter'a (pilocika selfie).
     *
     * Typowe HID shuttery emulują keyboard i wysyłają jeden z kodów:
     * - VOLUME_UP / VOLUME_DOWN (najczęstsze)
     * - CAMERA (niektóre dedykowane)
     * - HEADSETHOOK / MEDIA_PLAY_PAUSE (Apple / legacy)
     *
     * Consume (return true) = system nie zmienia głośności + nie odpala music.
     * Station jest w kiosk mode więc normalny volumen i tak jest niepotrzebny.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP,
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_CAMERA,
                KeyEvent.KEYCODE_HEADSETHOOK,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_MEDIA_PLAY,
                KeyEvent.KEYCODE_ENTER,
                KeyEvent.KEYCODE_DPAD_CENTER -> {
                    shutterChannel?.invokeMethod(
                        "shutter",
                        mapOf("keyCode" to event.keyCode)
                    )
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
