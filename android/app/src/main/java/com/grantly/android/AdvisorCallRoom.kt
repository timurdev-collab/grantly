package com.grantly.android

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import io.livekit.android.renderer.TextureViewRenderer
import io.livekit.android.events.collect
import io.livekit.android.events.RoomEvent
import io.livekit.android.room.Room
import io.livekit.android.room.track.VideoTrack
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Initial Android call UI for an EXISTING advisor call. Never creates a call.
 * Capture requires an explicit opt-in and OS permission. Navigating away or
 * backgrounding the app disconnects; no recording or background calls.
 * Authenticated end-to-end call behavior is NOT yet verified.
 */
@Composable
internal fun AdvisorCallRoomContent(call: AdvisorCallListItem, userId: String, onClose: () -> Unit) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()
    val session = remember(userId, call.id) {
        AdvisorLiveKitRoomSession(context.applicationContext)
    }
    var room by remember(userId, call.id) { mutableStateOf<Room?>(null) }
    var joining by remember(userId, call.id) { mutableStateOf(false) }
    var microphoneEnabled by remember(userId, call.id) { mutableStateOf(true) }
    var cameraEnabled by remember(userId, call.id) { mutableStateOf(true) }
    var changingMedia by remember(userId, call.id) { mutableStateOf(false) }
    var consent by remember(userId, call.id) { mutableStateOf(false) }
    var error by remember(userId, call.id) { mutableStateOf<String?>(null) }
    var permissionVersion by remember(userId, call.id) { mutableIntStateOf(0) }
    var trackVersion by remember(userId, call.id) { mutableIntStateOf(0) }

    val requestPermissions = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissionVersion++ }
    val permissionsGranted = remember(permissionVersion, context) {
        context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED &&
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    fun close() {
        // Invalidate the Join synchronously, before navigation can cancel UI work.
        // Coroutine teardown still disconnects and releases any connected room.
        session.invalidatePendingJoin()
        scope.launch { session.leave() }
        onClose()
    }
    BackHandler { close() }

    // Cancellation on navigation/sign-out guarantees teardown even if Join
    // is still awaiting network credentials or a slow LiveKit connection.
    LaunchedEffect(session) {
        try {
            awaitCancellation()
        } finally {
            withContext(NonCancellable) { session.leave() }
        }
    }
    DisposableEffect(owner, session) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                // Permissions may have changed in system Settings while paused.
                permissionVersion++
            }
            if (event == Lifecycle.Event.ON_STOP) {
                // Never wait for a scheduled coroutine to invalidate a slow Join.
                session.invalidatePendingJoin()
                scope.launch {
                    session.leave()
                    room = null
                    joining = false
                }
            }
        }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }

    // A live call must not survive account changes or permission revocation.
    LaunchedEffect(room, userId) {
        if (room == null) return@LaunchedEffect
        while (true) {
            delay(1_000)
            val stillAuthorized = AuthRepository.session?.userId == userId &&
                context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED &&
                context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
            if (!stillAuthorized) {
                session.leave()
                room = null
                error = "Call ended because your account or permissions changed."
                break
            }
        }
    }
    LaunchedEffect(room) {
        val current = room ?: return@LaunchedEffect
        current.events.collect { event ->
            trackVersion++
            if (event is RoomEvent.Disconnected) {
                // Updating room state cancels this effect; finish release first.
                withContext(NonCancellable) { session.leave() }
                room = null
                error = "The call disconnected. You can try joining again."
            }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedButton(onClick = { close() }) { Text("Back to calls / Leave") }
        Text("Video call with " + call.studentName.ifBlank { "Student" },
            style = MaterialTheme.typography.titleLarge)
        Text("Status: " + AdvisorCallListRules.label(call.status))
        Text("No recording is started by this Android screen.",
            style = MaterialTheme.typography.bodySmall)
        if (room == null) {
            androidx.compose.foundation.layout.Row {
                Checkbox(checked = consent, onCheckedChange = { consent = it }, enabled = !joining)
                Text("I agree to turn on my camera and microphone when I join.")
            }
            if (!permissionsGranted) {
                OutlinedButton(enabled = !joining, onClick = {
                    requestPermissions.launch(arrayOf(
                        Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO
                    ))
                }) { Text("Allow camera and microphone") }
            }
            OutlinedButton(
                enabled = consent && permissionsGranted && !joining,
                onClick = {
                    joining = true
                    error = null
                    scope.launch {
                        try {
                            val connected = session.joinExistingCall(call.id, userId, captureConsent = true)
                            if (AuthRepository.session?.userId == userId) {
                                microphoneEnabled = true
                                cameraEnabled = true
                                room = connected
                            } else {
                                session.leave()
                                error = "Your account changed. Sign in again."
                            }
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Unable to join the call."
                        } finally {
                            joining = false
                        }
                    }
                }
            ) { Text(if (joining) "Connecting..." else "Join existing call") }
            if (joining) CircularProgressIndicator()
        } else {
            val connected = room!!
            // Reading the track lists after room events also covers participants
            // who were already connected when the advisor joined.
            @Suppress("UNUSED_VARIABLE") val refreshTracks = trackVersion
            val remote = connected.remoteParticipants.values
                .flatMap { it.videoTrackPublications }
                .mapNotNull { it.second as? VideoTrack }
                .firstOrNull()
            val local = connected.localParticipant.videoTrackPublications
                .mapNotNull { it.second as? VideoTrack }.firstOrNull()
            Text(if (remote == null) "Waiting for the other participant's video..." else "Participant video")
            if (remote != null) {
                AdvisorVideoTrack(room = connected, track = remote,
                    modifier = Modifier.fillMaxWidth().height(220.dp))
            }
            Text(if (cameraEnabled) "Your camera preview" else "Your camera is off")
            if (cameraEnabled && local != null) {
                AdvisorVideoTrack(room = connected, track = local,
                    modifier = Modifier.fillMaxWidth().height(130.dp), mirror = true)
            } else {
                if (cameraEnabled) Text("Camera preview unavailable.")
            }
            OutlinedButton(
                enabled = !changingMedia,
                onClick = {
                    if (!changingMedia) {
                        changingMedia = true
                        val enable = !microphoneEnabled
                        scope.launch {
                            try {
                                session.setMicrophoneEnabled(userId, enable)
                                if (room === connected) microphoneEnabled = enable
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (failure: Exception) {
                                error = failure.message ?: "Unable to change microphone."
                            } finally {
                                changingMedia = false
                            }
                        }
                    }
                }
            ) { Text(if (microphoneEnabled) "Mute microphone" else "Unmute microphone") }
            OutlinedButton(
                enabled = !changingMedia,
                onClick = {
                    if (!changingMedia) {
                        changingMedia = true
                        val enable = !cameraEnabled
                        scope.launch {
                            try {
                                session.setCameraEnabled(userId, enable)
                                if (room === connected) cameraEnabled = enable
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (failure: Exception) {
                                error = failure.message ?: "Unable to change camera."
                            } finally {
                                changingMedia = false
                            }
                        }
                    }
                }
            ) { Text(if (cameraEnabled) "Turn camera off" else "Turn camera on") }
            OutlinedButton(onClick = {
                scope.launch {
                    session.leave()
                    room = null
                }
            }) { Text("Leave call and stop camera/microphone") }
        }
        if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
    }
}

/** Use the LiveKit SDK's renderer directly; no separate Compose Components dependency. */
@Composable
private fun AdvisorVideoTrack(room: Room, track: VideoTrack, modifier: Modifier, mirror: Boolean = false) {
    val context = LocalContext.current
    val renderer = remember(room) {
        TextureViewRenderer(context).also { room.initVideoRenderer(it) }
    }
    DisposableEffect(renderer, track, mirror) {
        renderer.setMirror(mirror)
        track.addRenderer(renderer)
        onDispose { track.removeRenderer(renderer) }
    }
    DisposableEffect(renderer) {
        onDispose { renderer.release() }
    }
    AndroidView(factory = { renderer }, modifier = modifier)
}
