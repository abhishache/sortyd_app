package com.sortyd.app.ui.screens.ai

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sortyd.app.model.*
import com.sortyd.app.ui.components.*
import com.sortyd.app.ui.theme.*
import com.sortyd.app.viewmodel.AppViewModel

@Composable
fun AICoachScreen(vm: AppViewModel = hiltViewModel(), onNavigateToSettings: () -> Unit = {}) {
    val c = sortydColors
    val isLoading by vm.isAILoading.collectAsStateWithLifecycle()
    val weeklyRecap by vm.weeklyRecap.collectAsStateWithLifecycle()
    val behaviouralAnalysis by vm.behaviouralAnalysis.collectAsStateWithLifecycle()
    val lists by vm.lists.collectAsStateWithLifecycle()
    val snapshots by vm.snapshots.collectAsStateWithLifecycle()

    val hasData = lists.any { !it.isArchived && !it.isTodo && it.tasks.isNotEmpty() }

    // Shimmer animation for loading
    val shimmer by rememberInfiniteTransition(label = "shimmer").animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1400, easing = LinearEasing), RepeatMode.Restart),
        label = "shimmer_val"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(c.bg0)
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 24.dp, vertical = 20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "AI Coach", 
                    style = MaterialTheme.typography.displayLarge.copy(
                        color = Color.White,
                        fontWeight = FontWeight.Black,
                        letterSpacing = (-1).sp
                    )
                )
                Text("Powered by Llama 3.1", style = MaterialTheme.typography.labelMedium.copy(color = c.text2))
            }
            // Settings gear
            IconButton(onClick = onNavigateToSettings) {
                Icon(Icons.Default.Settings, null, tint = c.text2)
            }
            // Refresh button
            IconButton(
                onClick = { vm.loadAIInsights() },
                enabled = !isLoading && hasData
            ) {
                if (isLoading) {
                    CircularProgressIndicator(color = c.accent, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                } else {
                    Icon(Icons.Default.Refresh, null, tint = c.accent)
                }
            }
        }

        if (!hasData) {
            EmptyAIState()
            return@Column
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            // Load on first view
            LaunchedEffect(Unit) {
                if (weeklyRecap == null && !isLoading) vm.loadAIInsights()
            }

            if (isLoading && weeklyRecap == null) {
                AILoadingState(shimmerProgress = shimmer)
            } else {
                // Weekly Recap Card
                weeklyRecap?.let { recap ->
                    WeeklyRecapCard(recap = recap)
                }

                // Behavioural Pillars
                behaviouralAnalysis?.let { analysis ->
                    BehaviouralPillarsCard(analysis = analysis)
                }

                // Disclaimer
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 12.dp)
                ) {
                    Text(
                        "AI analytics use goal titles only — processed securely",
                        style = MaterialTheme.typography.labelSmall.copy(color = c.text2, letterSpacing = 0.5.sp),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            Spacer(Modifier.height(100.dp))
        }
    }
}

@Composable
private fun WeeklyRecapCard(recap: WeeklyRecap) {
    val c = sortydColors
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp),
        alpha = 0.05f
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(Icons.Default.Insights, null, tint = c.accent, modifier = Modifier.size(16.dp))
            Text("WEEKLY RECAP", style = MaterialTheme.typography.labelMedium.copy(color = c.accent, letterSpacing = 1.sp, fontWeight = FontWeight.Black))
        }
        Spacer(Modifier.height(16.dp))

        Text(recap.headline, style = MaterialTheme.typography.headlineLarge.copy(color = Color.White, fontWeight = FontWeight.Bold))
        Spacer(Modifier.height(8.dp))
        Text(recap.summary, style = MaterialTheme.typography.bodyLarge.copy(color = Color.White.copy(alpha = 0.7f), lineHeight = 20.sp))

        if (recap.highlight.isNotBlank()) {
            Spacer(Modifier.height(16.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(c.success.copy(alpha = 0.05f), RoundedCornerShape(16.dp))
                    .border(1.dp, c.success.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
                    .padding(16.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("✨", style = MaterialTheme.typography.bodyLarge)
                    Text(recap.highlight, style = MaterialTheme.typography.bodyMedium.copy(color = c.success, fontWeight = FontWeight.Medium))
                }
            }
        }

        if (recap.nudge.isNotBlank()) {
            Spacer(Modifier.height(12.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(c.warning.copy(alpha = 0.05f), RoundedCornerShape(16.dp))
                    .border(1.dp, c.warning.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
                    .padding(16.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("💡", style = MaterialTheme.typography.bodyLarge)
                    Text(recap.nudge, style = MaterialTheme.typography.bodyMedium.copy(color = c.warning, fontWeight = FontWeight.Medium))
                }
            }
        }

        if (recap.grade.isNotBlank()) {
            Spacer(Modifier.height(24.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                val gradeColor = when {
                    recap.grade.startsWith("A") -> c.success
                    recap.grade.startsWith("B") -> c.teal
                    recap.grade.startsWith("C") -> c.warning
                    else -> c.danger
                }
                Text(
                    recap.grade,
                    style = MaterialTheme.typography.displayLarge.copy(
                        color = gradeColor,
                        fontWeight = FontWeight.Black,
                        fontSize = 80.sp,
                        letterSpacing = (-4).sp
                    )
                )
                Column {
                    Text("OVERALL GRADE", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.4f), letterSpacing = 1.sp, fontWeight = FontWeight.Black))
                    Text(recap.gradeReason, style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.4f)))
                }
            }
        }
    }
}

@Composable
private fun BehaviouralPillarsCard(analysis: BehaviouralAnalysis) {
    val c = sortydColors
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp),
        alpha = 0.05f
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.Psychology, null, tint = c.violet, modifier = Modifier.size(16.dp))
            Text("BEHAVIOURAL PILLARS", style = MaterialTheme.typography.labelMedium.copy(color = c.violet, letterSpacing = 1.sp, fontWeight = FontWeight.Black))
        }

        if (analysis.overallInsight.isNotBlank()) {
            Spacer(Modifier.height(16.dp))
            Text(analysis.overallInsight, style = MaterialTheme.typography.bodyLarge.copy(color = Color.White.copy(alpha = 0.7f), lineHeight = 20.sp))
        }

        analysis.pillars.forEach { pillar ->
            Spacer(Modifier.height(16.dp))
            PillarRow(pillar = pillar)
        }
    }
}

@Composable
private fun PillarRow(pillar: BehaviouralPillar) {
    val c = sortydColors
    val pillarColor = when {
        pillar.score >= 80 -> c.success
        pillar.score >= 60 -> c.teal
        pillar.score >= 40 -> c.warning
        else -> c.danger
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.03f), RoundedCornerShape(16.dp))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(pillar.name, style = MaterialTheme.typography.headlineSmall.copy(color = Color.White, fontWeight = FontWeight.Bold))
            Text("${pillar.score}%", style = MaterialTheme.typography.headlineSmall.copy(color = pillarColor, fontWeight = FontWeight.Black))
        }
        
        LinearProgressIndicator(
            progress = { pillar.score / 100f },
            modifier = Modifier.fillMaxWidth().height(6.dp).clip(CircleShape),
            color = pillarColor, 
            trackColor = Color.White.copy(alpha = 0.05f)
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .background(pillarColor.copy(alpha = 0.1f), CircleShape)
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            ) {
                Text(pillar.status.uppercase(), style = MaterialTheme.typography.labelSmall.copy(color = pillarColor, fontWeight = FontWeight.Black, letterSpacing = 0.5.sp))
            }
            if (pillar.insight.isNotBlank()) {
                Text(pillar.insight, style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.4f)), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        
        if (pillar.advice.isNotBlank()) {
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp), color = Color.White.copy(alpha = 0.05f))
            Text(pillar.advice, style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.6f), fontStyle = androidx.compose.ui.text.font.FontStyle.Italic))
        }
    }
}

@Composable
private fun AILoadingState(shimmerProgress: Float) {
    val c = sortydColors
    Column(
        modifier = Modifier.fillMaxWidth().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        repeat(3) { idx ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(if (idx == 0) 160.dp else 100.dp)
                    .background(
                        color = c.bg2.copy(alpha = 0.5f + 0.3f * shimmerProgress),
                        shape = RoundedCornerShape(16.dp)
                    )
            )
        }
        Text("Analyzing your habits…", style = MaterialTheme.typography.bodyMedium.copy(color = c.text2),
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    }
}

@Composable
private fun EmptyAIState() {
    val c = sortydColors
    Column(
        modifier = Modifier.fillMaxSize().padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("🤖", style = MaterialTheme.typography.displayLarge.copy(fontSize = 64.sp))
        Spacer(Modifier.height(16.dp))
        Text("Add tasks to get AI insights",
            style = MaterialTheme.typography.headlineMedium.copy(color = c.text1),
            textAlign = TextAlign.Center)
        Text("Your coach analyzes patterns across all your lists",
            style = MaterialTheme.typography.bodyMedium.copy(color = c.text2),
            textAlign = TextAlign.Center)
    }
}
