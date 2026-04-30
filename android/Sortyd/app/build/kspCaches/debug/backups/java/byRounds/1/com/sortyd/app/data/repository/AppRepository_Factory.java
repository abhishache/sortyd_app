package com.sortyd.app.data.repository;

import android.content.Context;
import com.sortyd.app.data.local.AppDatabase;
import dagger.internal.DaggerGenerated;
import dagger.internal.Factory;
import dagger.internal.QualifierMetadata;
import dagger.internal.ScopeMetadata;
import javax.annotation.processing.Generated;
import javax.inject.Provider;

@ScopeMetadata("javax.inject.Singleton")
@QualifierMetadata("dagger.hilt.android.qualifiers.ApplicationContext")
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
public final class AppRepository_Factory implements Factory<AppRepository> {
  private final Provider<Context> contextProvider;

  private final Provider<AppDatabase> dbProvider;

  public AppRepository_Factory(Provider<Context> contextProvider,
      Provider<AppDatabase> dbProvider) {
    this.contextProvider = contextProvider;
    this.dbProvider = dbProvider;
  }

  @Override
  public AppRepository get() {
    return newInstance(contextProvider.get(), dbProvider.get());
  }

  public static AppRepository_Factory create(Provider<Context> contextProvider,
      Provider<AppDatabase> dbProvider) {
    return new AppRepository_Factory(contextProvider, dbProvider);
  }

  public static AppRepository newInstance(Context context, AppDatabase db) {
    return new AppRepository(context, db);
  }
}
