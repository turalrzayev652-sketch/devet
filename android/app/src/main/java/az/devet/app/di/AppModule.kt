package az.devet.app.di

import az.devet.app.data.SupabaseConfig
import az.devet.app.data.createDevetSupabase
import org.koin.dsl.module

/** Koin graph. The Supabase client is created on first use, so the app starts even without backend settings. */
val appModule = module {
    single { SupabaseConfig.fromBuild() }
    single { createDevetSupabase(get()) }
}
