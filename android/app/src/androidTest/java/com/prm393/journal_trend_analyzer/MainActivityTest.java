package com.prm393.journal_trend_analyzer;

import android.Manifest;
import android.os.Build;

import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.rule.GrantPermissionRule;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TestRule;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;

import pl.leancode.patrol.PatrolJUnitRunner;

// Patrol JUnit entry point (Lab 03 Phase 10). Discovers the Dart integration
// tests and runs each as a parameterized native test.
@RunWith(Parameterized.class)
public class MainActivityTest {
    // Grants POST_NOTIFICATIONS before every test method so the native
    // "Allow app to send you notifications?" dialog (triggered at launch by
    // NotificationsViewModel) can never appear and cover/steal focus from the
    // Flutter UI mid-test. `testInstrumentationRunnerArguments["grantPermissions"]`
    // in build.gradle.kts was tried first but PatrolJUnitRunner does not honor
    // it; this JUnit rule is applied directly by the instrumentation and is
    // confirmed to work (verified on a real device — TC8 was failing because
    // this exact dialog covered the Profile screen).
    @Rule
    public TestRule permissionRule = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
            ? GrantPermissionRule.grant(Manifest.permission.POST_NOTIFICATIONS)
            : new org.junit.rules.ExternalResource() {};

    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
