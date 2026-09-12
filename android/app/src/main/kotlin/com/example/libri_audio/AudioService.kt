package com.example.libri_audio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class AudioService : Service() {
    companion object {
        const val CHANNEL_ID = "libri_audio_channel"
        const val NOTIFICATION_ID = 1
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "LibriAudio Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Audio playback service"
                setShowBadge(false)
                setImportance(NotificationManager.IMPORTANCE_LOW)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("LibriAudio")
            .setContentText("Đang phát audio...")
            .setSmallIcon(android.R.drawable.ic_menu_music)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
