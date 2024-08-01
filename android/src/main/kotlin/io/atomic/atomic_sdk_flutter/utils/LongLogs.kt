package io.atomic.atomic_sdk_flutter.utils

import android.util.Log

/// Internal method used for logging really long strings because android has a limit on the length of a log.
fun longLog(tag : String, msg : String) {
    val maxLogSize = 1000
    for (i in 0..msg.length/ maxLogSize) {
        val start = i * maxLogSize
        var end = (i + 1) * maxLogSize
        if (end > msg.length) {
            end = msg.length
        }
        Log.v(tag, msg.substring(start, end))
    }
}