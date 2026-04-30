package com.sortyd.app.health;

import android.content.Context;
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
public final class HealthConnectManager_Factory implements Factory<HealthConnectManager> {
  private final Provider<Context> contextProvider;

  public HealthConnectManager_Factory(Provider<Context> contextProvider) {
    this.contextProvider = contextProvider;
  }

  @Override
  public HealthConnectManager get() {
    return newInstance(contextProvider.get());
  }

  public static HealthConnectManager_Factory create(Provider<Context> contextProvider) {
    return new HealthConnectManager_Factory(contextProvider);
  }

  public static HealthConnectManager newInstance(Context context) {
    return new HealthConnectManager(context);
  }
}
