// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
package vn.bvdkkh.remote

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.hjq.permissions.OnPermissionCallback
import com.hjq.permissions.XXPermissions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal object SupportTicketNotifications {
    private const val AUDIBLE_CHANNEL = "bvdkkh_support_tickets"
    private const val SILENT_CHANNEL = "bvdkkh_support_tickets_silent"

    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "bvdkkh/support_notifications").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "requestPermission" -> requestPermission(activity, result)
                    "show" -> {
                        show(activity, call)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_arguments", error.message, null)
            } catch (error: SecurityException) {
                result.error("notifications_disabled", error.message, null)
            } catch (error: Exception) {
                result.error("notification_failed", error.message, null)
            }
        }
    }

    private fun requestPermission(activity: Activity, result: MethodChannel.Result) {
        createChannels(activity)
        if (Build.VERSION.SDK_INT < 33 ||
            XXPermissions.isGranted(activity, Manifest.permission.POST_NOTIFICATIONS)) {
            result.success(NotificationManagerCompat.from(activity).areNotificationsEnabled())
            return
        }
        XXPermissions.with(activity)
            .permission(Manifest.permission.POST_NOTIFICATIONS)
            .request(object : OnPermissionCallback {
                override fun onGranted(permissions: MutableList<String>, allGranted: Boolean) {
                    result.success(allGranted &&
                        NotificationManagerCompat.from(activity).areNotificationsEnabled())
                }

                override fun onDenied(permissions: MutableList<String>, doNotAskAgain: Boolean) {
                    result.success(false)
                }
            })
    }

    private fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(
            AUDIBLE_CHANNEL, "Phiếu hỗ trợ", NotificationManager.IMPORTANCE_HIGH))
        manager.createNotificationChannel(NotificationChannel(
            SILENT_CHANNEL, "Phiếu hỗ trợ (im lặng)", NotificationManager.IMPORTANCE_HIGH).apply {
            setSound(null, null)
            enableVibration(false)
        })
    }

    @SuppressLint("MissingPermission")
    private fun show(activity: Activity, call: MethodCall) {
        val ticketId = when (val id = call.argument<Any>("id")) {
            is Int -> id.toLong()
            is Long -> id
            else -> null
        }
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        val sound = call.argument<Boolean>("sound")
        require(ticketId != null && ticketId > 0 &&
            !title.isNullOrBlank() && !body.isNullOrBlank() && sound != null) {
            "A positive ticket id, title, body and sound flag are required"
        }
        val notifications = NotificationManagerCompat.from(activity)
        if (!notifications.areNotificationsEnabled() ||
            (Build.VERSION.SDK_INT >= 33 &&
                !XXPermissions.isGranted(activity, Manifest.permission.POST_NOTIFICATIONS))) {
            throw SecurityException("Support ticket notifications are disabled in Android settings")
        }
        createChannels(activity)
        val channelId = if (sound) AUDIBLE_CHANNEL else SILENT_CHANNEL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(channelId)?.importance == NotificationManager.IMPORTANCE_NONE) {
                throw SecurityException("The support ticket notification channel is disabled")
            }
        }
        val intent = Intent(activity, MainActivity::class.java).apply {
            action = "vn.bvdkkh.remote.SUPPORT_TICKET.$ticketId"
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("support_ticket_id", ticketId)
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getActivity(activity, 0, intent, pendingFlags)
        val notification = NotificationCompat.Builder(activity, channelId)
            .setSmallIcon(R.mipmap.ic_stat_logo)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDefaults(if (sound) Notification.DEFAULT_SOUND else 0)
            .setSilent(!sound)
            .build()
        notifications.notify("support-ticket-$ticketId", 0, notification)
    }
}
