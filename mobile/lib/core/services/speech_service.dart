import 'package:speech_to_text/speech_to_text.dart';

final class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize();
    return _initialized;
  }

  Future<bool> start({required void Function(String text, bool finalResult) onText}) async {
    if (!await initialize()) return false;
    await _speech.listen(
      onResult: (result) => onText(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: 'tr_TR',
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        autoPunctuation: true,
        enableHapticFeedback: true,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
      ),
    );
    return true;
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}
