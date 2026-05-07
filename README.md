# Mortgage Calculator (Hypoteční kalkulačka)

An iPad investment simulator for property financed by a mortgage. Not a simple payment calculator — a complete financial model that answers: *"Is this property worth buying as a rental investment?"*

[![Build & Test](https://github.com/pavel-jurka/hypokalkulacka/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/pavel-jurka/hypokalkulacka/actions)

Unlike standard mortgage calculators, this app models:
- **Rental cash flow** with vacancy, growth, and operating costs
- **Equity accumulation** — principal repayment builds net worth, not just cost
- **Czech rental taxation** — flat-rate 30% expense or actual costs (§ 9 ZDP)
- **Extra payments** — manual or automatic from rental income
- **Property appreciation/depreciation** (−5% to +10%/year)
- **Inflation-adjusted returns** and alternative investment comparison
- **Scenario comparison** — save, load, and compare A vs B side by side

## Screenshots

> *TODO: Add 3–4 screenshots (input panel, charts, snapshot cards, scenario comparison)*

## Quick Start

```bash
git clone https://github.com/pavel-jurka/hypokalkulacka.git
cd hypokalkulacka
open MortgageCalculator.xcodeproj
```

Requirements: iPadOS 17+ / macOS 14+, Xcode 15+, no external dependencies.

## Features

### Financial Model

| Category | Parameters |
|---|---|
| **Property** | Price (1M–30M CZK), own capital (5–50%), reconstruction (0–2M), appreciation (−5% to +10%) |
| **Mortgage** | Duration (5–30y), interest rate (0.5–10%), refixation after N years |
| **Rental income** | Monthly rent (10k–80k), annual growth (0–8%), vacancy (0–4 months/year) |
| **Operating costs** | Insurance, SVJ/maintenance fund, property management fee (% of rent) |
| **Repairs** | Annual maintenance + periodic major repairs every N years |
| **Tax** | Czech income tax — flat-rate 30% or actual costs with full deductions (§ 9 ZDP) |
| **Extra payments** | Manual one-off + automatic rent-as-payments (reactive, grows with rent) |
| **Investment view** | Appreciation, alternative return comparison, inflation discount |
| **Scenarios** | Save named scenarios, load, compare side by side |

### Interactive UI

- **4 charts** — amortization breakdown, cumulative net result, debt vs. interest, annual result
- **Snapshot slider** — drag to any year, see 3 rows of cumulative cards
- **PDF export** — parameters, result cards, charts, full year-by-year table
- **Toggle-based** — every feature is optional, flip switches to compare scenarios instantly

### Calculation Model

Annuity: `M = P × r × (1+r)^n / ((1+r)^n − 1)`

Net result: `−own_capital + Σ(rent − interest − repairs − operating − tax − extra)`

Principal repayment is NOT subtracted — it converts cash into property equity.

Total investment: `cumulative_net + property_value − remaining_debt`

### Performance

~360 monthly iterations per recalculation. Instant on any modern device — no caching needed.

## Architecture

```mermaid
graph TD
    Views[Views — SwiftUI] --> ViewModel[@Observable ViewModel]
    ViewModel --> Engine[CalculationEngine — pure functions]
    Engine --> Models[Models — domain types]
    ViewModel --> Store[ScenarioStore — persistence]
    Store --> Models
```

The calculation engine has **zero SwiftUI dependency** — pure static functions that accept `MortgageInputs` and return `[YearData]`. Fully testable independently.

Financial types (`CZK`, `Percent`, `Years`, `Months`) are typealiases — semantic clarity without breaking SwiftUI bindings.

<details>
<summary>Detailed file structure</summary>

```
MortgageCalculator/
├── .github/workflows/
│   └── build-and-test.yml              — CI: build + test on push/PR
├── MortgageCalculator/
│   ├── MortgageCalculatorApp.swift     — entry point (@main)
│   ├── FinancialTypes.swift            — CZK, Percent, Years, Months + formatter
│   ├── Models.swift                    — TaxMode, ExtraPayment, YearData, MortgageInputs
│   ├── CalculationEngine.swift         — pure calculation functions (~220 lines)
│   ├── MortgageViewModel.swift         — @Observable ViewModel (~205 lines)
│   ├── ScenarioStore.swift             — save/load scenarios (UserDefaults)
│   ├── ContentView.swift               — root view (21 lines)
│   └── Views/
│       ├── InputPanel.swift            — left panel with all inputs
│       ├── DetailPanel.swift           — right panel container
│       ├── SnapshotHeader.swift        — cumulative overview cards
│       ├── ChartPanel.swift            — 4 interactive charts
│       ├── YearTable.swift             — amortization table
│       ├── PDFReportView.swift         — PDF generation
│       └── ScenarioManagerView.swift   — save/load/compare scenarios
├── MortgageCalculatorTests/            — 45+ unit tests (XCTest)
├── README.md
└── CLAUDE.md                           — AI assistant context
```

</details>

<details>
<summary>Key design decisions</summary>

| Decision | Why |
|---|---|
| `@Observable` (not `ObservableObject`) | Eliminates `@Published` boilerplate, cleaner reactivity |
| Separated domain layer | Engine is pure, testable independently. `MortgageInputs` decouples UI from computation |
| Financial typealiases | Semantic clarity without wrapper complexity |
| Computed `schedule` | Reactive to every input change. 360 iterations = instant |
| XCTest (not Swift Testing) | Universal Xcode compatibility for CI |
| PDF via `ImageRenderer` → `cgImage` → `CGContext` | No UIKit dependency |
| `@Observable` + explicit `save()` | `didSet` is unreliable with `@Observable` macro |

</details>

## Testing

45+ unit tests covering annuity formula, amortization invariants, tax computation (both modes), refixation, extra payments (reactivity, capping, rent growth), operating costs, property appreciation, snapshot values, edge cases, financial precision with known reference values, and direct CalculationEngine tests.

```bash
xcodebuild test \
  -scheme MortgageCalculator \
  -destination 'platform=macOS' \
  -only-testing:MortgageCalculatorTests
```

## CI/CD

GitHub Actions on every push/PR to `main`: build + unit tests on macOS 15, Xcode 16, Node.js 24.

## Roadmap

- [ ] Screenshots in README
- [ ] iCloud scenario sync
- [ ] Monte Carlo stress testing (rate hikes, rent drops, vacancy spikes)
- [ ] Monthly cash flow granularity
- [ ] Portfolio mode (multiple properties)
- [ ] Refinancing comparison
- [ ] Localization (EN)
- [ ] macOS native layout

## What the App Does Not Model

- Mortgage insurance (pojištění schopnosti splácet)
- Vacancy patterns beyond average months/year
- Depreciation allowance as tax deduction
- Currency other than CZK

## License

Private project.
