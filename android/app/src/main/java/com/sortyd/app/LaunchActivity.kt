package com.sortyd.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class LaunchActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Install the splash screen before calling super.onCreate()
        installSplashScreen()
        
        super.onCreate(savedInstanceState)

        startActivity(Intent(this, MainActivity::class.java).apply {
            data = intent?.data
            action = intent?.action
            if (intent?.extras != null) {
                putExtras(intent!!.extras!!)
            }
        })
        finish()
    }
}
