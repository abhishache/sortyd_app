package com.sortyd.app

import com.sortyd.app.data.model.HealthTaskType
import org.junit.Assert.*
import org.junit.Test

class HealthTaskTypeTest {

    // ── detect(): English ──

    @Test fun detectSteps_dailySteps() = assertEquals(HealthTaskType.STEPS, HealthTaskType.detect("Walk 10,000 daily steps"))
    @Test fun detectSteps_pedometer() = assertEquals(HealthTaskType.STEPS, HealthTaskType.detect("Check pedometer"))
    @Test fun detectSteps_highConfidence() = assertEquals(HealthTaskType.STEPS, HealthTaskType.detect("Hit 10k steps today"))
    @Test fun detectSteps_walkingWord() = assertEquals(HealthTaskType.STEPS, HealthTaskType.detect("Go walking in the park"))

    @Test fun detectCalories_burned() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("Calories burned target"))
    @Test fun detectCalories_cardio() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("Do cardio session"))
    @Test fun detectCalories_gym() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("Go to the gym"))
    @Test fun detectCalories_weightLoss() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("Weight loss challenge"))

    @Test fun detectDistance_run5km() = assertEquals(HealthTaskType.DISTANCE, HealthTaskType.detect("Run 5km today"))
    @Test fun detectDistance_jogging() = assertEquals(HealthTaskType.DISTANCE, HealthTaskType.detect("Go jogging"))
    @Test fun detectDistance_kilometers() = assertEquals(HealthTaskType.DISTANCE, HealthTaskType.detect("Track 10 kilometers"))

    // ── detect(): Arabic ──

    @Test fun detectSteps_arabic() = assertEquals(HealthTaskType.STEPS, HealthTaskType.detect("١٠ آلاف خطوة"))
    @Test fun detectDistance_arabic() = assertEquals(HealthTaskType.DISTANCE, HealthTaskType.detect("جري ٥ كم"))
    @Test fun detectCalories_arabic() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("تمرين يومي"))

    // ── detect(): Spanish ──

    @Test fun detectSteps_spanish() = assertEquals(HealthTaskType.STEPS, HealthTaskType.detect("10k pasos diarios"))
    @Test fun detectDistance_spanish() = assertEquals(HealthTaskType.DISTANCE, HealthTaskType.detect("Correr 5km"))
    @Test fun detectCalories_spanish() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("Calorías quemadas"))

    // ── detect(): null (not a health task) ──

    @Test fun noDetect_randomTask() = assertNull(HealthTaskType.detect("Buy groceries"))
    @Test fun noDetect_energyDrink() = assertNull(HealthTaskType.detect("Buy an energy drink"))
    @Test fun noDetect_stepByStep() = assertNull(HealthTaskType.detect("Follow step by step tutorial"))
    @Test fun noDetect_walkIn() = assertNull(HealthTaskType.detect("Walk in interview scheduled"))
    @Test fun noDetect_sidewalk() = assertNull(HealthTaskType.detect("Fix the sidewalk"))
    @Test fun noDetect_burnDown() = assertNull(HealthTaskType.detect("Create a burn down chart"))
    @Test fun noDetect_study() = assertNull(HealthTaskType.detect("Study for exam"))
    @Test fun noDetect_career() = assertNull(HealthTaskType.detect("Update career portfolio"))
    @Test fun noDetect_piano() = assertNull(HealthTaskType.detect("Practice piano lessons"))

    // ── "workout" must NOT be excluded ──
    @Test fun workout_mapsToCalories() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("Do a workout session"))
    @Test fun workout_uppercaseVariant() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.detect("Complete WORKOUT"))

    // ── "work" in a non-health context should still return null ──
    @Test fun noDetect_workMeeting() = assertNull(HealthTaskType.detect("Attend work meeting"))
    @Test fun noDetect_workProject() = assertNull(HealthTaskType.detect("Finish work project"))

    // ── detect(): priority — distance > steps > calories ──

    @Test fun priority_distanceOverCalories() {
        // "run" is a distance word, even though the sentence also mentions exercise (calorie word)
        assertEquals(HealthTaskType.DISTANCE, HealthTaskType.detect("Run and exercise daily"))
    }

    @Test fun priority_stepsOverCalories() {
        // "walk" is a step word; "activity" is calorie word — steps should win
        assertEquals(HealthTaskType.STEPS, HealthTaskType.detect("Daily walk activity"))
    }

    // ── defaultTarget ──

    @Test fun defaultTarget_steps() = assertEquals(10_000.0, HealthTaskType.defaultTarget(HealthTaskType.STEPS), 0.0)
    @Test fun defaultTarget_calories() = assertEquals(500.0, HealthTaskType.defaultTarget(HealthTaskType.CALORIES), 0.0)
    @Test fun defaultTarget_distance() = assertEquals(5.0, HealthTaskType.defaultTarget(HealthTaskType.DISTANCE), 0.0)

    // ── fromRawValue ──

    @Test fun fromRawValue_steps() = assertEquals(HealthTaskType.STEPS, HealthTaskType.fromRawValue("steps"))
    @Test fun fromRawValue_calories() = assertEquals(HealthTaskType.CALORIES, HealthTaskType.fromRawValue("calories"))
    @Test fun fromRawValue_distance() = assertEquals(HealthTaskType.DISTANCE, HealthTaskType.fromRawValue("distance"))
    @Test fun fromRawValue_null() = assertNull(HealthTaskType.fromRawValue(null))
    @Test fun fromRawValue_unknown() = assertNull(HealthTaskType.fromRawValue("heartrate"))
}
