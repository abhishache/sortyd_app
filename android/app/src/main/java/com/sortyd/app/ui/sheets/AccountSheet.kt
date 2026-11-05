package com.sortyd.app.ui.sheets

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.data.UserProfile
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.viewmodel.SortydViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSheet(
    viewModel: SortydViewModel,
    onDismiss: () -> Unit
) {
    val colors = SortydColors.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val currentUser by viewModel.currentUser.collectAsState()
    val isSyncing by viewModel.isSyncing.collectAsState()
    val lastSyncTime by viewModel.lastSyncTime.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()
    val allLists by viewModel.allLists.collectAsState()
    val localRegularCount = allLists.count { !it.isTodo && !it.isArchived }
    val localTaskCount = allLists.sumOf { it.tasks.size }

    var isSignUp by remember { mutableStateOf(false) }
    var showGooglePrompt by remember { mutableStateOf(false) }
    var googleEmail by remember { mutableStateOf("") }
    var googleName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(false) }
    var showSignOutConfirm by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.bg0,
        contentColor = colors.text0,
        dragHandle = { BottomSheetDefaults.DragHandle(color = colors.text2.copy(alpha = 0.4f)) }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 36.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            val user = currentUser
            if (user != null) {
                // ── Authenticated View ──
                Spacer(modifier = Modifier.height(8.dp))

                // Avatar
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(
                                listOf(colors.accent.copy(alpha = 0.35f), colors.coral.copy(alpha = 0.25f))
                            )
                        )
                        .border(1.5.dp, colors.accent.copy(alpha = 0.5f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    val initials = if (user.name.isNotBlank()) {
                        user.name.split(" ").filter { it.isNotBlank() }
                            .take(2).map { it.take(1) }.joinToString("").uppercase()
                    } else {
                        user.email.take(2).uppercase()
                    }
                    Text(
                        text = initials,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = colors.text0
                    )
                }

                Spacer(modifier = Modifier.height(14.dp))

                Text(
                    text = if (user.name.isNotBlank()) user.name else "Sortyd Member",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = colors.text0
                )
                Text(
                    text = user.email,
                    fontSize = 13.sp,
                    color = colors.text2
                )

                Spacer(modifier = Modifier.height(24.dp))

                // Cloud Sync Status Card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(colors.bg1.copy(alpha = 0.85f))
                        .border(1.dp, colors.borderSubtle, RoundedCornerShape(18.dp))
                        .padding(18.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        val rotation = remember { Animatable(0f) }
                        LaunchedEffect(isSyncing) {
                            if (isSyncing) {
                                rotation.animateTo(
                                    targetValue = 360f,
                                    animationSpec = infiniteRepeatable(
                                        animation = tween(1000, easing = LinearEasing),
                                        repeatMode = RepeatMode.Restart
                                    )
                                )
                            } else {
                                rotation.snapTo(0f)
                            }
                        }

                        Icon(
                            imageVector = if (isSyncing) Icons.Default.Refresh else Icons.Default.CloudDone,
                            contentDescription = "Sync Status",
                            tint = colors.accent,
                            modifier = Modifier
                                .size(24.dp)
                                .rotate(if (isSyncing) rotation.value else 0f)
                        )

                        Spacer(modifier = Modifier.width(12.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Cloud Sync Active",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = colors.text0
                            )
                            val syncText = if (isSyncing) {
                                "Syncing your data..."
                            } else if (lastSyncTime > 0) {
                                val sdf = SimpleDateFormat("h:mm a", Locale.getDefault())
                                "Last synced at ${sdf.format(Date(lastSyncTime))}"
                            } else {
                                "Not synced yet"
                            }
                            Text(
                                text = syncText,
                                fontSize = 12.sp,
                                color = colors.text2
                            )
                        }

                        if (isSyncing) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                color = colors.accent,
                                strokeWidth = 2.dp
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))
                    HorizontalDivider(color = Color.White.copy(alpha = 0.08f))
                    Spacer(modifier = Modifier.height(14.dp))

                    Text(
                        text = "Your habit lists, task history, and weekly plans are automatically synced across macOS, iOS, and Android.",
                        fontSize = 12.sp,
                        color = colors.text2,
                        lineHeight = 16.sp
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Sync Now Button
                    Button(
                        onClick = { viewModel.triggerCloudSync() },
                        enabled = !isSyncing,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = colors.accent.copy(alpha = 0.18f),
                            contentColor = colors.accent
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, colors.accent.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    ) {
                        Icon(
                            imageVector = Icons.Default.Sync,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = if (isSyncing) "Syncing..." else "Sync Now",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // Sign Out Button
                OutlinedButton(
                    onClick = { showSignOutConfirm = true },
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = colors.danger),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, colors.danger.copy(alpha = 0.3f), RoundedCornerShape(14.dp))
                ) {
                    Icon(
                        imageVector = Icons.Default.ExitToApp,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(text = "Sign Out", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                }

                if (showSignOutConfirm) {
                    AlertDialog(
                        onDismissRequest = { showSignOutConfirm = false },
                        containerColor = colors.bg1,
                        title = { Text("Sign out of Sortyd?", color = colors.text0, fontWeight = FontWeight.Bold) },
                        text = {
                            Text(
                                "Your local habit lists will remain on this phone, but won't sync to your other devices until you sign back in.",
                                color = colors.text1
                            )
                        },
                        confirmButton = {
                            TextButton(onClick = {
                                showSignOutConfirm = false
                                viewModel.signOut()
                            }) {
                                Text("Sign Out", color = colors.danger, fontWeight = FontWeight.Bold)
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = { showSignOutConfirm = false }) {
                                Text("Cancel", color = colors.text2)
                            }
                        }
                    )
                }

            } else {
                // ── Unauthenticated View ──
                Spacer(modifier = Modifier.height(8.dp))

                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(colors.accent.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.CloudQueue,
                        contentDescription = null,
                        tint = colors.accent,
                        modifier = Modifier.size(36.dp)
                    )
                }

                Spacer(modifier = Modifier.height(14.dp))

                Text(
                    text = "Sync Everywhere",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = colors.text0
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "Sign in via sortyd.com to back up your habits and seamlessly sync across your Mac, iPhone, and Android device.",
                    fontSize = 13.sp,
                    color = colors.text2,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )

                Spacer(modifier = Modifier.height(14.dp))

                // Safe Local List Migration Banner
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(colors.accent.copy(alpha = 0.10f))
                        .border(1.dp, colors.accent.copy(alpha = 0.28f), RoundedCornerShape(14.dp))
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.VerifiedUser,
                        contentDescription = null,
                        tint = colors.accent,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Automatic List Preservation",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = colors.text0
                        )
                        Text(
                            text = "Your $localRegularCount existing habit list${if (localRegularCount == 1) "" else "s"} and $localTaskCount task${if (localTaskCount == 1) "" else "s"} on this device will automatically merge into your account.",
                            fontSize = 11.5.sp,
                            color = colors.text2,
                            lineHeight = 15.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Continue with Google Button (Masked via auth.sortyd.com)
                OutlinedButton(
                    onClick = { showGooglePrompt = true },
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = colors.bg1,
                        contentColor = colors.text0
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .border(1.dp, colors.borderSubtle, RoundedCornerShape(14.dp))
                ) {
                    Box(
                        modifier = Modifier
                            .size(22.dp)
                            .clip(CircleShape)
                            .background(Color.White),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("G", fontSize = 13.sp, fontWeight = FontWeight.Black, color = Color(0xFF4285F4))
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "Continue with Google",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.text0
                    )
                }

                if (showGooglePrompt) {
                    AlertDialog(
                        onDismissRequest = { showGooglePrompt = false },
                        containerColor = colors.bg1,
                        title = {
                            Text("Continue with Google (sortyd.com)", color = colors.text0, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        },
                        text = {
                            Column {
                                Text(
                                    "Enter your Google account to sync your habit lists via auth.sortyd.com:",
                                    fontSize = 12.5.sp,
                                    color = colors.text2
                                )
                                Spacer(modifier = Modifier.height(12.dp))
                                OutlinedTextField(
                                    value = googleEmail,
                                    onValueChange = { googleEmail = it },
                                    label = { Text("Google Email (@gmail.com)", color = colors.text2) },
                                    singleLine = true,
                                    modifier = Modifier.fillMaxWidth()
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                OutlinedTextField(
                                    value = googleName,
                                    onValueChange = { googleName = it },
                                    label = { Text("Display Name", color = colors.text2) },
                                    singleLine = true,
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        },
                        confirmButton = {
                            TextButton(
                                enabled = googleEmail.contains("@") && !isLoading,
                                onClick = {
                                    isLoading = true
                                    viewModel.signInWithGoogle(googleEmail, googleName) { res ->
                                        isLoading = false
                                        showGooglePrompt = false
                                        if (res.isFailure) {
                                            errorMessage = res.exceptionOrNull()?.message ?: "Google Sign-In failed"
                                        }
                                    }
                                }
                            ) {
                                Text("Continue", color = colors.accent, fontWeight = FontWeight.Bold)
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = { showGooglePrompt = false }) {
                                Text("Cancel", color = colors.text2)
                            }
                        }
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Toggle Sign In / Create Account
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(colors.bg1)
                        .padding(4.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(9.dp))
                            .background(if (!isSignUp) colors.accent.copy(alpha = 0.22f) else Color.Transparent)
                            .clickable { isSignUp = false; errorMessage = null }
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Sign In",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (!isSignUp) colors.text0 else colors.text2
                        )
                    }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(9.dp))
                            .background(if (isSignUp) colors.accent.copy(alpha = 0.22f) else Color.Transparent)
                            .clickable { isSignUp = true; errorMessage = null }
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Create Account",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isSignUp) colors.text0 else colors.text2
                        )
                    }
                }

                if (errorMessage != null) {
                    Spacer(modifier = Modifier.height(14.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(colors.danger.copy(alpha = 0.12f))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            tint = colors.danger,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = errorMessage ?: "",
                            fontSize = 13.sp,
                            color = colors.danger
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                if (isSignUp) {
                    OutlinedTextField(
                        value = fullName,
                        onValueChange = { fullName = it },
                        label = { Text("Full Name", color = colors.text2) },
                        leadingIcon = { Icon(Icons.Default.Person, contentDescription = null, tint = colors.text2) },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = colors.text0,
                            unfocusedTextColor = colors.text0,
                            focusedBorderColor = colors.accent,
                            unfocusedBorderColor = colors.borderSubtle,
                            cursorColor = colors.accent
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }

                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email address", color = colors.text2) },
                    leadingIcon = { Icon(Icons.Default.Email, contentDescription = null, tint = colors.text2) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = colors.text0,
                        unfocusedTextColor = colors.text0,
                        focusedBorderColor = colors.accent,
                        unfocusedBorderColor = colors.borderSubtle,
                        cursorColor = colors.accent
                    ),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(modifier = Modifier.height(12.dp))

                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password (min 6 characters)", color = colors.text2) },
                    leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null, tint = colors.text2) },
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = colors.text0,
                        unfocusedTextColor = colors.text0,
                        focusedBorderColor = colors.accent,
                        unfocusedBorderColor = colors.borderSubtle,
                        cursorColor = colors.accent
                    ),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(modifier = Modifier.height(24.dp))

                val isFormValid = email.isNotBlank() && password.length >= 6 && (!isSignUp || fullName.isNotBlank())
                Button(
                    onClick = {
                        errorMessage = null
                        isLoading = true
                        if (isSignUp) {
                            viewModel.signUp(email, password, fullName) { result ->
                                isLoading = false
                                if (result.isFailure) {
                                    errorMessage = result.exceptionOrNull()?.message ?: "Sign up failed"
                                }
                            }
                        } else {
                            viewModel.signIn(email, password) { result ->
                                isLoading = false
                                if (result.isFailure) {
                                    errorMessage = result.exceptionOrNull()?.message ?: "Sign in failed"
                                }
                            }
                        }
                    },
                    enabled = isFormValid && !isLoading,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = colors.accent,
                        contentColor = Color.Black
                    ),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp)
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(
                            color = Color.Black,
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp
                        )
                    } else {
                        Text(
                            text = if (isSignUp) "Create Account" else "Sign In",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}
