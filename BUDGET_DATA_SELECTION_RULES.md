# Budget Data Selection Rules

This document explains the rules used by PocketPilot to select which month's data to use for generating budget prescriptions.

## Monthly Data Rule (Updated)

The budget prescription system uses the following hierarchy to determine which month's data to use:

### 1. Reliable Data Criteria (Carry-over Ready)
If the **previous month** meets either of these criteria:
- **≥ 80%** of days filled with transaction data, OR
- **25+ transactions** recorded

**Action**: Use the previous month's data directly for the current month's budget prescription.
**Additional**: This month's data can be carried over if the next month does not meet requirements.

### 2. Strong Data Criteria (High Reliability)
If the **previous month** meets either of these criteria:
- **≥ 70%** of days filled with transaction data, OR
- **20+ transactions** recorded

**Action**: Use the previous month's data directly for the current month's budget prescription.
**Additional**: Budget is more reliable than just 50%, but the data cannot be carried over to future months.

### 3. Usable Data Criteria (Basic)
If the **previous month** meets either of these criteria:
- **≥ 50%** of days filled with transaction data, OR
- **15+ transactions** recorded

**Action**: Use the previous month's data temporarily for the current month's budget prescription.
**Additional**: The app can generate a budget based on this data.

### 4. Carry-over from Last Reliable Month
If the previous month does **not** meet the usable criteria, the system looks backward to find the **most recent month** that met the reliable data criteria (≥ 80% days or 25+ transactions).

**Action**: Carry over that month's data for the current month's budget prescription.

### 5. Fallback (Insufficient Data)
If none of the above criteria are met:

**Action**: Use the last reliable month's data (≥ 80% days or 25+ transactions).
**Additional**: If no reliable month exists, use the previous month's data anyway, but with low confidence.

## Motivational Nudges

The system provides motivational nudges based on data completeness:

- **At 60–69% logged**: "You're close to a strong budget! Log a few more days to reach 70%."
- **At 70–79% logged**: "Great job! To make this month reliable and carry-over ready, aim for 80%."
- **At ≥ 80% logged**: "Excellent! This month's data is reliable and will be used for future budgets if needed."

## Updated Example Timeline

| Month    | Data Completeness | Transactions | Status         | Action Taken              |
|----------|-------------------|--------------|----------------|---------------------------|
| August   | 55% (16 days)     | 16           | Usable         | Used for budget           |
| September| 40% (12 days)     | 10           | Insufficient   | Carry over August data    |
| October  | 82% (25 days)     | 30           | Reliable       | Used directly + carry-over|
| November | 75% (23 days)     | 22           | Strong         | Used directly             |
| December | 72% (22 days)     | 18           | Strong         | Used directly             |
| January  | 10% (3 days)      | 8            | Insufficient   | Carry over October data   |

## Confidence Levels

The system assigns confidence levels based on data quality:

- **High Confidence**: Reliable data criteria met (80%+ days OR 25+ transactions)
- **Medium-High Confidence**: Strong data criteria met (70%+ days OR 20+ transactions)
- **Medium Confidence**: Usable data criteria met (50%+ days OR 15+ transactions)
- **Low Confidence**: Neither reliable, strong, nor usable criteria met

## Tips for Users

When the system uses temporary or insufficient data, it provides actionable tips to help users improve their data quality:
- "You're close to a strong budget! Log a few more days to reach 70%."
- "Great job! To make this month reliable and carry-over ready, aim for 80%."
- "Excellent! This month's data is reliable and will be used for future budgets if needed."
- "Log more transactions to improve budget accuracy."

These tips encourage better financial tracking habits that lead to more accurate and personalized budget recommendations.