package com.sortyd.app.ui.navigation

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.*
import com.sortyd.app.ui.screens.ai.AICoachScreen
import com.sortyd.app.ui.screens.analytics.AnalyticsScreen
import com.sortyd.app.ui.screens.home.HomeScreen
import com.sortyd.app.ui.screens.lists.ListsScreen
import com.sortyd.app.ui.screens.onboarding.OnboardingScreen
import com.sortyd.app.ui.screens.settings.SettingsScreen
import com.sortyd.app.ui.theme.sortydColors
import com.sortyd.app.viewmodel.AppViewModel

sealed class Screen(val route: String) {
    object Onboarding : Screen("onboarding")
    object Home : Screen("home")
    object Lists : Screen("lists")
    object Analytics : Screen("analytics")
    object AICoach : Screen("ai_coach")
    object Settings : Screen("settings")
}

data class BottomNavItem(
    val screen: Screen,
    val label: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
)

@Composable
fun SortydNavHost(
    navController: NavHostController,
    vm: AppViewModel = hiltViewModel()
) {
    val selectedTab by vm.selectedTab.collectAsStateWithLifecycle()
    val c = sortydColors

    val navItems = listOf(
        BottomNavItem(Screen.Home, "Today", Icons.Filled.Home, Icons.Outlined.Home),
        BottomNavItem(Screen.Lists, "Lists", Icons.Filled.List, Icons.Outlined.List),
        BottomNavItem(Screen.Analytics, "Analytics", Icons.Filled.BarChart, Icons.Outlined.BarChart),
        BottomNavItem(Screen.AICoach, "Coach", Icons.Filled.AutoAwesome, Icons.Outlined.AutoAwesome)
    )

    val mainRoutes = listOf(Screen.Home.route, Screen.Lists.route, Screen.Analytics.route, Screen.AICoach.route)
    val currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route

    Box(modifier = Modifier.fillMaxSize()) {
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.fillMaxSize(),
            enterTransition = { fadeIn(tween(300)) },
            exitTransition = { fadeOut(tween(300)) }
        ) {
            composable(Screen.Home.route) { HomeScreen(vm = vm) }
            composable(Screen.Lists.route) { ListsScreen(vm = vm) }
            composable(Screen.Analytics.route) { AnalyticsScreen(vm = vm) }
            composable(Screen.AICoach.route) {
                AICoachScreen(vm = vm, onNavigateToSettings = { navController.navigate(Screen.Settings.route) })
            }
            composable(Screen.Settings.route) { SettingsScreen(vm = vm) }
        }

        // Floating Glass Dock
        if (currentRoute in mainRoutes) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(horizontal = 24.dp, vertical = 24.dp)
                    .fillMaxWidth()
                    .height(72.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
                    .border(1.dp, Color.White.copy(alpha = 0.1f), CircleShape)
            ) {
                // Blur Effect (using Box behind)
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .blur(20.dp)
                        .background(Color.Black.copy(alpha = 0.4f))
                )

                Row(
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    navItems.forEachIndexed { idx, item ->
                        val isSelected = selectedTab == idx
                        
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .clickable(
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null
                                ) {
                                    vm.setTab(idx)
                                    navController.navigate(item.screen.route) {
                                        popUpTo(Screen.Home.route) { saveState = true }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Icon(
                                    if (isSelected) item.selectedIcon else item.unselectedIcon,
                                    contentDescription = item.label,
                                    tint = if (isSelected) c.teal else Color.White.copy(alpha = 0.4f),
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    item.label.uppercase(),
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        fontSize = 8.sp,
                                        fontWeight = FontWeight.Black,
                                        letterSpacing = 0.5.sp,
                                        color = if (isSelected) c.teal else Color.White.copy(alpha = 0.4f)
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
