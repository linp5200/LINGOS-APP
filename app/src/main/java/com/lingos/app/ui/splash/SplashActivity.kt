package com.lingos.app.ui.splash

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.viewModels
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.lingos.app.ui.connect.ConnectActivity
import com.lingos.app.ui.main.MainActivity
import com.lingos.app.ui.theme.LINGOSTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class SplashActivity : ComponentActivity() {
    private val viewModel: SplashViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LINGOSTheme {
                SplashScreen(
                    onComplete = {
                        // 【B1】自动连接后进 Connect 页认证（不再直接进 Main——未认证是假连接）
                        val host = viewModel.foundHost.value
                        startActivity(Intent(this, ConnectActivity::class.java).apply {
                            if (host != null) {
                                putExtra("host_ip", host.ip)
                                putExtra("host_port", host.port)
                            }
                        })
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
