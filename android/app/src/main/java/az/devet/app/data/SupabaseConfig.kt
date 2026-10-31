package az.devet.app.data

import az.devet.app.BuildConfig
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.storage.Storage

/**
 * Backend settings from the build (local.properties / CI env). Only the anon key ever reaches the app
 * (CLAUDE.md security rules); access is limited by RLS (spec/api.md §0.1).
 */
data class SupabaseConfig(val url: String, val anonKey: String, val publicBaseUrl: String) {
    val isConfigured: Boolean get() = url.startsWith("https://") || url.startsWith("http://")

    companion object {
        fun fromBuild() = SupabaseConfig(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_ANON_KEY, BuildConfig.PUBLIC_BASE_URL)
    }
}

fun createDevetSupabase(config: SupabaseConfig): SupabaseClient {
    require(config.isConfigured) { "SUPABASE_URL is not set (android/local.properties or environment)" }
    return createSupabaseClient(supabaseUrl = config.url, supabaseKey = config.anonKey) {
        install(Auth)
        install(Postgrest)
        install(Storage)
        install(Functions)
    }
}
