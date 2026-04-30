package com.sortyd.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.core.view.WindowCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.rememberNavController
import com.sortyd.app.ui.navigation.SortydNavHost
import com.sortyd.app.ui.screens.onboarding.OnboardingScreen
import com.sortyd.app.ui.theme.SortydTheme
import com.sortyd.app.ui.theme.sortydColors
import com.sortyd.app.viewmodel.AppViewModel
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContent {
            val vm: AppViewModel = hiltViewModel()
            val isDark by vm.isDarkTheme.collectAsStateWithLifecycle()
            val dataLoaded by vm.dataLoaded.collectAsStateWithLifecycle()
            val regularLists by vm.regularLists.collectAsStateWithLifecycle()

            // Resets on every app restart: if the user still has no lists when
            // they reopen the app, they see onboarding again automatically.
            var dismissedOnboarding by remember { mutableStateOf(false) }

            val navController = rememberNavController()

            SortydTheme(isDark = isDark) {
                val c = sortydColors
                Surface(modifier = Modifier.fillMaxSize(), color = c.bg0) {
                    when {
                        // Data not yet loaded — show blank splash to avoid flash
                        !dataLoaded -> {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(Color(0xFF0A0A0A))
                            )
                        }

                        // No lists yet (or again after deleting all lists),
                        // and the user hasn't just dismissed onboarding this session
                        regularLists.isEmpty() && !dismissedOnboarding -> {
                            OnboardingScreen(
                                onDismiss = {
                                    dismissedOnboarding = true
                                    vm.setTab(1) // jump to Lists tab so they can create first list
                                },
                                vm = vm
                            )
                        }

                        // Main app
                        else -> {
                            LaunchedEffect(dismissedOnboarding) {
                                if (dismissedOnboarding) vm.setTab(1)
                            }
                            SortydNavHost(navController = navController, vm = vm)
                        }
                    }
                }
            }
        }
    }
}
