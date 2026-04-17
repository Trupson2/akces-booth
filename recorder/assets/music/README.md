# Music library

Wrzuc tu pliki MP3 nazwane `track_01.mp3` - `track_10.mp3`.

Nazwy musza pasowac do `MusicLibrary.knownTracks` w kodzie
(`lib/services/music_library.dart`).

Jesli chcesz dodac 11 track - dopisz `track_11.mp3` i dodaj do listy.

**Uwagi:**
- Rozmiar zalecany: < 5 MB / plik (APK urosnie o sume)
- Dlugosc: >= 20s (dla krotszych FFmpeg zapetli)
- Format: MP3 preferowany, M4A/WAV/OGG OK

**TODO (przed produkcja):** switch na royalty-free (Mixkit, Pixabay,
YouTube Audio Library). Obecne dla dev - Instagram mutuje copyright automatycznie.
