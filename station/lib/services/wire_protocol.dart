/// Wspolny protokol WebSocket miedzy Station a Recorder.
///
/// Stringi sa zdublowane w recorder/lib/services/wire_protocol.dart - trzymajmy
/// je zsynchronizowane (to MVP, pakiet wspolny dopiero w Sesji 5+).
class WireMsg {
  // Station -> Recorder
  static const startRecording = 'start_recording';
  static const stopRecording = 'stop_recording';
  static const eventConfig = 'event_config';
  static const ping = 'ping';

  // Recorder -> Station
  static const recordingStarted = 'recording_started';
  static const recordingProgress = 'recording_progress';
  static const recordingStopped = 'recording_stopped';
  static const processingProgress = 'processing_progress';
  static const processingDone = 'processing_done';
  static const uploadProgress = 'upload_progress';
  static const error = 'error';
  static const pong = 'pong';
}
