# PocketPilot Budget Page Functionality

## Overview
The Budget Page in PocketPilot generates a personalized monthly budget prescription using historical transaction data. It employs Smart Data Selection and Category Preservation to ensure continuity and realistic budgeting rather than applying generic frameworks.

## How the Budget Page Works

### 1. Data Collection and Analysis
- **Smart Data Selection**: Identifies the most reliable and recent transaction dataset for budget computation
- **Transaction Analysis**: Analyzes spending patterns across different categories
- **Income Assessment**: Uses declared monthly net income or calculates it from transaction history

### 2. Base Data Selection Process
The system analyzes available months with transaction data and follows these rules:

1. **Analyze all available months** with transaction data
2. **Select the most recent month** with ≥80% data completeness
3. **If only one month is available** → use that month
4. **If multiple months qualify** (≥80%) → always choose the latest month

**Completeness Calculation**:
```
dataCompleteness = (numberOfCategoriesFilled / totalExpectedCategories) * 100
```

### 3. Category Preservation
The system maintains consistent budgeting categories even when they don't appear in the selected month:

#### Preservation Rules:
- **Include all historical categories**: All categories that have ever appeared in the user's transaction history
- **Estimated values for missing categories**: 
  - If a category existed in previous months but not in the base month, include with estimated value
  - Use either average from past appearances or last known amount
- **Frequency-based inclusion**: 
  - If a category didn't appear last month but was frequent in earlier months (appeared in ≥50% of total recorded months), include with estimated average
- **6-month window rule**: 
  - If a category has not appeared in the last 6 months, exclude it from the active budget
  - Supported by financial research identifying a 6-month inactivity window as sufficient to distinguish recurring expenses from non-recurring costs

### 4. Budget Computation Logic

#### Fixed Needs Categories:
- **Examples**: Housing & Utilities, Debt, Education, Childcare, Health & Personal Care
- **Data Source**: Selected base month
- **Missing values**: Use the most recent value before the base month

#### Flexible Needs Categories:
- **Examples**: Food, Transportation, Entertainment & Lifestyle
- **Formula**: `projectedValue = (totalSpent / daysLogged) * daysInCurrentMonth`
- **Minimum daily constraints**:
  - Food ≥ ₱100/day
  - Transport ≥ ₱50/day
- **Auto-adjustment**: If projected values fall below minimum, automatically adjust upward

### 5. Validation and Adjustment Process

The system ensures the total budget stays within net income limits:

| Case | Condition | System Action |
|------|-----------|---------------|
| A | Fixed > Income | Set flexible categories to minimums |
| B | Fixed + Flexible > Income | Apply proportional scaling across flexible categories |
| C | Fixed + Minimum Flexible > Income | Flag as unsustainable and recommend adjustment |

### 6. Category Continuity
- **Maintain recurring categories**: Keep all recurring categories unless excluded by the 6-month inactivity rule
- **Preserve visual continuity**: Maintain familiar budgeting structure across months
- **Never show ₱0 allocations**: Always provide meaningful values

### 7. Output & Display Logic

#### Display Rules:
- **Fixed Needs**: Show as monthly total
- **Flexible Needs**: Show as daily or weekly total
- **Confidence Level Indicators**:
  - High (≥80%)
  - Medium (50–79%)
  - Low (<50%)
- **Estimated Labels**: Categories with estimated values display an "Estimated" label for transparency

## Data Source Priority Hierarchy

1. **Most recent month** (≥80% completeness)
2. **Fallback to previous month** (if missing categories)
3. **Use past averages** for continuity
4. **Exclude inactive** (6-month gap) categories

## Example Scenario

| Category | Last Seen | Base Month Data | Included? | Value Used |
|----------|-----------|-----------------|-----------|------------|
| Food | Current Month | ₱7,500 | ✅ | ₱7,500 |
| Transport | Current Month | ₱2,000 | ✅ | ₱2,000 |
| Education | Last Month | — | ✅ | Averaged Value |
| Childcare | 3 Months Ago | — | ✅ | Averaged Value |
| Debt | 7 Months Ago | — | ❌ | Excluded |

## Key Features

### 1. Confidence Level Indicator
- **High**: 80%+ data completeness or 25+ transactions
- **Medium**: 50-79% completeness or 15-24 transactions
- **Low**: Below 50% completeness or fewer than 15 transactions

### 2. Emergency Fund Tracking
- Calculates emergency fund goal based on 3 months of highest expenses
- Shows progress toward building your safety net

### 3. Budget Utilization
- Shows what percentage of your income is allocated to the budget
- Highlights if you're over-budget

### 4. Real-time Updates
- Automatically refreshes when new transactions are added
- Recalculates budgets based on current spending patterns

## User Interface Components

1. **Budget Overview Header**: Shows personalized budget for the current month
2. **Daily Budget Allowance**: Flexible spending for each day
3. **Fixed Monthly Expenses**: Recurring expenses and savings goals
4. **Budget Allocation Summary**: Total budget breakdown with remaining funds
5. **Emergency Fund Progress**: Tracking toward 3-month safety net
6. **Budgeting Tips**: Personalized advice based on your spending patterns

The Budget Page provides a comprehensive, personalized approach to financial planning that adapts to your actual spending patterns rather than applying generic budgeting rules.