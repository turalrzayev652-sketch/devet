package az.devet.app.di

import org.koin.core.module.Module

/** Release builds have no demo mode (BuildConfig.DEMO is always false). */
fun demoModule(): Module? = null
