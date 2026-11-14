package com.github.wgh136.venera

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmbeddedVideoLaunchGateTest {
    @Test fun rejectsDuplicateUntilActivityReturns() {
        val gate = EmbeddedVideoLaunchGate()
        assertTrue(gate.acquire())
        assertTrue(gate.pending)
        assertFalse(gate.acquire())
        gate.release()
        assertFalse(gate.pending)
        assertTrue(gate.acquire())
    }
}
