package com.sortyd.app.ui.screens.settings

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sortyd.app.model.AppLanguage
import com.sortyd.app.ui.components.GlassCard
import com.sortyd.app.ui.theme.*
import com.sortyd.app.viewmodel.AppViewModel

@Composable
fun SettingsScreen(vm: AppViewModel = hiltViewModel()) {
    val c = sortydColors
    val isDark by vm.isDarkTheme.collectAsStateWithLifecycle()
    val lang by vm.appLanguage.collectAsStateWithLifecycle()

    var showClearConfirm by remember { mutableStateOf(false) }

    if (showClearConfirm) {
        AlertDialog(
            onDismissRequest = { showClearConfirm = false },
            containerColor = Color(0xFF141414),
            title = { Text("CLEAR HISTORY?", style = MaterialTheme.typography.titleLarge.copy(color = Color.White, fontWeight = FontWeight.Black, letterSpacing = 1.sp)) },
            text = { Text("This will delete all completion history and analytics. Your lists and tasks will remain.", style = MaterialTheme.typography.bodyMedium.copy(color = Color.White.copy(alpha = 0.6f))) },
            confirmButton = {
                TextButton(onClick = { vm.clearHistory(); showClearConfirm = false }) {
                    Text("CLEAR", color = Color(0xFFFF5252), fontWeight = FontWeight.Black, letterSpacing = 1.sp)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearConfirm = false }) { 
                    Text("CANCEL", color = Color.White.copy(alpha = 0.4f), fontWeight = FontWeight.Black, letterSpacing = 1.sp) 
                }
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A))
            .verticalScroll(rememberScrollState())
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(top = 24.dp, bottom = 12.dp, start = 24.dp, end = 24.dp), 
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "SETTINGS", 
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = c.teal, 
                        fontWeight = FontWeight.Black,
                        letterSpacing = 1.5.sp
                    )
                )
            }
            Text(
                "SORTYD V1.3", 
                style = MaterialTheme.typography.labelSmall.copy(
                    color = Color.White.copy(alpha = 0.2f),
                    fontWeight = FontWeight.Bold
                )
            )
        }

        // Appearance Section
        SettingsSection(title = "APPEARANCE") {
            SettingsToggleRow(
                icon = if (isDark) Icons.Default.NightsStay else Icons.Default.LightMode,
                title = if (isDark) "Dark Mode" else "Light Mode",
                subtitle = "Deep obsidian aesthetic",
                checked = isDark,
                onToggle = { vm.toggleTheme() }
            )
        }

        // Language Section
        SettingsSection(title = "LANGUAGE") {
            Column(modifier = Modifier.padding(vertical = 4.dp)) {
                AppLanguage.entries.forEachIndexed { index, language ->
                    SettingsSelectRow(
                        title = language.displayName,
                        isSelected = lang == language,
                        onClick = { vm.setLanguage(language) }
                    )
                    if (index < AppLanguage.entries.size - 1) {
                        HorizontalDivider(
                            color = Color.White.copy(alpha = 0.05f),
                            thickness = 0.5.dp,
                            modifier = Modifier.padding(horizontal = 4.dp)
                        )
                    }
                }
            }
        }

        // Data Section
        SettingsSection(title = "DATA & PRIVACY") {
            SettingsActionRow(
                icon = Icons.Default.DeleteForever,
                title = "Clear History",
                subtitle = "Reset all progress data",
                color = Color(0xFFFF5252),
                onClick = { showClearConfirm = true }
            )
        }

        // About Section
        SettingsSection(title = "SYSTEM INFO") {
            SettingsInfoRow("VERSION", "1.3.0")
            SettingsInfoRow("PLATFORM", "ANDROID 14")
            SettingsInfoRow("ENGINE", "COMPOSE M3")
            SettingsInfoRow("AI CORE", "LLAMA 3.1")
        }

        Spacer(Modifier.height(140.dp))
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 10.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.labelSmall.copy(
                color = Color.White.copy(alpha = 0.4f),
                fontWeight = FontWeight.Black,
                letterSpacing = 2.sp
            ),
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp)
        )
        GlassCard(cornerRadius = 24.dp, alpha = 0.03f) {
            content()
        }
    }
}

@Composable
private fun SettingsToggleRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    checked: Boolean,
    onToggle: () -> Unit
) {
    val c = sortydColors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() }
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(c.teal.copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = c.teal, modifier = Modifier.size(20.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title, 
                style = MaterialTheme.typography.bodyLarge.copy(
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            )
            Text(
                subtitle, 
                style = MaterialTheme.typography.labelSmall.copy(
                    color = Color.White.copy(alpha = 0.4f),
                    fontWeight = FontWeight.Medium
                )
            )
        }
        Switch(
            checked = checked, onCheckedChange = { onToggle() },
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White, 
                checkedTrackColor = c.teal,
                uncheckedThumbColor = Color.White.copy(alpha = 0.4f),
                uncheckedTrackColor = Color.White.copy(alpha = 0.05f),
                uncheckedBorderColor = Color.Transparent
            ),
            modifier = Modifier.scale(0.8f)
        )
    }
}

@Composable
private fun SettingsSelectRow(title: String, isSelected: Boolean, onClick: () -> Unit) {
    val c = sortydColors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            title, 
            style = MaterialTheme.typography.bodyLarge.copy(
                color = if (isSelected) Color.White else Color.White.copy(alpha = 0.4f),
                fontWeight = if (isSelected) FontWeight.Black else FontWeight.Bold,
                letterSpacing = if (isSelected) 0.5.sp else 0.sp
            ), 
            modifier = Modifier.weight(1f)
        )
        if (isSelected) {
            Icon(Icons.Default.CheckCircle, null, tint = c.teal, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
private fun SettingsActionRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    color: Color,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(color.copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title, 
                style = MaterialTheme.typography.bodyLarge.copy(
                    color = color,
                    fontWeight = FontWeight.Bold
                )
            )
            Text(
                subtitle, 
                style = MaterialTheme.typography.labelSmall.copy(
                    color = Color.White.copy(alpha = 0.4f),
                    fontWeight = FontWeight.Medium
                )
            )
        }
        Icon(Icons.Default.ChevronRight, null, tint = Color.White.copy(alpha = 0.2f), modifier = Modifier.size(20.dp))
    }
}

@Composable
private fun SettingsInfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label, 
            style = MaterialTheme.typography.labelSmall.copy(
                color = Color.White.copy(alpha = 0.3f),
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp
            )
        )
        Text(
            value, 
            style = MaterialTheme.typography.bodyMedium.copy(
                color = Color.White.copy(alpha = 0.7f),
                fontWeight = FontWeight.Black
            )
        )
    }
}
