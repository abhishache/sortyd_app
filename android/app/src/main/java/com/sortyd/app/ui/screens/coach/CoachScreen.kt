package com.sortyd.app.ui.screens.coach

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowCircleRight
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.ui.theme.glow
import com.sortyd.app.viewmodel.Pillar
import com.sortyd.app.viewmodel.SortydViewModel

@Composable
fun CoachScreen(viewModel: SortydViewModel) {
    val colors = SortydColors.current
    val isLoading by viewModel.coachLoading.collectAsState()
    val recap by viewModel.coachRecap.collectAsState()
    val activeList by viewModel.activeList.collectAsState()
    val activeLists by viewModel.activeLists.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()
    val coachLists = activeLists.filter { !it.isArchived && !it.isTodo && !it.cleanName.equals("Weekly Planner", ignoreCase = true) }
    val selectedCoachList = coachLists.firstOrNull { it.id == activeList?.id } ?: coachLists.firstOrNull()
    var showCoachInfo by remember { mutableStateOf(false) }

    val infinite = rememberInfiniteTransition(label = "spin")
    val spin by infinite.animateFloat(0f, 360f, infiniteRepeatable(tween(700, easing = LinearEasing)), label = "spinA")

    Box(Modifier.fillMaxSize().background(colors.bg0)) {
        // Subtle Background Glows
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(Color(0xFF3ECFFF).copy(alpha = 0.04f), Color.Transparent),
                    center = Offset(size.width * 0.35f, 0f),
                    radius = size.width * 0.6f
                )
            )
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(Color(0xFF7C6FFF).copy(alpha = 0.03f), Color.Transparent),
                    center = Offset(size.width * 0.8f, 0f),
                    radius = size.width * 0.5f
                )
            )
        }

        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp)) {
            // ── Header ──
            Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(SortydStrings.t(language, "AI COACH"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, letterSpacing = 2.5.sp, fontWeight = FontWeight.Black).glow(colors.accent), color = colors.accent)
                    Text(SortydStrings.t(language, "Habit Analysis"), style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.ExtraBold, fontSize = 24.sp), color = colors.text0)
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    // Info button with glow
                    Box(
                        Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(colors.accent.copy(0.08f))
                            .border(0.85.dp, Brush.linearGradient(listOf(colors.accent.copy(0.55f), colors.coral.copy(0.3f))), CircleShape)
                            .clickable { showCoachInfo = true },
                        Alignment.Center
                    ) {
                        Icon(Icons.Default.Info, null, tint = colors.accent, modifier = Modifier.size(14.dp))
                    }
                    // Refresh button
                    Box(Modifier.size(44.dp).clip(CircleShape).background(colors.bg2).border(0.5.dp, colors.borderSubtle, CircleShape).clickable { selectedCoachList?.let { viewModel.refreshCoach(it.id) } }, Alignment.Center) {
                        Icon(Icons.Default.Refresh, null, tint = if (isLoading) colors.accent else colors.text1, modifier = Modifier.size(14.dp).then(if (isLoading) Modifier.rotate(spin) else Modifier))
                    }
                }
            }

            // ── List Picker ──
            LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 18.dp)) {
                items(coachLists) { l ->
                    val sel = l.id == activeList?.id
                    Box(Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(20.dp))
                        .background(if (sel) colors.accent.copy(0.1f) else colors.bg2)
                        .border(if (sel) 1.dp else 0.5.dp, if (sel) colors.accent.copy(0.4f) else colors.borderSubtle, RoundedCornerShape(20.dp))
                        .clickable { viewModel.setActiveList(l.id) }.padding(horizontal = 13.dp, vertical = 7.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            Text(l.emoji, fontSize = 12.sp)
                            Text(l.cleanName, style = MaterialTheme.typography.labelMedium.copy(fontSize = 12.sp, fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium),
                                color = if (sel) colors.accent else colors.text1)
                        }
                    }
                }
            }

            if (isLoading) {
                repeat(4) { SkeletonCard(Modifier.padding(horizontal = 20.dp, vertical = 5.dp)) }
            } else if (recap == null) {
                // Idle state
                Column(Modifier.fillMaxWidth().padding(vertical = 48.dp, horizontal = 20.dp).clip(RoundedCornerShape(18.dp)).background(colors.bg1).border(0.5.dp, colors.borderSubtle, RoundedCornerShape(18.dp)).padding(40.dp),
                    horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🧠", fontSize = 36.sp)
                    Spacer(Modifier.height(16.dp))
                    Text(SortydStrings.t(language, "No Analysis Yet"), style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold), color = colors.text0)
                    Text(SortydStrings.t(language, "Tap refresh to unlock AI insights into your habit patterns."), style = MaterialTheme.typography.bodySmall, color = colors.text2, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 5.dp))
                }
            } else {
                val r = recap!!
                
                // ── Weekly Grade Banner ──
                WeeklyGradeBanner(r, language)

                Spacer(Modifier.height(12.dp))

                // ── Pillar Summary Row ──
                val strong = r.pillars.count { it.score >= 75 }
                val weak = r.pillars.count { it.score < 50 }
                Row(Modifier.padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SummaryChip("$strong", SortydStrings.t(language, "Strong"), colors.success, Modifier.weight(1f))
                    SummaryChip("$weak", SortydStrings.t(language, if (weak == 0) "All good" else "Need work"), if (weak == 0) colors.success else colors.warning, Modifier.weight(1f))
                    SummaryChip("${r.pillars.size}", SortydStrings.t(language, "Pillars"), colors.text1, Modifier.weight(1f))
                }

                Spacer(Modifier.height(12.dp))

                // ── Pillar Cards ──
                r.pillars.sortedBy { it.score }.forEachIndexed { i, p ->
                    PillarCard(p, language, expanded = i == 0, Modifier.padding(horizontal = 20.dp, vertical = 4.dp))
                }

                Spacer(Modifier.height(12.dp))
                
                // ── Overall Pattern ──
                OverallInsightBanner(r.overallInsight, language)
                
                // ── Procrastination Flags ──
                if (r.skippedTasks.isNotEmpty()) {
                    Spacer(Modifier.height(12.dp))
                    ProcrastinationSection(r.skippedTasks, language)
                }
            }
        }

        if (showCoachInfo) {
            AlertDialog(
                onDismissRequest = { showCoachInfo = false },
                title = { Text("How AI Coach works", color = colors.text0) },
                text = { Text("Choose a list, then refresh to see patterns based on completed tasks and your recent progress.", color = colors.text1) },
                confirmButton = {
                    TextButton(onClick = { showCoachInfo = false }) { Text("Got it") }
                },
                containerColor = colors.bg1
            )
        }
    }
}

@Composable
private fun WeeklyGradeBanner(recap: com.sortyd.app.viewmodel.CoachRecap, language: String) {
    val colors = SortydColors.current
    val gradeColor = when {
        recap.grade.startsWith("A") -> colors.success
        recap.grade.startsWith("B") -> colors.accent
        recap.grade.startsWith("C") -> colors.warning
        else -> colors.danger
    }
    
    Row(Modifier.padding(horizontal = 20.dp).fillMaxWidth().height(IntrinsicSize.Min).clip(RoundedCornerShape(16.dp)).background(colors.bg1).border(0.75.dp, gradeColor.copy(0.15f), RoundedCornerShape(16.dp))) {
        Column(Modifier.width(60.dp).fillMaxHeight().background(gradeColor.copy(0.07f)), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(recap.grade, style = MaterialTheme.typography.headlineSmall.copy(fontSize = 30.sp, fontWeight = FontWeight.Black), color = gradeColor)
            Text(SortydStrings.t(language, "WEEK"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, fontWeight = FontWeight.Black, letterSpacing = 1.8.sp).glow(gradeColor), color = gradeColor.copy(alpha = 0.45f))
        }
        Box(Modifier.width(0.5.dp).fillMaxHeight().background(gradeColor.copy(0.12f)))
        Column(Modifier.weight(1f).padding(horizontal = 14.dp, vertical = 13.dp)) {
            Text(recap.headline, style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold), color = colors.text0, maxLines = 1)
            Text(recap.reason, style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.5.sp), color = colors.text2, maxLines = 2, lineHeight = 16.sp)
        }
        Box(Modifier.padding(end = 12.dp).size(34.dp).clip(CircleShape).background(colors.accent.copy(0.08f)).align(Alignment.CenterVertically), Alignment.Center) {
            Text("💡", fontSize = 13.sp)
        }
    }
}

@Composable
private fun SummaryChip(value: String, label: String, color: Color, modifier: Modifier) {
    val colors = SortydColors.current
    Column(modifier.clip(RoundedCornerShape(12.dp)).background(colors.bg1).border(0.5.dp, color.copy(0.12f), RoundedCornerShape(12.dp)).padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp, fontWeight = FontWeight.Black), color = color)
        Text(label, style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.SemiBold), color = colors.text2)
    }
}

@Composable
private fun ProcrastinationSection(tasks: List<String>, language: String) {
    val colors = SortydColors.current
    Column(Modifier.padding(horizontal = 20.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(colors.bg1).border(0.5.dp, colors.borderSubtle, RoundedCornerShape(18.dp)).padding(16.dp)) {
        Text(SortydStrings.t(language, "SKIPPED TASKS"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp, letterSpacing = 1.4.sp, fontWeight = FontWeight.Bold), color = colors.text2)
        Spacer(Modifier.height(10.dp))
        tasks.forEach { t ->
            Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("⚠️", fontSize = 11.sp)
                Spacer(Modifier.width(8.dp))
                Text(t, style = MaterialTheme.typography.bodySmall, color = colors.text0)
            }
        }
    }
}

@Composable
private fun OverallInsightBanner(text: String, language: String) {
    val colors = SortydColors.current
    Column(Modifier.padding(horizontal = 20.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(colors.bg1).border(0.5.dp, colors.borderSubtle, RoundedCornerShape(18.dp)).padding(16.dp)) {
        Text(SortydStrings.t(language, "OVERALL PATTERN"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp, letterSpacing = 1.4.sp, fontWeight = FontWeight.Bold), color = colors.text2)
        Spacer(Modifier.height(6.dp))
        Text(text, style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.5.sp), color = colors.text1, lineHeight = 18.sp)
    }
}

@Composable
private fun PillarCard(pillar: Pillar, language: String, expanded: Boolean, modifier: Modifier) {
    val colors = SortydColors.current
    var isExpanded by remember { mutableStateOf(expanded) }
    val scoreColor = when { pillar.score >= 70 -> colors.success; pillar.score >= 50 -> colors.warning; else -> colors.danger }
    val statusLabel = SortydStrings.status(language, pillar.status, pillar.score)

    Column(modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.bg1)
        .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(16.dp)).clickable { isExpanded = !isExpanded }) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            // Score ring with emoji
            Box(Modifier.size(40.dp), Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    drawArc(color = colors.bg3, 0f, 360f, false, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round),
                        topLeft = Offset(4f, 4f), size = Size(size.width - 8, size.height - 8))
                    drawArc(color = scoreColor, -90f, 360f * pillar.score / 100f, false, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round),
                        topLeft = Offset(4f, 4f), size = Size(size.width - 8, size.height - 8))
                }
                Text(pillar.emoji, fontSize = 16.sp)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(pillar.name, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold), color = colors.text0)
                    if (pillar.score < 50) {
                        Spacer(Modifier.width(8.dp))
                        Text(SortydStrings.t(language, "FOCUS"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.sp, fontWeight = FontWeight.ExtraBold),
                            color = colors.danger, modifier = Modifier.background(colors.danger.copy(0.1f), RoundedCornerShape(4.dp)).padding(horizontal = 6.dp, vertical = 1.dp))
                    }
                }
                Text(statusLabel, style = MaterialTheme.typography.bodySmall, color = scoreColor)
            }
            Text("${pillar.score}", style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Black), color = scoreColor)
            Spacer(Modifier.width(4.dp))
            Text(if (isExpanded) "▲" else "▼", color = colors.text2, fontSize = 10.sp)
        }

        // Score progress bar
        Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp).height(3.dp).clip(RoundedCornerShape(2.dp)).background(colors.bg3)) {
            Box(Modifier.fillMaxHeight().fillMaxWidth(pillar.score / 100f).clip(RoundedCornerShape(2.dp)).background(scoreColor))
        }

        // Expanded content
        AnimatedVisibility(isExpanded, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
            Column(Modifier.padding(16.dp)) {
                // "WHAT'S HAPPENING" section
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Visibility, null, tint = scoreColor, modifier = Modifier.size(12.dp))
                    Spacer(Modifier.width(5.dp))
                    Text(SortydStrings.t(language, "WHAT'S HAPPENING"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp, letterSpacing = 1.2.sp, fontWeight = FontWeight.Bold).glow(scoreColor, 4f), color = colors.text2)
                }
                Spacer(Modifier.height(8.dp))
                pillar.advice.take(1).forEach { a ->
                    Row {
                        Text("-", color = scoreColor.copy(0.6f), fontWeight = FontWeight.Bold, modifier = Modifier.width(14.dp))
                        Text(a, style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.5.sp), color = colors.text1, lineHeight = 18.sp)
                    }
                }

                Spacer(Modifier.height(14.dp))

                // Task chips (matching iOS colored pills)
                if (pillar.relatedTasks.isNotEmpty()) {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(pillar.relatedTasks) { t ->
                            Box(Modifier.clip(RoundedCornerShape(12.dp)).background(scoreColor.copy(0.07f))
                                .border(0.5.dp, scoreColor.copy(0.18f), RoundedCornerShape(12.dp)).padding(horizontal = 10.dp, vertical = 5.dp)) {
                                Text(t, style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp, fontWeight = FontWeight.Medium), color = scoreColor)
                            }
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                }

                // "NEXT STEPS" section
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.ArrowCircleRight, null, tint = colors.accent, modifier = Modifier.size(12.dp))
                    Spacer(Modifier.width(5.dp))
                    Text(SortydStrings.t(language, "NEXT STEPS"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp, letterSpacing = 1.2.sp, fontWeight = FontWeight.Bold).glow(colors.accent, 4f), color = colors.text2)
                }
                Spacer(Modifier.height(8.dp))
                pillar.advice.drop(1).forEach { a ->
                    Row(Modifier.padding(vertical = 2.dp)) {
                        Text("→", color = colors.accent.copy(0.6f), fontWeight = FontWeight.Bold, modifier = Modifier.width(14.dp))
                        Text(a, style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.5.sp), color = colors.text1, lineHeight = 18.sp)
                    }
                }
            }
        }

        Spacer(Modifier.height(4.dp))
    }
}

@Composable
private fun SkeletonCard(modifier: Modifier) {
    val colors = SortydColors.current
    val tr = rememberInfiniteTransition(label = "shimmer")
    val alpha by tr.animateFloat(0.3f, 0.7f, infiniteRepeatable(tween(1400, easing = LinearEasing), RepeatMode.Reverse), label = "shA")
    Box(modifier.fillMaxWidth().height(72.dp).clip(RoundedCornerShape(12.dp)).background(colors.bg1)) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(36.dp).clip(CircleShape).background(colors.bg3.copy(alpha)))
            Spacer(Modifier.width(12.dp))
            Column { Box(Modifier.width(120.dp).height(12.dp).clip(RoundedCornerShape(4.dp)).background(colors.bg3.copy(alpha)))
                Spacer(Modifier.height(8.dp)); Box(Modifier.width(80.dp).height(8.dp).clip(RoundedCornerShape(4.dp)).background(colors.bg3.copy(alpha))) }
        }
    }
}
