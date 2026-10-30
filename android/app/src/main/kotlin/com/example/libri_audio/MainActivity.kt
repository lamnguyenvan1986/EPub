package com.example.libri_audio

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity giữ Flutter engine sống để audio_service phát TTS nền.
// Plugin được đăng ký tự động, không cần gọi GeneratedPluginRegistrant thủ công.
class MainActivity : AudioServiceActivity()
