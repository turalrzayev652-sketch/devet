package az.devet.app.di

import az.devet.app.data.AndroidAppLanguage
import az.devet.app.data.AppLanguage
import az.devet.app.data.SupabaseConfig
import az.devet.app.data.account.AccountRepository
import az.devet.app.data.account.SupabaseAccountRepository
import az.devet.app.data.auth.AuthRepository
import az.devet.app.data.auth.SupabaseAuthRepository
import az.devet.app.data.createDevetSupabase
import az.devet.app.data.network.AndroidConnectivity
import az.devet.app.data.network.Connectivity
import az.devet.app.data.events.ArchiveStore
import az.devet.app.data.events.EventRepository
import az.devet.app.data.events.PrefsArchiveStore
import az.devet.app.data.events.SupabaseEventRepository
import az.devet.app.data.guests.GuestListRepository
import az.devet.app.data.guests.GuestRepository
import az.devet.app.data.guests.SupabaseGuestListRepository
import az.devet.app.data.guests.GuestSpec
import az.devet.app.data.guests.SupabaseGuestRepository
import az.devet.app.data.guests.StorageRepository
import az.devet.app.data.guests.SupabaseStorageRepository
import az.devet.app.ui.AppViewModel
import az.devet.app.ui.guests.ContactsViewModel
import az.devet.app.ui.guests.ExcelImportViewModel
import az.devet.app.ui.guests.GuestContext
import az.devet.app.ui.guests.GuestListViewModel
import az.devet.app.ui.guests.ManualGuestViewModel
import az.devet.app.ui.send.PreviewListViewModel
import az.devet.app.ui.events.CreateEventViewModel
import az.devet.app.ui.events.EditEventViewModel
import az.devet.app.ui.events.EventsViewModel
import az.devet.app.ui.auth.ConfirmEmailViewModel
import az.devet.app.ui.auth.NewPasswordViewModel
import az.devet.app.ui.auth.RegisterViewModel
import az.devet.app.ui.auth.ResetPasswordViewModel
import az.devet.app.ui.auth.SignInViewModel
import az.devet.app.ui.settings.SettingsViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

/** Koin graph. Without backend settings the client is null and repositories report [az.devet.app.data.auth.AuthError.NotConfigured]. */
val appModule = module {
    single { CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate) }
    single { SupabaseConfig.fromBuild() }
    single { SupabaseHolder(createDevetSupabase(get())) }
    single<AuthRepository> { SupabaseAuthRepository(get<SupabaseHolder>().client, get()) }
    single<AccountRepository> { SupabaseAccountRepository(get<SupabaseHolder>().client) }
    single<Connectivity> { AndroidConnectivity(androidContext(), get()) }
    single<AppLanguage> { AndroidAppLanguage() }
    single<EventRepository> { SupabaseEventRepository(get<SupabaseHolder>().client) }
    single<ArchiveStore> { PrefsArchiveStore(androidContext()) }
    single<GuestRepository> { SupabaseGuestRepository(get<SupabaseHolder>().client) }
    single<GuestListRepository> { SupabaseGuestListRepository(get<SupabaseHolder>().client) }
    single<StorageRepository> { SupabaseStorageRepository(get<SupabaseHolder>().client) }
    single { GuestSpec.load(androidContext()) }

    viewModel { AppViewModel(get()) }
    viewModel { SignInViewModel(get(), get()) }
    viewModel { RegisterViewModel(get(), get()) }
    viewModel { ResetPasswordViewModel(get(), get()) }
    viewModel { ConfirmEmailViewModel(get()) }
    viewModel { NewPasswordViewModel(get()) }
    viewModel { SettingsViewModel(get(), get(), get()) }
    viewModel { EventsViewModel(get(), get()) }
    viewModel { CreateEventViewModel(get(), get()) }
    viewModel { (id: String) -> EditEventViewModel(get(), id) }
    viewModel { (id: String) -> ManualGuestViewModel(GuestContext(id, get(), get()), get()) }
    viewModel { (id: String) -> ContactsViewModel(GuestContext(id, get(), get()), get()) }
    viewModel { (id: String) -> ExcelImportViewModel(GuestContext(id, get(), get()), get()) }
    viewModel { (id: String, owner: Boolean) -> GuestListViewModel(id, owner, get(), get(), get()) }
    viewModel { (id: String) -> PreviewListViewModel(id, get(), get(), get(), get()) }
}

/** Koin cannot hold a nullable single directly. */
class SupabaseHolder(val client: io.github.jan.supabase.SupabaseClient?)
