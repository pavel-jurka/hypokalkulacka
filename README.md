# Mortgage Calculator (Hypoteční kalkulačka)

A comprehensive iPad app for simulating property investment financed by a mortgage. Model the full lifecycle year by year — see exactly how much you pay in interest, how rental income offsets costs, and what your total investment result looks like after 5, 10, or 30 years.

Built for real-world decision making, not just a demo calculator.

[![Build & Test](https://github.com/pavel-jurka/hypokalkulacka/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/pavel-jurka/hypokalkulacka/actions)

## Requirements

- iPadOS 17 or later
- Xcode 15+ / Swift 5.9+
- No external dependencies — pure Apple frameworks

## Architecture

```
ContentView.swift (~1,450 lines)
├── TaxMode               — enum: flat-rate vs. actual costs
├── ExtraPayment          — one-off principal payment (manual or auto-generated)
├── YearData              — computed results for one year (immutable struct)
├── MortgageViewModel     — @Observable; inputs + calculation engine
│   ├── schedule          — computed amortization schedule [YearData]
│   ├── autoExtraPayments — computed: rent-as-payments (reactive)
│   └── computeTax()      — Czech tax law § 9 ZDP
├── ContentView           — NavigationSplitView root
├── InputPanel            — left panel: all inputs as sliders/toggles
├── DetailPanel           — right panel: charts/table + PDF export
├── SnapshotHeader        — year slider + cumulative overview cards
├── ChartPanel            — 4 interactive charts (Swift Charts)
├── YearTable             — full amortization schedule table
└── PDFReportView         — rendered to PDF via ImageRenderer
```

**Key design decisions:**

| Decision | Why |
|---|---|
| `@Observable` (not `ObservableObject`) | Eliminates `@Published` boilerplate, cleaner reactivity. Requires iOS 17. |
| Single file | All logic + UI in one place. Fast iteration, easy to search. No premature abstraction. |
| Computed `schedule` | Recalculates on every input change. 30 years × 12 months = 360 iterations — instant. |
| Computed `autoExtraPayments` | Reactive to all input changes (rent, vacancy, rate...). No stale state. |
| `series:` on `LineMark` | Required to keep multiple chart series separate. Without it, Charts connects all points into one jagged line. |
| `chartForegroundStyleScale` | Only way to generate a legend in Swift Charts. |
| PDF via `ImageRenderer → cgImage → CGContext` | Reliable cross-platform approach. No UIKit dependency. |
| SwiftUI `Table` 10-column limit | Repairs + operating costs merged into single "Náklady" column. |

## Features

### Financial Model

The calculator models a complete property investment scenario:

| Category | Parameters |
|---|---|
| **Property** | Purchase price (1M–30M CZK), own capital (5–50%), optional reconstruction (0–2M) |
| **Mortgage** | Duration (5–30 years), interest rate (0.5–10%), optional rate refixation |
| **Rental income** | Monthly rent (10k–80k), annual growth (0–8%), vacancy (0–4 months/year) |
| **Operating costs** | Insurance, SVJ/maintenance fund, optional property management fee (% of rent) |
| **Repairs** | Annual maintenance + periodic major repairs |
| **Tax** | Czech income tax on rental income — flat-rate 30% expense or actual costs (§ 9 ZDP) |
| **Extra payments** | Manual one-off payments + automatic rent-as-payments (computed, reactive) |
| **Investment view** | Property appreciation, alternative investment comparison, inflation discount |

### Calculation Model

**Annuity formula:**
```
M = P × r × (1+r)^n / ((1+r)^n − 1)
```
where `P` = mortgage amount, `r` = monthly rate, `n` = total months.

**Cumulative net result:**
```
Start = −own_capital
Each year += rent − interest − repairs − operating_costs − tax − extra_payment
```
Principal repayment is NOT subtracted — it converts cash into property equity.

**Tax (Czech law § 9 ZDP):**
- Flat-rate: taxable base = 70% of rental income
- Actual costs: taxable base = max(0, rent − interest − repairs − management − insurance − SVJ)

**Total investment result:**
```
cumulative_net + property_value − remaining_debt
```

### Interactive Features

- **4 charts:** amortization breakdown, cumulative net result, debt vs. cumulative interest, annual net result
- **Snapshot slider:** drag to any year, see cumulative values across 3 rows of cards (investor view, investment view, cash flow)
- **PDF export:** full report with parameters, result cards, charts (2×2 grid), year-by-year table
- **Toggle-based:** every feature is optional — compare scenarios by flipping switches
- **Auto extra payments:** enable "rent as payments" and the app computes how many years of rental income pay off the mortgage early. Amounts grow with rent, react to all parameter changes.

### UI

- All text in **Czech** (labels, sections, charts, table, PDF)
- Currency: CZK with thin-space grouping, compact format in charts (1.2 M / 350 k)
- iPad-optimized: `NavigationSplitView` with left input panel + right detail panel

## Testing

Comprehensive unit tests covering:

- **Annuity formula** — standard, zero-rate, short term, known reference values
- **Amortization invariants** — balance reaches zero, principal + interest = payment, monotonicity
- **Rental income** — geometric growth, vacancy reduction
- **Tax computation** — both modes, all deductible costs, disabled state
- **Refixation** — payment changes, year marking
- **Extra payments** — balance reduction, capping, auto-reactivity, rent growth
- **Operating costs** — impact on net result, management fee calculation
- **Property appreciation** — value growth, total investment result
- **Snapshot** — year selection, opportunity cost, inflation discount
- **Edge cases** — min/max values, all features enabled simultaneously
- **Financial precision** — known reference values, payment composition over time

Run tests:
```bash
xcodebuild test \
  -scheme HypotecniKalkulacka \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```

## CI/CD

GitHub Actions workflow runs on every push and PR to `main`:
- **Build** — compile the full project
- **Test** — run all unit tests

## What the App Does Not Model

- Property value depreciation scenarios (only appreciation)
- Mortgage insurance (pojištění schopnosti splácet)
- Property management beyond simple fee percentage
- Vacancy patterns (only average months/year)
- Depreciation allowance as a tax deduction
- Multiple properties / portfolio view
- Currency other than CZK

## Project Structure

```
HypotecniKalkulacka/
├── .github/workflows/
│   └── build-and-test.yml          — CI: build + test on push/PR
├── HypotecniKalkulacka/
│   ├── HypotecniKalkulackaApp.swift — entry point (@main)
│   ├── ContentView.swift            — all logic + UI (~1,450 lines)
│   └── Assets.xcassets/             — app icon + colors
├── HypotecniKalkulackaTests/
│   └── HypotecniKalkulackaTests.swift — 35+ unit tests
├── README.md                        — this file
└── CLAUDE.md                        — AI assistant project context
```

## License

Private project.
