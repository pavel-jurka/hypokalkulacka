# Mortgage Calculator

An iPad app for simulating a property investment financed by a mortgage. Model the entire loan year by year — see exactly how much you pay in interest, how much rental income you earn, and what your net result is at any point in time.

## Requirements

- iPadOS 17 or later
- Xcode 15+

## Features

### Inputs (left panel)

| Section | Parameter | Default value |
|---|---|---|
| Property | Purchase price | 12,875,000 CZK |
| Property | Own capital | 10 % (1,287,500 CZK) |
| Mortgage | Duration | 20 years |
| Mortgage | Interest rate | 4.50 % |
| Income | Monthly rent | 30,000 CZK |
| Income | Annual rent growth | 2.00 % |
| Repairs | Annual maintenance | 130,000 CZK |
| Repairs | Major maintenance every N years | 10 years / 300,000 CZK |

All values are controlled by sliders — any change instantly recalculates the full schedule.

The app continuously displays:
- **Monthly payment** (calculated from the formula, not editable directly)
- **Break-even year** — the first year the cumulative net result turns positive
- **Net result over the full mortgage term**

### Extra principal payments

Any number of one-off principal payments can be added for specific years:

1. Choose the year with the Stepper (1 — mortgage duration)
2. Set the amount with the slider (10,000 — 3,000,000 CZK, step 10,000 CZK)
3. Tap **Add extra payment**

Each payment has a **toggle** — it can be temporarily disabled without deleting it. This lets you compare scenarios (e.g. "what if I paid an extra 500,000 CZK in year 5?") by simply flipping the switch.

If extra payments pay off the mortgage early, the payoff year is shown.

### Interest rate refixation

Enable the **Rate change after refixation** toggle to simulate what happens when your fixed-rate period ends:

- Set the end of the fixed period (year slider)
- Set the new interest rate
- The monthly payment is automatically recalculated from the remaining balance and remaining term
- The refixation year is marked with a ↺ icon in the table and a vertical line in the amortisation chart

### Rental income tax

Enable **Rental income tax** to include Czech income tax on rental earnings:

| Mode | Basis |
|---|---|
| Flat-rate expense 30 % | Taxable base = 70 % of rental income |
| Actual costs | Taxable base = rent − interest − repairs (min. 0) |

The tax rate slider defaults to 15 % (standard Czech rate). Tax is subtracted from the net result each year and shown as a separate column in the table and a separate snapshot card.

### Snapshot (cumulative overview at a selected year)

The slider at the top of the right panel lets you "travel in time" — drag it to any year and instantly see cumulative values up to that point.

**Including own capital:**

| Card | Description |
|---|---|
| Total payments | Sum of all regular + extra payments |
| of which interest | How much of the above was pure interest cost |
| Remaining debt | Unpaid principal at the end of the selected year |
| Rental income | Cumulative rental income (with annual growth) |
| Net result | Result including the initial own-capital outlay |

**Excluding own capital (pure cash flow, after tax):**

| Card | Description |
|---|---|
| Paid to bank | Same as above |
| Rental income | Same as above |
| Tax | Cumulative tax paid (shown when tax is enabled) |
| Rent − payments − tax | Positive = rent covers payments with surplus |

### Charts

Use the **Chart / Table** toggle in the right panel to switch views.

#### 1. Cumulative net result
A line chart showing the total investment result from day one. Red = in the red, green = in the black. An indigo vertical line marks the year selected in the snapshot slider.

> **Includes:** −own capital + rent − interest − repairs − tax − extra payments  
> **Excludes:** property value, alternative investment returns

#### 2. Payment breakdown: principal vs. interest
Normalised stacked bars (100 %). Early in the mortgage, interest dominates; it reverses towards the end. Shows how much of each payment actually reduces your debt vs. how much is pure cost.

#### 3. Remaining debt and cumulative interest
Two separate series on the same axis:
- **Blue (declining)** — remaining unpaid principal
- **Red (rising)** — cumulative interest paid to date

The intersection means: *"from this year on, you have paid more in interest than you still owe."*

#### 4. Annual net result
One bar per year: `rent − interest − repairs − tax`. A wrench icon marks major maintenance years. Red bars = you topped up out of pocket that year.

### Table

Year-by-year view of all calculated values:

| Column | Description |
|---|---|
| Year | Year number; 🔧 = major maintenance year, ↺ = refixation year |
| Interest | Interest portion of payments (red) |
| Extra payment | One-off principal payment if scheduled (purple) |
| Principal | Debt-reducing portion of payments |
| Remaining debt | Unpaid principal at year end (orange) |
| Rental income | Actual income that year (grows with rent inflation) |
| Tax | Income tax on rental earnings (purple) |
| Repairs | Total annual maintenance cost; bold in major maintenance years |
| Net year | Rent − interest − repairs − tax |
| Cumulative | Total result from the start of the investment |

### PDF export

Tap **Export PDF** in the top bar of the right panel to generate a report. A sheet appears with a **Share / Save to Files** button that opens the system share sheet (AirDrop, Mail, Files, Print…).

The PDF report includes:
- Input parameters summary
- Overall results (colour-coded cards)
- All four charts in a 2 × 2 grid
- Full year-by-year table

## Calculation model

### Annuity payment
The monthly payment is calculated using the standard annuity formula:

```
M = P × r × (1+r)^n / ((1+r)^n − 1)
```

where `P` = mortgage amount, `r` = monthly interest rate (`annual rate / 12`), `n` = total number of months.

### Annual rental income
Rent grows geometrically each year:

```
rent(year) = monthly_rent × 12 × (1 + growth/100)^(year−1)
```

### Interest rate refixation
At the start of the year following the fixed-rate period, the monthly payment is recalculated:

```
new_payment = remaining_balance × r2 × (1+r2)^m / ((1+r2)^m − 1)
```

where `r2` = new monthly rate, `m` = remaining months.

### Rental income tax
Two modes available under Czech tax law (§ 9 Income Tax Act):

- **Flat-rate expense 30 %:** taxable base = rental income × 70 %, tax = base × rate
- **Actual costs:** taxable base = max(0, rent − interest − repairs), tax = base × rate

### Cumulative net result
Starting value = −own capital. Each year adds:

```
Δ = rental_income − interest_paid − repairs − tax − extra_payment
```

Principal repayment (`principalPaid`) is **not subtracted** — it does not leave your net worth, it merely shifts cash into equity in the property.

### Extra payments
Applied at the end of each year after regular payments. Capped at the remaining balance. Once the mortgage is paid off, subsequent years show no payments — net income = rent − repairs − tax.

## Code architecture

```
ContentView.swift
├── TaxMode               — enum: flat-rate expense vs. actual costs
├── ExtraPayment          — one-off principal payment data structure
├── YearData              — computed results for one year (read-only)
├── MortgageViewModel     — @Observable; all inputs + calculation logic
├── czk()                 — helper for formatting CZK amounts
├── ContentView           — root view (NavigationSplitView)
├── InputPanel            — left panel: all sliders and inputs
├── SliderRow             — reusable slider row component
├── DetailPanel           — right panel: Chart ↔ Table toggle + PDF export
├── SnapshotHeader        — year slider + two sets of cumulative cards
├── SnapCard              — individual info card in SnapshotHeader
├── ChartPanel            — ScrollView with four charts (Charts framework)
├── YearTable             — Table view with the amortisation schedule
└── PDFReportView         — view rendered to PDF (parameters, charts, table)
```

**Key technical decisions:**
- `@Observable` instead of `ObservableObject` — requires iOS 17, eliminates `@Published`
- `series:` parameter on `LineMark` — required to keep multiple series separate in one `Chart`; without it, Charts connects all data points into a single jagged line
- `chartForegroundStyleScale` — the only way to generate a chart legend; direct `.foregroundStyle(Color.X)` colours the marks but produces no legend entry
- The amortisation schedule is a computed property (not cached) — fast enough at 30 years × 12 months = 360 iterations
- PDF generation uses `ImageRenderer` → `cgImage` → `CGContext` PDF wrapper (no UIKit dependency)

## What the app does not model

- Property insurance
- Property management fees (letting agent)
- Property value appreciation or depreciation over time
- Alternative investment return on own capital (opportunity cost)
