package com.grantly.android

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.io.IOException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypts Supabase session tokens with a non-exportable Android Keystore AES-GCM key.
 * SharedPreferences contains only ciphertext and a random IV; Android backup is disabled.
 * Corrupt or undecryptable entries are discarded rather than restoring invalid credentials.
 */
internal class EncryptedSessionStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "edut_encrypted_auth_v1", Context.MODE_PRIVATE
    )
    private val alias = "edut_session_aes_gcm_v1"
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun secretKey(): SecretKey {
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(
                    alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setRandomizedEncryptionRequired(true)
                    .build()
            )
        }.generateKey()
    }

    fun save(session: AuthSession) {
        val plain = JSONObject()
            .put("userId", session.userId)
            .put("email", session.email)
            .put("accessToken", session.accessToken)
            .put("refreshToken", session.refreshToken)
            .put("expiresAtMs", session.expiresAtMs)
            .toString().toByteArray(Charsets.UTF_8)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val encrypted = Base64.encodeToString(cipher.doFinal(plain), Base64.NO_WRAP)
        if (!preferences.edit().putString("session", "$iv:$encrypted").commit()) {
            throw IOException("Unable to save encrypted session.")
        }
    }

    fun load(): AuthSession? {
        val value = preferences.getString("session", null) ?: return null
        return try {
            val parts = value.split(':', limit = 2)
            require(parts.size == 2)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE, secretKey(),
                GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP))
            )
            val json = JSONObject(
                String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8)
            )
            val restored = AuthSession(
                userId = json.getString("userId"),
                email = json.getString("email"),
                accessToken = json.getString("accessToken"),
                refreshToken = json.getString("refreshToken"),
                expiresAtMs = json.getLong("expiresAtMs")
            )
            require(restored.userId.isNotBlank() && restored.accessToken.isNotBlank() &&
                restored.refreshToken.isNotBlank() && restored.expiresAtMs > 0)
            restored
        } catch (_: Exception) {
            clear()
            null
        }
    }

    fun clear() {
        preferences.edit().remove("session").commit()
    }
}
