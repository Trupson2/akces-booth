# third_party

Lokalne forki zewnetrznych pakietow z drobnymi patchami.

## camera_android_camerax

Fork `camera_android_camerax-0.6.30` (pub.dev) z wlaczona preview + video
stabilization. Stock plugin nie wlacza tych opcji w `Preview.Builder` /
`VideoCapture.Builder`, wiec CameraX jedzie bez EIS pomimo wsparcia sprzetu.

### Zmiany

- `android/src/main/java/io/flutter/plugins/camerax/PreviewProxyApi.java`
  — `builder.setPreviewStabilizationEnabled(true)` (API 33+, CameraX 1.3+)
- `android/src/main/java/io/flutter/plugins/camerax/VideoCaptureProxyApi.java`
  — `builder.setVideoStabilizationEnabled(true)` (CameraX 1.3+)

Oba w `try/catch` zeby nie zabic builderu na urzadzeniach bez wsparcia.

### Jak podmieniono

W `recorder/pubspec.yaml`:

```yaml
dependency_overrides:
  camera_android_camerax:
    path: third_party/camera_android_camerax
```

### Aktualizacja

Przy bumpie `camera`/`camera_android_camerax` w pubspec: skopiowac nowa wersje
z `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\camera_android_camerax-X.Y.Z\` tutaj
i nalozyc patch z `git log` tego katalogu.

### Diagnostyka

Czy fork dziala: `adb logcat | grep -E "AkcesBoothFork|CameraDiag|applyVideoStabilization"`.
W logu powinno byc `applyVideoStabilization: mode = 2` (PREVIEW_STABILIZATION)
lub `= 1` (basic EIS) zamiast `mode = null`.
