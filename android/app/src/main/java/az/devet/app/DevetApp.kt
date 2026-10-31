package az.devet.app

import android.app.Application
import az.devet.app.di.appModule
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin

class DevetApp : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@DevetApp)
            modules(appModule)
        }
    }
}
