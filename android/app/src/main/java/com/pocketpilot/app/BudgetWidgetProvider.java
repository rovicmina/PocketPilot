package com.pocketpilot.app;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import org.json.JSONObject;

public class BudgetWidgetProvider extends AppWidgetProvider {

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        android.util.Log.d("BudgetWidget", "onUpdate called for " + appWidgetIds.length + " widget(s)");
        
        for (int appWidgetId : appWidgetIds) {
            try {
                updateAppWidget(context, appWidgetManager, appWidgetId);
                android.util.Log.d("BudgetWidget", "Successfully updated widget ID: " + appWidgetId);
            } catch (Exception e) {
                android.util.Log.e("BudgetWidget", "Failed to update widget ID " + appWidgetId + ": " + e.getMessage(), e);
                // Try to show a basic error state for this specific widget
                showErrorState(context, appWidgetManager, appWidgetId, "Update failed");
            }
        }
    }
    
    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        android.util.Log.d("BudgetWidget", "Widget enabled - first widget added to home screen");
    }
    
    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        android.util.Log.d("BudgetWidget", "Widget disabled - last widget removed from home screen");
    }

    public static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        try {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.budget_widget);

            // Get widget data from SharedPreferences
            WidgetData widgetData = getWidgetData(context);
            
            // Format currency numbers
            int budget = (int) Math.max(0, widgetData.budget);
            int expenses = (int) Math.max(0, widgetData.expenses);
            int percentage = budget > 0 ? (int) Math.min(100, (expenses * 100) / budget) : 0;
            
            // Update budget and expense amounts (side by side)
            views.setTextViewText(R.id.budget_amount, formatCurrency(budget));
            views.setTextViewText(R.id.expenses_amount, formatCurrency(expenses));
            
            // Update spending percentage with color coding
            String percentageText = percentage + "% spent";
            views.setTextViewText(R.id.spending_percentage, percentageText);
            
            // Get simple daily tip
            String dailyTip = getSimpleDailyTip(percentage);
            views.setTextViewText(R.id.daily_tip, dailyTip);
            
            // Set up click intent to open app
            Intent intent = new Intent(context, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent pendingIntent = PendingIntent.getActivity(
                context, 0, intent, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent);

            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views);
            
            android.util.Log.d("BudgetWidget", "Widget updated - Budget: " + budget + ", Expenses: " + expenses + ", " + percentage + "% spent");
            
        } catch (Exception e) {
            android.util.Log.e("BudgetWidget", "Error updating widget: " + e.getMessage(), e);
            showErrorState(context, appWidgetManager, appWidgetId, "Error loading data");
        }
    }
    
    private static String formatCurrency(int amount) {
        if (amount >= 1000000) {
            return "₱" + String.format("%.1f", amount / 1000000.0) + "M";
        } else if (amount >= 1000) {
            return "₱" + String.format("%.1f", amount / 1000.0) + "K";
        } else {
            return "₱" + amount;
        }
    }
    
    private static String getSimpleDailyTip(int spentPercentage) {
        // Simple daily tips based on spending percentage - no external dependencies
        if (spentPercentage >= 100) {
            return "Budget fully used! Consider saving for tomorrow.";
        } else if (spentPercentage >= 90) {
            return "Budget almost used! Consider saving for tomorrow.";
        } else if (spentPercentage >= 70) {
            return "Watch your spending! You're at " + spentPercentage + "% of budget.";
        } else if (spentPercentage >= 50) {
            return "Halfway through your budget. Stay mindful of expenses.";
        } else if (spentPercentage >= 25) {
            return "Good spending pace! Keep tracking your expenses.";
        } else {
            return "Great start! Every peso saved builds wealth.";
        }
    }
    
    private static WidgetData getWidgetData(Context context) {
        try {
            SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            String jsonString = prefs.getString("flutter.native_widget_data", null);
            
            android.util.Log.d("BudgetWidget", "Raw widget data: " + (jsonString != null ? jsonString : "null"));
            
            if (jsonString != null && !jsonString.isEmpty()) {
                try {
                    JSONObject json = new JSONObject(jsonString);
                    WidgetData data = new WidgetData(
                        json.optDouble("budget", 500.0),    // Default to ₱500 if missing
                        json.optDouble("expenses", 0.0),
                        json.optDouble("remaining", 500.0),
                        json.optDouble("percentage", 0.0)
                    );
                    android.util.Log.d("BudgetWidget", "Parsed widget data - Budget: " + data.budget + ", Expenses: " + data.expenses);
                    return data;
                } catch (Exception jsonException) {
                    android.util.Log.e("BudgetWidget", "Error parsing widget data JSON: " + jsonException.getMessage());
                    return getDefaultWidgetData();
                }
            } else {
                android.util.Log.i("BudgetWidget", "No widget data found, using defaults");
                return getDefaultWidgetData();
            }
        } catch (Exception e) {
            android.util.Log.e("BudgetWidget", "Unexpected error getting widget data: " + e.getMessage());
            return getDefaultWidgetData();
        }
    }
    
    private static WidgetData getDefaultWidgetData() {
        // Return sensible defaults for initial widget display
        android.util.Log.d("BudgetWidget", "Using default widget data");
        return new WidgetData(500.0, 0.0, 500.0, 0.0); // ₱500 budget, ₱0 expenses
    }
    
    public static class WidgetData {
        public double budget;
        public double expenses;
        public double remaining;
        public double percentage;
        
        public WidgetData() {
            this.budget = 0.0;
            this.expenses = 0.0;
            this.remaining = 0.0;
            this.percentage = 0.0;
        }
        
        public WidgetData(double budget, double expenses, double remaining, double percentage) {
            this.budget = budget;
            this.expenses = expenses;
            this.remaining = remaining;
            this.percentage = percentage;
        }
    }
    
    private static void showErrorState(Context context, AppWidgetManager appWidgetManager, int appWidgetId, String errorMessage) {
        try {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.budget_widget);
            
            // Show simple error state
            views.setTextViewText(R.id.budget_amount, "₱0");
            views.setTextViewText(R.id.expenses_amount, "₱0");
            views.setTextViewText(R.id.spending_percentage, "0% spent");
            views.setTextViewText(R.id.daily_tip, errorMessage != null ? errorMessage : "Loading...");
            
            // Still allow clicking to open the app
            Intent intent = new Intent(context, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            PendingIntent pendingIntent = PendingIntent.getActivity(
                context, 0, intent, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent);
            
            appWidgetManager.updateAppWidget(appWidgetId, views);
            android.util.Log.d("BudgetWidget", "Error state displayed: " + errorMessage);
            
        } catch (Exception e) {
            android.util.Log.e("BudgetWidget", "Failed to show error state: " + e.getMessage(), e);
        }
    }
}