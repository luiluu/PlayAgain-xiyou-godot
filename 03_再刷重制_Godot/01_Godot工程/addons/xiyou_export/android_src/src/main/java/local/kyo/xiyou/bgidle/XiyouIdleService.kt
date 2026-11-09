package local.kyo.xiyou.bgidle

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log

/**
 * 后台挂机前台服务（cc 平台 android-bgidle1，Kyo 2026-11-09 定 C）。
 * 只管保活与通知：通知栏常驻（计时显示离开多久）、点通知回游戏、「停止挂机」按钮。
 * Godot 切后台主循环会停，离开的时间由 GDScript 回前台时补跑（core/platform.gd）。
 */
class XiyouIdleService : Service() {
    companion object {
        const val TAG = "XiyouBgIdle"
        const val ACTION_START = "local.kyo.xiyou.bgidle.START"
        const val ACTION_STOP = "local.kyo.xiyou.bgidle.STOP"
        const val CHANNEL_ID = "xiyou_idle"
        const val NOTIFICATION_ID = 2061

        /** 服务在跑（onStartCommand 起、onDestroy 落）。 */
        @Volatile
        var running = false

        /** 玩家在通知上点了「停止挂机」的时刻（elapsedRealtime 毫秒）；没点是 -1。 */
        @Volatile
        var stopRequestedAt = -1L

        fun start(context: Context): Boolean {
            stopRequestedAt = -1L
            val intent = Intent(context, XiyouIdleService::class.java).setAction(ACTION_START)
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (e: Exception) {
                // Android 12+ 已在后台时不许起前台服务（ForegroundServiceStartNotAllowedException）：退回旧补跑
                Log.w(TAG, "起前台服务失败：$e")
                false
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, XiyouIdleService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRequestedAt = SystemClock.elapsedRealtime()
            Log.i(TAG, "通知上点了停止挂机")
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            running = true
            Log.i(TAG, "前台服务已起")
        } catch (e: Exception) {
            Log.w(TAG, "startForeground 失败：$e")
            stopSelf()
        }
        // 进程被系统杀了不重启服务：游戏不在了，服务留着没有意义
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        Log.i(TAG, "前台服务已停")
        super.onDestroy()
    }

    /** 玩家从最近任务里划掉游戏：服务跟着停。 */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopForegroundCompat()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(CHANNEL_ID, "后台挂机", NotificationManager.IMPORTANCE_LOW)
                channel.description = "挂机中切到后台时常驻，回到游戏自动消失"
                channel.setShowBadge(false)
                manager.createNotificationChannel(channel)
            }
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val immutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        }
        if (launch != null) {
            builder.setContentIntent(PendingIntent.getActivity(this, 0, launch, immutable or PendingIntent.FLAG_UPDATE_CURRENT))
        }
        val stopIntent = Intent(this, XiyouIdleService::class.java).setAction(ACTION_STOP)
        val stopPending = PendingIntent.getService(this, 1, stopIntent, immutable or PendingIntent.FLAG_UPDATE_CURRENT)
        val label = try {
            applicationInfo.loadLabel(packageManager).toString()
        } catch (e: Exception) {
            "再刷一把"
        }
        builder.setSmallIcon(R.drawable.xiyou_idle_notify)
            .setContentTitle("$label · 挂机中")
            .setContentText("回到游戏时按离开的时间补上挂机")
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        @Suppress("DEPRECATION")
        builder.addAction(Notification.Action.Builder(null, "停止挂机", stopPending).build())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }
}
