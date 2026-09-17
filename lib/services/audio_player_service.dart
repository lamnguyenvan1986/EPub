import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:libri_audio/models/book_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  double _rate = 1.0;
  String? _currentBookId;
  int _currentChapter = 0;
  Duration _currentPosition = Duration.zero;
  bool _wakelockEnabled = false;

  bool get isPlaying => _isPlaying;
  double get rate => _rate;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  Duration get position => _audioPlayer.position;
  String? get currentBookId => _currentBookId;
  int get currentChapter => _currentChapter;
  Duration get currentPosition => _currentPosition;

  AudioPlayerService() {
    _initAudioSession();
    _audioPlayer.playerStateStream.listen(_onPlayerStateChange);
    _audioPlayer.positionStream.listen((pos) {
      _currentPosition = pos;
      notifyListeners();
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);
  }

  void _onPlayerStateChange(PlayerState state) {
    _isPlaying = state.playing;
    notifyListeners();
  }

  Future<void> playBook(Book book, int chapter) async {
    _currentBookId = book.id;
    _currentChapter = chapter;

    try {
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      print('Error playing book: $e');
    }
  }

  Future<void> play() async {
    // Enable wakelock to prevent device sleep
    if (!_wakelockEnabled) {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
    }

    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();

    // Disable wakelock after stopping
    if (_wakelockEnabled) {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
    }
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.5, 2.0);
    await _audioPlayer.setSpeed(_rate);
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
