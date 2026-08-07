package com.lingos.app.utils

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import java.io.IOException
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.Socket
import java.util.*

object NetworkUtils {
    private const val TAG = "NetworkUtils"

    fun isNetworkAvailable(context: Context): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) { val network = connectivityManager.activeNetwork ?: return false; val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false; return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) } else { @Suppress("DEPRECATION") val networkInfo = connectivityManager.activeNetworkInfo; return networkInfo != null && networkInfo.isConnected }
    }

    fun getWifiIpAddress(context: Context): String? { val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager; val ip = wifiManager.connectionInfo?.ipAddress ?: return null; return String.format("%d.%d.%d.%d", ip and 0xFF, (ip shr 8) and 0xFF, (ip shr 16) and 0xFF, (ip shr 24) and 0xFF) }

    fun getLocalIpAddresses(): List<String> { val ips = mutableListOf<String>(); try { val interfaces = NetworkInterface.getNetworkInterfaces(); while (interfaces.hasMoreElements()) { val networkInterface = interfaces.nextElement(); val addresses = networkInterface.inetAddresses; while (addresses.hasMoreElements()) { val address = addresses.nextElement(); if (!address.isLoopbackAddress) { val ip = address.hostAddress ?: continue; if (ip.contains(":")) continue; ips.add(ip) } } } } catch (e: Exception) { Logger.e(TAG, "Failed to get local IP addresses", e) }; return ips }

    fun isPortReachable(host: String, port: Int, timeout: Int = 3000): Boolean { return try { val socket = Socket(); socket.connect(java.net.InetSocketAddress(host, port), timeout); socket.close(); true } catch (e: IOException) { false } }
    fun pingHost(host: String, timeout: Int = 3000): Boolean { return try { val address = InetAddress.getByName(host); address.isReachable(timeout) } catch (e: IOException) { Logger.w(TAG, "Ping failed for $host: ${e.message}"); false } }

    suspend fun scanLocalNetwork(prefix: String = "192.168.1.", start: Int = 1, end: Int = 254, port: Int = 2937, timeout: Int = 1000, onProgress: suspend (Int, Int) -> Unit = { _, _ -> }): List<String> {
        val results = mutableListOf<String>(); val total = end - start + 1
        for (i in start..end) { val ip = "$prefix$i"; onProgress(i - start + 1, total); kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { try { val address = InetAddress.getByName(ip); if (address.isReachable(timeout / 2)) { if (isPortReachable(ip, port, timeout / 2)) { synchronized(results) { results.add(ip) }; Logger.d(TAG, "Found LINGOS device at $ip:$port") } } } catch (e: Exception) { } } }; return results
    }

    fun getMacAddress(ip: String): String? { return try { val address = InetAddress.getByName(ip); val networkInterface = NetworkInterface.getByInetAddress(address); val mac = networkInterface?.hardwareAddress; if (mac != null) { mac.joinToString(":") { "%02x".format(it) }.uppercase() } else { null } } catch (e: Exception) { null } }
    fun reverseDns(ip: String): String? { return try { val address = InetAddress.getByName(ip); address.canonicalHostName.takeIf { it != ip } } catch (e: Exception) { null } }
    fun isPrivateIp(ip: String): Boolean { return try { val parts = ip.split(".").map { it.toInt() }; when (parts[0]) { 10 -> true; 172 -> parts[1] in 16..31; 192 -> parts[1] == 168; else -> false } } catch (e: Exception) { false } }

    fun getNetworkInterfaces(): List<NetworkInterfaceInfo> { val result = mutableListOf<NetworkInterfaceInfo>(); try { val interfaces = NetworkInterface.getNetworkInterfaces(); while (interfaces.hasMoreElements()) { val ni = interfaces.nextElement(); val ips = mutableListOf<String>(); val addresses = ni.inetAddresses; while (addresses.hasMoreElements()) { val address = addresses.nextElement(); val ip = address.hostAddress; if (ip != null && !address.isLoopbackAddress) { ips.add(ip) } }; if (ips.isNotEmpty()) { result.add(NetworkInterfaceInfo(name=ni.name, displayName=ni.displayName, ips=ips, isUp=ni.isUp, isLoopback=ni.isLoopback)) } } } catch (e: Exception) { Logger.e(TAG, "Failed to get network interfaces", e) }; return result }
    data class NetworkInterfaceInfo(val name: String, val displayName: String?, val ips: List<String>, val isUp: Boolean, val isLoopback: Boolean)
    fun isValidIPv4(ip: String): Boolean = ip.isValidIPv4()
    fun isValidPort(port: String): Boolean = port.isValidPort()
    data class PortScanResult(val ip: String, val port: Int, val isOpen: Boolean, val service: String? = null)

    suspend fun scanPorts(ip: String, startPort: Int = 2930, endPort: Int = 2940, timeout: Int = 500): List<PortScanResult> {
        val results = mutableListOf<PortScanResult>(); for (port in startPort..endPort) { kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { val isOpen = isPortReachable(ip, port, timeout); synchronized(results) { results.add(PortScanResult(ip=ip, port=port, isOpen=isOpen, service=if (isOpen) getServiceName(port) else null)) } } }; return results
    }

    private fun getServiceName(port: Int): String? = when (port) { 80 -> "HTTP"; 443 -> "HTTPS"; 22 -> "SSH"; 23 -> "Telnet"; 25 -> "SMTP"; 53 -> "DNS"; 110 -> "POP3"; 143 -> "IMAP"; 3306 -> "MySQL"; 5432 -> "PostgreSQL"; 6379 -> "Redis"; 8080 -> "HTTP-Alt"; 2937 -> "LING-OS"; 2938 -> "LING-OS-Backup"; 2837 -> "LING-OS-Hardware"; else -> null }
}
