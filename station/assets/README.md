# Station assets

## mock_video.mp4

PreviewScreen oczekuje pliku `assets/mock_video.mp4`. Na MVP Sesji 3 brak pliku
jest OK - PreviewScreen pokazuje wtedy placeholder z komunikatem.

Wygeneruj prawdziwy sample (5s, color bars, 1920x1080 @ 30fps):

```bash
ffmpeg -f lavfi -i testsrc=duration=5:size=1920x1080:rate=30 \
       -f lavfi -i sine=frequency=440:duration=5 \
       -c:v libx264 -c:a aac -shortest assets/mock_video.mp4
```

Albo wrzuc jakikolwiek maly MP4 (<= 10MB) pod ta nazwa.
Po dodaniu pliku zrob `flutter clean && flutter run`.
