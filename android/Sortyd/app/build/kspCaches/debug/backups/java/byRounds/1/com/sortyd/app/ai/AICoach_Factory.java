package com.sortyd.app.ai;

import dagger.internal.DaggerGenerated;
import dagger.internal.Factory;
import dagger.internal.QualifierMetadata;
import dagger.internal.ScopeMetadata;
import javax.annotation.processing.Generated;

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
public final class AICoach_Factory implements Factory<AICoach> {
  @Override
  public AICoach get() {
    return newInstance();
  }

  public static AICoach_Factory create() {
    return InstanceHolder.INSTANCE;
  }

  public static AICoach newInstance() {
    return new AICoach();
  }

  private static final class InstanceHolder {
    private static final AICoach_Factory INSTANCE = new AICoach_Factory();
  }
}
