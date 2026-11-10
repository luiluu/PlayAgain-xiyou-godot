package local.kyo.xiyou.bgidle

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.util.Log
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot

/**
 * GDScript 侧：Engine.get_singleton("XiyouBgIdle")（cc 平台 android-bgidle1）。
 * - setArmed(true)：挂机中，切后台（onMainPause）时起前台服务；false 就不起。
 * - 回前台（onMainResume）关服务，记下这次离开了多少毫秒（含锁屏睡眠）；按了通知上的「停止挂机」只算到按的那一刻。
 * - lastAwayMsec()：上一次由服务陪着的离开时长；-1＝那次没起服务（没挂机、起服务失败），GDScript 退回旧补跑（O-201）。
 * Godot 的回前台通知（NOTIFICATION_APPLICATION_RESUMED）在渲染线程恢复后才到，晚于这里的 onMainResume。
 */
class XiyouBgIdlePlugin(godot: Godot) : GodotPlugin(godot) {
    @Volatile
    private var armed = false
    private var pausedAt = -1L
    private var serviceStarted = false
    @Volatile
    private var lastAway = -1L
    @Volatile
    private var lastStopped = false
    @Volatile
    private var startCount = 0

    override fun getPluginName() = "XiyouBgIdle"

    @UsedByGodot
    fun setArmed(on: Boolean) {
        armed = on
    }

    @UsedByGodot
    fun isArmed(): Boolean = armed

    @UsedByGodot
    fun isServiceRunning(): Boolean = XiyouIdleService.running

    /** 起过几次服务（冒烟脚本看计数）。 */
    @UsedByGodot
    fun serviceStartCount(): Int = startCount

    @UsedByGodot
    fun lastAwayMsec(): Long = lastAway

    @UsedByGodot
    fun lastStoppedByUser(): Boolean = lastStopped

    /** 安卓 13+ 要运行时申请通知权限；不给也能起服务，只是通知不显示。已有或不需要时返回 true。 */
    @UsedByGodot
    fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val act = activity ?: return false
        if (act.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return true
        act.runOnUiThread { act.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2061) }
        return false
    }

    override fun onMainPause() {
        super.onMainPause()
        pausedAt = SystemClock.elapsedRealtime()
        serviceStarted = false
        if (!armed) return
        val ctx = activity ?: return
        serviceStarted = XiyouIdleService.start(ctx.applicationContext)
        if (serviceStarted) startCount += 1
        Log.i(XiyouIdleService.TAG, "切后台：挂机中，起服务 $serviceStarted")
    }

    override fun onMainResume() {
        super.onMainResume()
        if (pausedAt < 0) return
        val now = SystemClock.elapsedRealtime()
        if (serviceStarted) {
            val stopAt = XiyouIdleService.stopRequestedAt
            lastStopped = stopAt in pausedAt..now
            lastAway = (if (lastStopped) stopAt else now) - pausedAt
            activity?.let { XiyouIdleService.stop(it.applicationContext) }
            Log.i(XiyouIdleService.TAG, "回前台：离开 $lastAway 毫秒，点过停止 $lastStopped")
        } else {
            lastAway = -1L
            lastStopped = false
        }
        serviceStarted = false
        pausedAt = -1L
    }

    override fun onMainDestroy() {
        activity?.let { XiyouIdleService.stop(it.applicationContext) }
        super.onMainDestroy()
    }
}
