package com.sortyd.app.di;

import com.sortyd.app.data.local.AppDatabase;
import com.sortyd.app.data.local.AppStateDao;
import dagger.internal.DaggerGenerated;
import dagger.internal.Factory;
import dagger.internal.Preconditions;
import dagger.internal.QualifierMetadata;
import dagger.internal.ScopeMetadata;
import javax.annotation.processing.Generated;
import javax.inject.Provider;

@ScopeMetadata("javax.inject.Singleton")
@QualifierMetadata
@DaggerGenerated
@Generated(
    value = "dagger.internal.codegen.ComponentProcessor",
    comments = "https://dagger.dev"
)
@SuppressWarnings({
    "unchecked",
    "rawtypes",
    "KotlinInternal",
    "KotlinInternalInJava",
    "cast",
    "deprecation"
})
public final class AppModule_ProvideAppStateDaoFactory implements Factory<AppStateDao> {
  private final Provider<AppDatabase> dbProvider;

  public AppModule_ProvideAppStateDaoFactory(Provider<AppDatabase> dbProvider) {
    this.dbProvider = dbProvider;
  }

  @Override
  public AppStateDao get() {
    return provideAppStateDao(dbProvider.get());
  }

  public static AppModule_ProvideAppStateDaoFactory create(Provider<AppDatabase> dbProvider) {
    return new AppModule_ProvideAppStateDaoFactory(dbProvider);
  }

  public static AppStateDao provideAppStateDao(AppDatabase db) {
    return Preconditions.checkNotNullFromProvides(AppModule.INSTANCE.provideAppStateDao(db));
  }
}
