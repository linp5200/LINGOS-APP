package com.lingos.app.network

import java.security.SecureRandom

object Security {
    private const val AUTH_CODE_LENGTH = 6
    private const val CONNECTION_CODE_LENGTH = 12
    private const val CONNECTION_CODE_EXPIRE_SECONDS = 300
    private val secureRandom = SecureRandom()
    private val codeChars = ('A'..'Z') + ('0'..'9')
    private val pendingCodes = mutableMapOf<String, Long>()

    fun generateAuthCode(): String = (1..AUTH_CODE_LENGTH).map { codeChars[secureRandom.nextInt(codeChars.size)] }.joinToString("")
    fun generateConnectionCode(): String { val parts = (1..3).map { (1..4).map { codeChars[secureRandom.nextInt(codeChars.size)] }.joinToString("") }; return parts.joinToString("-") }
    fun verifyConnectionCode(code: String): Boolean { val normalized = code.trim().uppercase(); val entry = pendingCodes[normalized] ?: return false; val expireTime = entry + CONNECTION_CODE_EXPIRE_SECONDS * 1000L; if (System.currentTimeMillis() > expireTime) { pendingCodes.remove(normalized); return false }; pendingCodes.remove(normalized); return true }
    fun storeConnectionCode(code: String) { pendingCodes[code] = System.currentTimeMillis() }
    fun cleanupExpiredCodes() { val now = System.currentTimeMillis(); pendingCodes.entries.removeAll { entry -> val expireTime = entry.value + CONNECTION_CODE_EXPIRE_SECONDS * 1000L; now > expireTime } }
    fun generateSessionId(): String { val bytes = ByteArray(16); secureRandom.nextBytes(bytes); return bytes.joinToString("") { "%02x".format(it) } }
    fun hashCode(code: String): String { val bytes = code.toByteArray(); val digest = java.security.MessageDigest.getInstance("SHA-256"); val hash = digest.digest(bytes); return hash.joinToString("") { "%02x".format(it) } }
    fun verifyAuthCode(code: String): Boolean = code.length >= AUTH_CODE_LENGTH && code.all { it.isLetterOrDigit() }
}
