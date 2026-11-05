package com.sortyd.app.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.outlined.List
import androidx.compose.material.icons.filled.AutoGraph
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.outlined.AutoGraph
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.*
import androidx.navigation.navArgument
import android.net.Uri
import com.sortyd.app.ui.screens.analytics.AnalyticsScreen
import com.sortyd.app.ui.screens.coach.CoachScreen
import com.sortyd.app.ui.screens.home.HomeScreen
import com.sortyd.app.ui.screens.lists.ListDetailScreen
import com.sortyd.app.ui.screens.lists.ListsScreen
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.viewmodel.SortydViewModel

enum class BottomNavItem(
    val route: String,
    val label: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector,
) {
    TODAY("home", "Today", Icons.Filled.CheckCircle, Icons.Outlined.CheckCircle),
    LISTS("lists", "Lists", Icons.AutoMirrored.Filled.List, Icons.AutoMirrored.Outlined.List),
    ANALYTICS("analytics", "Analytics", Icons.Filled.AutoGraph, Icons.Outlined.AutoGraph),
    COACH("coach", "Coach", Icons.Filled.Psychology, Icons.Outlined.Psychology),
}

@Composable
fun SortydNavHost(
    viewModel: SortydViewModel,
    modifier: Modifier = Modifier,
) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Route all app-owned deep links. Widgets and notifications use this path rather
    // than relying on Android to reconstruct a navigation back stack.
    val pendingDeepLink by viewModel.pendingDeepLink.collectAsState()
    LaunchedEffect(pendingDeepLink) {
        val uri = pendingDeepLink ?: return@LaunchedEffect
        val parsed = Uri.parse(uri)
        when (parsed.host) {
            "list", "lists" -> {
                val listId = parsed.pathSegments.firstOrNull()
                if (!listId.isNullOrBlank()) {
                    viewModel.setActiveList(listId)
                    navController.navigate("lists/$listId") {
                        popUpTo(navController.graph.startDestinationId) { saveState = true }
                        launchSingleTop = true
                    }
                }
            }
            "quick-add" -> navController.navigate("home?quickAdd=true") { launchSingleTop = true }
            "analytics" -> navController.navigate(BottomNavItem.ANALYTICS.route) { launchSingleTop = true }
            "coach" -> navController.navigate(BottomNavItem.COACH.route) { launchSingleTop = true }
            "open", "home" -> navController.navigate(BottomNavItem.TODAY.route) { launchSingleTop = true }
        }
        viewModel.clearPendingDeepLink()
    }

    val colors = SortydColors.current
    val language by viewModel.selectedLanguage.collectAsState()
    val bottomNavRoutes = BottomNavItem.entries.map { it.route }
    val showBottomNav = currentRoute?.let { route ->
        bottomNavRoutes.any { base -> route.startsWith(base) }
    } == true

    Scaffold(
        containerColor = colors.bg0,
        modifier = modifier,
        bottomBar = {
            if (showBottomNav) {
                SortydBottomBar(
                    navController = navController,
                    currentRoute = currentRoute,
                    language = language
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .drawWithContent {
                    drawContent() // Draw content first
                    if (showBottomNav) {
                        // The point where NavHost content is cut off by padding
                        val contentBottomOffset = (innerPadding.calculateBottomPadding() - 7.dp).coerceAtLeast(0.dp).toPx()
                        val fadeHeightPx = 60.dp.toPx()
                        
                        // Draw a gradient from Transparent to bg0 OVER the content to fade it out
                        drawRect(
                            brush = Brush.verticalGradient(
                                colors = listOf(Color.Transparent, colors.bg0),
                                startY = size.height - contentBottomOffset - fadeHeightPx,
                                endY = size.height - contentBottomOffset
                            ),
                            topLeft = androidx.compose.ui.geometry.Offset(0f, size.height - contentBottomOffset - fadeHeightPx),
                            size = androidx.compose.ui.geometry.Size(size.width, fadeHeightPx)
                        )
                    }
                }
        ) {
            NavHost(
                navController = navController,
                startDestination = BottomNavItem.TODAY.route,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(
                        top = innerPadding.calculateTopPadding(),
                        bottom = if (showBottomNav) (innerPadding.calculateBottomPadding() - 7.dp).coerceAtLeast(0.dp) else 0.dp
                    ),
            ) {
                composable(
                    route = BottomNavItem.TODAY.route + "?quickAdd={quickAdd}",
                    arguments = listOf(navArgument("quickAdd") { 
                        type = NavType.BoolType
                        defaultValue = false 
                    }),
                    deepLinks = listOf(
                        androidx.navigation.navDeepLink { uriPattern = "sortyd://home?quickAdd={quickAdd}" },
                        androidx.navigation.navDeepLink { uriPattern = "sortyd://quick-add" }
                    )
                ) { backStackEntry ->
                    val isQuickAddDeepLink = backStackEntry.arguments?.getString("android-support-nav:controller:deep-link-uri")?.contains("quick-add") == true
                    val quickAdd = backStackEntry.arguments?.getBoolean("quickAdd") ?: false || isQuickAddDeepLink
                    HomeScreen(viewModel = viewModel, navController = navController, initialShowAddTask = quickAdd)
                }
                composable(BottomNavItem.LISTS.route) {
                    ListsScreen(viewModel = viewModel, navController = navController)
                }
                composable(
                    route = BottomNavItem.ANALYTICS.route,
                    deepLinks = listOf(androidx.navigation.navDeepLink { uriPattern = "sortyd://analytics" })
                ) {
                    AnalyticsScreen(viewModel = viewModel)
                }
                composable(BottomNavItem.COACH.route) {
                    CoachScreen(viewModel = viewModel)
                }
                composable(
                    route = "lists/{listId}",
                    arguments = listOf(navArgument("listId") { type = NavType.StringType }),
                    deepLinks = listOf(androidx.navigation.navDeepLink { uriPattern = "sortyd://lists/{listId}" })
                ) { backStackEntry ->
                    val listId = backStackEntry.arguments?.getString("listId") ?: return@composable
                    ListDetailScreen(
                        listId = listId,
                        viewModel = viewModel,
                        onBack = { navController.popBackStack() },
                    )
                }
                composable("ai_starter_list") {
                    com.sortyd.app.ui.screens.lists.AIStarterListScreen(
                        viewModel = viewModel,
                        onBack = { navController.popBackStack() },
                        onListCreated = { 
                            navController.navigate(BottomNavItem.TODAY.route) {
                                popUpTo(navController.graph.startDestinationId) {
                                    inclusive = false
                                }
                                launchSingleTop = true
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun SortydBottomBar(
    navController: NavHostController,
    currentRoute: String?,
    language: String,
    modifier: Modifier = Modifier,
) {
    val colors = SortydColors.current
    val items = BottomNavItem.entries
    val selectedIndex = items.indexOfFirst { currentRoute?.startsWith(it.route) == true }.coerceAtLeast(0)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(top = 12.dp, bottom = 16.dp)
            .navigationBarsPadding()
    ) {
        // --- 3D Glass Container ---
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {} // Consume clicks to prevent passthrough to list items
                )
                .graphicsLayer {
                    shadowElevation = 30f
                    shape = RoundedCornerShape(36.dp)
                    clip = true
                },
            shape = RoundedCornerShape(36.dp),
            color = colors.bg1.copy(alpha = 0.88f),
            border = BorderStroke(
                width = 1.2.dp,
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.28f),
                        Color.White.copy(alpha = 0.08f)
                    )
                )
            )
        ) {
            // Apple-style Background Blur
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .blur(30.dp)
                    .background(colors.bg1.copy(alpha = 0.70f))
            )

            BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                val barWidth = maxWidth
                val itemWidth = barWidth / items.size
                
                // --- Magnetic Sliding Selector ---
                val indicatorOffset by animateDpAsState(
                    targetValue = itemWidth * selectedIndex,
                    animationSpec = spring(
                        dampingRatio = 0.7f,
                        stiffness = Spring.StiffnessLow
                    ),
                    label = "indicator"
                )

                Box(
                    modifier = Modifier
                        .offset { IntOffset(indicatorOffset.roundToPx(), 0) }
                        .width(itemWidth)
                        .fillMaxHeight()
                        .padding(vertical = 10.dp, horizontal = 12.dp)
                        .background(
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    colors.accent.copy(alpha = 0.25f),
                                    colors.accent.copy(alpha = 0.1f)
                                )
                            ),
                            shape = RoundedCornerShape(22.dp)
                        )
                        .border(
                            0.5.dp, 
                            Color.White.copy(alpha = 0.1f), 
                            RoundedCornerShape(22.dp)
                        )
                )

                Row(
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    items.forEachIndexed { index, item ->
                        val selected = selectedIndex == index
                        val interactionSource = remember { MutableInteractionSource() }
                        val isPressed by interactionSource.collectIsPressedAsState()
                        
                        val scale by animateFloatAsState(
                            targetValue = if (isPressed) 0.96f else if (selected) 1.03f else 1f,
                            animationSpec = spring(
                                dampingRatio = 0.82f,
                                stiffness = Spring.StiffnessMedium
                            ),
                            label = "scale"
                        )
                        
                        val iconColor by animateColorAsState(
                            targetValue = if (selected) colors.accent else colors.text2,
                            animationSpec = tween(150),
                            label = "color"
                        )

                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .clickable(
                                    interactionSource = interactionSource,
                                    indication = null,
                                    onClick = {
                                        if (!selected) {
                                            navController.navigate(item.route) {
                                                popUpTo(navController.graph.startDestinationId) {
                                                    saveState = true
                                                }
                                                launchSingleTop = true
                                                restoreState = true
                                            }
                                        }
                                    }
                                )
                                .graphicsLayer {
                                    scaleX = scale
                                    scaleY = scale
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Icon(
                                    imageVector = if (selected) item.selectedIcon else item.unselectedIcon,
                                    contentDescription = SortydStrings.t(language, item.label),
                                    tint = iconColor,
                                    modifier = Modifier
                                        .size(26.dp)
                                        .then(if (selected) Modifier.graphicsLayer {
                                            shadowElevation = 8f
                                            shape = RoundedCornerShape(13.dp)
                                        } else Modifier)
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = SortydStrings.t(language, item.label),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = iconColor,
                                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                                    maxLines = 1
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
