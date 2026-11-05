package com.sortyd.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModelProvider
import androidx.compose.ui.Modifier
import com.microsoft.clarity.modifiers.clarityMask
import com.sortyd.app.navigation.SortydNavHost
import com.sortyd.app.services.ReviewPromptManager
import com.sortyd.app.ui.theme.AppFont
import com.sortyd.app.ui.theme.SortydTheme
import com.sortyd.app.viewmodel.SortydViewModel

class MainActivity : ComponentActivity() {

    private lateinit var viewModel: SortydViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        viewModel = ViewModelProvider(this)[SortydViewModel::class.java]

        // Pass any launch-time deep link to the ViewModel
        consumeNavigationIntent(intent)

        setContent {
            val isDark by viewModel.isDarkMode.collectAsState()
            val fontName by viewModel.selectedFont.collectAsState()
            val appFont = try {
                AppFont.valueOf(fontName)
            } catch (_: Exception) {
                AppFont.ROUNDED
            }

            SortydTheme(darkTheme = isDark, appFont = appFont) {
                val hasSeenOnboarding by viewModel.hasSeenOnboarding.collectAsState()
                val dailyRecap by viewModel.dailyRecap.collectAsState()

                androidx.compose.foundation.layout.Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clarityMask()
                ) {
                    if (hasSeenOnboarding) {
                        SortydNavHost(viewModel = viewModel)
                    } else {
                        com.sortyd.app.ui.screens.onboarding.OnboardingScreen(
                            viewModel = viewModel,
                            onComplete = { viewModel.setOnboardingSeen() }
                        )
                    }

                    dailyRecap?.let { recap ->
                        com.sortyd.app.ui.components.DailyRecapBanner(
                            data = recap,
                            onDismiss = { viewModel.dismissDailyRecap() }
                        )
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        viewModel.refresh()
        ReviewPromptManager.maybeRequestReview(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeNavigationIntent(intent)
    }

    private fun consumeNavigationIntent(intent: Intent) {
        intent.data?.toString()?.let { viewModel.consumeDeepLink(it) }
        when (intent.getStringExtra("navigate_to")) {
            "coach" -> viewModel.consumeDeepLink("sortyd://coach")
            "analytics" -> viewModel.consumeDeepLink("sortyd://analytics")
            "today" -> viewModel.consumeDeepLink("sortyd://home")
        }
    }
}
