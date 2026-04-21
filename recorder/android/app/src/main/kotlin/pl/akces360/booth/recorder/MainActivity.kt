package pl.akces360.booth.recorder

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel dla diagnostyki EIS (Electronic Image Stabilization).
 *
 * Dart wywoluje `getBackCameraStabilization()` zeby dowiedziec sie jakie
 * tryby stabilizacji wspiera back camera (OP13 powinien miec PREVIEW_STAB
 * na API 33+). Nie WLACZAMY tu stabilizacji - Flutter `camera` plugin nie
 * wystawia API do tego, potrzebny by byl fork `camera_android_camerax`.
 * Ten channel jest source-of-truth dla decyzji czy warto forkac.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "akces_booth/camera_diag"
        private const val TAG = "CameraDiag"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBackCameraStabilization" -> {
                        result.success(queryBackCameraStabilization())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun queryBackCameraStabilization(): Map<String, Any?> {
        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        return try {
            val backId = cm.cameraIdList.firstOrNull { id ->
                val c = cm.getCameraCharacteristics(id)
                c.get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_BACK
            } ?: return mapOf("ok" to false, "error" to "no back camera")

            val ch = cm.getCameraCharacteristics(backId)

            // CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES:
            //   0=OFF, 1=ON, 2=PREVIEW_STABILIZATION (API 33+)
            val videoModes = ch.get(
                CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES
            )?.toList() ?: emptyList()

            // LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION:
            //   0=OFF, 1=ON
            val opticalModes = ch.get(
                CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION
            )?.toList() ?: emptyList()

            val hasPreviewStab = videoModes.contains(
                CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_PREVIEW_STABILIZATION
            )
            val hasBasicEis = videoModes.contains(
                CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON
            )
            val hasOis = opticalModes.contains(
                CameraMetadata.LENS_OPTICAL_STABILIZATION_MODE_ON
            )

            val out = mapOf(
                "ok" to true,
                "camera_id" to backId,
                "api_level" to Build.VERSION.SDK_INT,
                "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
                "video_stab_modes" to videoModes,
                "optical_stab_modes" to opticalModes,
                "has_preview_stabilization" to hasPreviewStab,
                "has_basic_eis" to hasBasicEis,
                "has_ois" to hasOis,
            )
            Log.i(TAG, "Back camera stabilization: $out")
            out
        } catch (e: Throwable) {
            Log.e(TAG, "queryBackCameraStabilization failed", e)
            mapOf("ok" to false, "error" to (e.message ?: "unknown"))
        }
    }
}
