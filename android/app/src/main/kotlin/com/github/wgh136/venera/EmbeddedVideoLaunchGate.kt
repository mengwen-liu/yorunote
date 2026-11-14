package com.github.wgh136.venera

/** All calls are made on the Activity's main thread. */
internal class EmbeddedVideoLaunchGate {
    var pending = false
        private set

    fun acquire(): Boolean {
        if (pending) return false
        pending = true
        return true
    }

    fun release() {
        pending = false
    }
}
