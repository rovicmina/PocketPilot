package com.pocketpilot.app;

import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Intent;
import androidx.core.view.WindowCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "pocketpilot/widget";

    @Override
    protected void onCreate(android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Enable edge-to-edge display for Android 15+ compatibility
        // Use WindowCompat for better compatibility
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                try {
                    switch (call.method) {
                        case "updateWidget":
                            try {
                                updateHomeScreenWidget();
                                result.success("Widget updated successfully");
                                android.util.Log.d("MainActivity", "Widget update requested and completed");
                            } catch (Exception e) {
                                android.util.Log.e("MainActivity", "Widget update failed: " + e.getMessage(), e);
                                result.error("UPDATE_FAILED", e.getMessage(), e.toString());
                            }
                            break;
                        case "isSupported":
                            result.success(true);
                            android.util.Log.d("MainActivity", "Widget support check: true");
                            break;
                        case "getWidgetConfig":
                            try {
                                Map<String, Object> config = new HashMap<>();
                                config.put("supported", true);
                                config.put("platform", "android");
                                config.put("version", "1.0");
                                result.success(config);
                                android.util.Log.d("MainActivity", "Widget config requested");
                            } catch (Exception e) {
                                android.util.Log.e("MainActivity", "Error getting widget config: " + e.getMessage(), e);
                                result.error("CONFIG_ERROR", e.getMessage(), null);
                            }
                            break;
                        default:
                            android.util.Log.w("MainActivity", "Unknown method called: " + call.method);
                            result.notImplemented();
                            break;
                    }
                } catch (Exception e) {
                    android.util.Log.e("MainActivity", "Unexpected error in method channel: " + e.getMessage(), e);
                    result.error("UNEXPECTED_ERROR", e.getMessage(), e.toString());
                }
            });
    }

    private void updateHomeScreenWidget() {
        try {
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
            ComponentName componentName = new ComponentName(this, BudgetWidgetProvider.class);
            int[] appWidgetIds = appWidgetManager.getAppWidgetIds(componentName);
            
            if (appWidgetIds.length > 0) {
                // Update each widget individually
                for (int appWidgetId : appWidgetIds) {
                    BudgetWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId);
                }
                
                // Also send broadcast for additional widget updates
                Intent intent = new Intent(this, BudgetWidgetProvider.class);
                intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds);
                sendBroadcast(intent);
                
                android.util.Log.d("MainActivity", "Updated " + appWidgetIds.length + " widget(s)");
            } else {
                android.util.Log.i("MainActivity", "No widgets found to update");
            }
        } catch (Exception e) {
            android.util.Log.e("MainActivity", "Error updating home screen widget: " + e.getMessage(), e);
            throw e; // Re-throw to be handled by the method channel
        }
    }
}