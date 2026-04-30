package com.sortyd.app;

import androidx.hilt.work.HiltWorkerFactory;
import dagger.MembersInjector;
import dagger.internal.DaggerGenerated;
import dagger.internal.InjectedFieldSignature;
import dagger.internal.QualifierMetadata;
import javax.annotation.processing.Generated;
import javax.inject.Provider;

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
public final class SortydApp_MembersInjector implements MembersInjector<SortydApp> {
  private final Provider<HiltWorkerFactory> workerFactoryProvider;

  public SortydApp_MembersInjector(Provider<HiltWorkerFactory> workerFactoryProvider) {
    this.workerFactoryProvider = workerFactoryProvider;
  }

  public static MembersInjector<SortydApp> create(
      Provider<HiltWorkerFactory> workerFactoryProvider) {
    return new SortydApp_MembersInjector(workerFactoryProvider);
  }

  @Override
  public void injectMembers(SortydApp instance) {
    injectWorkerFactory(instance, workerFactoryProvider.get());
  }

  @InjectedFieldSignature("com.sortyd.app.SortydApp.workerFactory")
  public static void injectWorkerFactory(SortydApp instance, HiltWorkerFactory workerFactory) {
    instance.workerFactory = workerFactory;
  }
}
