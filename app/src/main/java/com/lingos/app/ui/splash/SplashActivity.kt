package com.lingos.app.ui.splash

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.lingos.app.ui.connect.ConnectActivity
import com.lingos.app.ui.main.MainActivity
import com.lingos.app.ui.theme.LINGOSTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class SplashActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LINGOSTheme {
                SplashScreen(
                    onComplete = {
                        startActivity(Intent(this, MainActivity::class.java))
                        finish()
                    },
                    onConnectFailed = {
                        startActivity(Intent(this, ConnectActivity::class.java))
                        finish()
                    }
                )
            }
        }
    }
}
