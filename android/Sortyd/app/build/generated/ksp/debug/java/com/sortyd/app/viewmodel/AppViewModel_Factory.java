package com.sortyd.app.viewmodel;

import com.sortyd.app.ai.AICoach;
import com.sortyd.app.data.repository.AppRepository;
import com.sortyd.app.health.HealthConnectManager;
import com.sortyd.app.notifications.NotificationHelper;
import dagger.internal.DaggerGenerated;
import dagger.internal.Factory;
import dagger.internal.QualifierMetadata;
import dagger.internal.ScopeMetadata;
import javax.annotation.processing.Generated;
import javax.inject.Provider;

@ScopeMetadata
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
public final class AppViewModel_Factory implements Factory<AppViewModel> {
  private final Provider<AppRepository> repositoryProvider;

  private final Provider<AICoach> aiCoachProvider;

  private final Provider<HealthConnectManager> healthConnectProvider;

  private final Provider<NotificationHelper> notificationHelperProvider;

  public AppViewModel_Factory(Provider<AppRepository> repositoryProvider,
      Provider<AICoach> aiCoachProvider, Provider<HealthConnectManager> healthConnectProvider,
      Provider<NotificationHelper> notificationHelperProvider) {
    this.repositoryProvider = repositoryProvider;
    this.aiCoachProvider = aiCoachProvider;
    this.healthConnectProvider = healthConnectProvider;
    this.notificationHelperProvider = notificationHelperProvider;
  }

  @Override
  public AppViewModel get() {
    return newInstance(repositoryProvider.get(), aiCoachProvider.get(), healthConnectProvider.get(), notificationHelperProvider.get());
  }

  public static AppViewModel_Factory create(Provider<AppRepository> repositoryProvider,
      Provider<AICoach> aiCoachProvider, Provider<HealthConnectManager> healthConnectProvider,
      Provider<NotificationHelper> notificationHelperProvider) {
    return new AppViewModel_Factory(repositoryProvider, aiCoachProvider, healthConnectProvider, notificationHelperProvider);
  }

  public static AppViewModel newInstance(AppRepository repository, AICoach aiCoach,
      HealthConnectManager healthConnect, NotificationHelper notificationHelper) {
    return new AppViewModel(repository, aiCoach, healthConnect, notificationHelper);
  }
}
