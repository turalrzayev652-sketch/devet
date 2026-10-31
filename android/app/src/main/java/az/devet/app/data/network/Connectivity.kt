package az.devet.app.data.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.stateIn

/** Online/offline for the offline banner (screens.md §1: "Oflayn: yuxarıda zolaq, Daxil ol bağlı"). */
interface Connectivity {
    val isOnline: StateFlow<Boolean>
}

class AndroidConnectivity(context: Context, scope: CoroutineScope) : Connectivity {
    private val manager = context.getSystemService(ConnectivityManager::class.java)

    private fun online(): Boolean =
        manager.getNetworkCapabilities(manager.activeNetwork)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true

    override val isOnline: StateFlow<Boolean> = callbackFlow {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { trySend(true) }
            override fun onLost(network: Network) { trySend(online()) }
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) { trySend(online()) }
        }
        trySend(online())
        manager.registerDefaultNetworkCallback(callback)
        awaitClose { manager.unregisterNetworkCallback(callback) }
    }.distinctUntilChanged().stateIn(scope, SharingStarted.Eagerly, online())
}
