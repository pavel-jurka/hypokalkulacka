/// Unit testy pro výpočetní logiku hypoteční kalkulačky.
/// Pokrývají anuitní splátku, amortizaci, daň, edge cases i finanční přesnost.

import Testing
@testable import HypotecniKalkulacka

private func testPow(_ base: Double, _ exp: Double) -> Double {
    Darwin.pow(base, exp)
}

// MARK: - Annuity Formula

struct AnnuityTests {

    @Test func standardAnnuity() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.ownCapitalPct = 20
        vm.mortgageYears = 30
        vm.interestRate = 5.0
        vm.includeReconstruction = false

        // Mortgage = 8M, rate 5%, 30y → expected ~42,944 CZK/month
        let mp = vm.monthlyPayment
        #expect(mp > 42_000 && mp < 44_000, "Monthly payment should be ~42,944 for 8M at 5%/30y")
    }

    @Test func zeroInterestRate() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 3_600_000
        vm.ownCapitalPct = 0  // slider min is 5, but test edge
        vm.mortgageYears = 30
        vm.interestRate = 0.0
        vm.includeReconstruction = false
        vm.ownCapitalPct = 10

        // Mortgage = 3,240,000, 0% rate, 30y → 3,240,000 / 360 = 9,000
        let mp = vm.monthlyPayment
        #expect(abs(mp - 9_000) < 1, "Zero interest: payment = principal / months")
    }

    @Test func shortMortgage() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000
        vm.ownCapitalPct = 50
        vm.mortgageYears = 5
        vm.interestRate = 4.0
        vm.includeReconstruction = false

        let mp = vm.monthlyPayment
        // 2.5M at 4%, 5y → ~46,063
        #expect(mp > 45_000 && mp < 47_000)
    }

    @Test func reconstructionIncreasesPayment() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.ownCapitalPct = 10
        vm.mortgageYears = 20
        vm.interestRate = 5.0

        vm.includeReconstruction = false
        let paymentWithout = vm.monthlyPayment

        vm.includeReconstruction = true
        vm.reconstructionAmount = 1_000_000
        let paymentWith = vm.monthlyPayment

        #expect(paymentWith > paymentWithout, "Reconstruction should increase monthly payment")
    }
}

// MARK: - Down Payment & Mortgage Amount

struct MortgageAmountTests {

    @Test func basicMortgageAmount() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.ownCapitalPct = 20
        vm.includeReconstruction = false

        #expect(vm.mortgageAmount == 8_000_000)
        #expect(vm.downPayment == 2_000_000)
    }

    @Test func reconstructionAffectsBoth() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.ownCapitalPct = 10
        vm.includeReconstruction = true
        vm.reconstructionAmount = 1_000_000

        // totalPropertyCost = 11M, 10% down = 1.1M, mortgage = 9.9M
        #expect(vm.totalPropertyCost == 11_000_000)
        #expect(abs(vm.downPayment - 1_100_000) < 1)
        #expect(abs(vm.mortgageAmount - 9_900_000) < 1)
    }

    @Test func maxOwnCapital() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.ownCapitalPct = 50
        vm.includeReconstruction = false

        #expect(vm.mortgageAmount == 5_000_000)
        #expect(vm.downPayment == 5_000_000)
    }
}

// MARK: - Schedule / Amortization

struct ScheduleTests {

    @Test func scheduleLength() {
        let vm = MortgageViewModel()
        vm.mortgageYears = 25
        vm.includeTax = false

        #expect(vm.schedule.count == 25)
    }

    @Test func balanceReachesZero() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000
        vm.ownCapitalPct = 20
        vm.mortgageYears = 20
        vm.interestRate = 5.0
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        let last = vm.schedule.last!
        #expect(abs(last.remainingBalance) < 1, "Balance should be ~0 at end of mortgage")
    }

    @Test func principalPlusInterestEqualsPayment() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000
        vm.ownCapitalPct = 20
        vm.mortgageYears = 10
        vm.interestRate = 4.0
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        for d in vm.schedule where d.annualPayment > 0 {
            let diff = abs(d.annualPayment - d.interestPaid - d.principalPaid)
            #expect(diff < 1, "Year \(d.year): payment should equal interest + principal")
        }
    }

    @Test func cumulativeInterestMonotonicallyIncreases() {
        let vm = MortgageViewModel()
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        var prev = 0.0
        for d in vm.schedule {
            #expect(d.cumulativeInterest >= prev)
            prev = d.cumulativeInterest
        }
    }

    @Test func remainingBalanceMonotonicallyDecreases() {
        let vm = MortgageViewModel()
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        var prev = vm.mortgageAmount + 1
        for d in vm.schedule {
            #expect(d.remainingBalance <= prev, "Year \(d.year): balance should not increase")
            prev = d.remainingBalance
        }
    }

    @Test func totalPrincipalPaidEqualsMortgage() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 8_000_000
        vm.ownCapitalPct = 10
        vm.mortgageYears = 20
        vm.interestRate = 5.0
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        let totalPrincipal = vm.schedule.reduce(0) { $0 + $1.principalPaid }
        let totalExtra = vm.schedule.reduce(0) { $0 + $1.extraPayment }
        let diff = abs(totalPrincipal + totalExtra - vm.mortgageAmount)
        #expect(diff < 1, "Total principal + extra should equal mortgage amount")
    }
}

// MARK: - Rental Income

struct RentalIncomeTests {

    @Test func rentGrowsGeometrically() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 20_000
        vm.rentGrowthPct = 3.0
        vm.vacancyMonths = 0
        vm.mortgageYears = 5
        vm.includeTax = false

        let schedule = vm.schedule
        let year1 = schedule[0].rentalIncome
        let year5 = schedule[4].rentalIncome

        #expect(abs(year1 - 240_000) < 1)
        let expected5 = 240_000 * testPow(1.03, 4)
        #expect(abs(year5 - expected5) < 1)
    }

    @Test func vacancyReducesRent() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 30_000
        vm.rentGrowthPct = 0
        vm.mortgageYears = 5
        vm.includeTax = false

        vm.vacancyMonths = 0
        let fullRent = vm.schedule[0].rentalIncome

        vm.vacancyMonths = 2
        let reducedRent = vm.schedule[0].rentalIncome

        #expect(abs(fullRent - 360_000) < 1)
        #expect(abs(reducedRent - 300_000) < 1)
    }
}

// MARK: - Tax Computation

struct TaxTests {

    @Test func pausalniFlatRate() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 30_000
        vm.vacancyMonths = 0
        vm.rentGrowthPct = 0
        vm.mortgageYears = 5
        vm.includeTax = true
        vm.taxMode = .pausalni
        vm.taxRate = 15

        // Year 1: rent = 360,000, base = 70% = 252,000, tax = 15% = 37,800
        let tax1 = vm.schedule[0].taxAmount
        #expect(abs(tax1 - 37_800) < 1)
    }

    @Test func skutecneCostsDeductAll() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000
        vm.ownCapitalPct = 20
        vm.mortgageYears = 20
        vm.interestRate = 5.0
        vm.monthlyRent = 30_000
        vm.vacancyMonths = 0
        vm.rentGrowthPct = 0
        vm.includeTax = true
        vm.taxMode = .skutecne
        vm.taxRate = 15
        vm.annualRepairs = 50_000
        vm.annualInsurance = 10_000
        vm.monthlySVJ = 2_000
        vm.includeManagement = true
        vm.managementFeePct = 10

        let d = vm.schedule[0]
        let rent = d.rentalIncome
        let deductible = d.interestPaid + d.repairCost + d.managementFee + d.insuranceCost + d.svjCost
        let expectedBase = max(0, rent - deductible)
        let expectedTax = expectedBase * 0.15
        #expect(abs(d.taxAmount - expectedTax) < 1)
    }

    @Test func taxDisabledReturnsZero() {
        let vm = MortgageViewModel()
        vm.includeTax = false

        for d in vm.schedule {
            #expect(d.taxAmount == 0)
        }
    }
}

// MARK: - Refixation

struct RefixationTests {

    @Test func refixChangesPayment() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.ownCapitalPct = 20
        vm.mortgageYears = 20
        vm.interestRate = 4.0
        vm.useRefixation = true
        vm.refixYear = 5
        vm.refixRate = 6.0
        vm.includeTax = false

        let preRefix = vm.schedule[4]  // year 5
        let postRefix = vm.schedule[5] // year 6

        // After refixation to higher rate, interest portion should increase
        let interestRatioBefore = preRefix.interestPaid / preRefix.annualPayment
        let interestRatioAfter = postRefix.interestPaid / postRefix.annualPayment
        #expect(interestRatioAfter > interestRatioBefore,
                "Higher refix rate should increase interest ratio")
    }

    @Test func refixYearIsMarked() {
        let vm = MortgageViewModel()
        vm.useRefixation = true
        vm.refixYear = 5
        vm.mortgageYears = 20
        vm.includeTax = false

        let year6 = vm.schedule[5]
        #expect(year6.isRefixYear == true)

        let year5 = vm.schedule[4]
        #expect(year5.isRefixYear == false)
    }
}

// MARK: - Extra Payments

struct ExtraPaymentTests {

    @Test func extraPaymentReducesBalance() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.ownCapitalPct = 20
        vm.mortgageYears = 20
        vm.interestRate = 5.0
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        let balanceWithout = vm.schedule[4].remainingBalance

        vm.extraPayments = [ExtraPayment(year: 3, amount: 1_000_000)]
        let balanceWith = vm.schedule[4].remainingBalance

        #expect(balanceWith < balanceWithout, "Extra payment should reduce remaining balance")
    }

    @Test func extraPaymentCappedAtBalance() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 2_000_000
        vm.ownCapitalPct = 10
        vm.mortgageYears = 10
        vm.interestRate = 3.0
        vm.includeTax = false
        vm.useRentAsExtraPayments = false
        vm.extraPayments = [ExtraPayment(year: 1, amount: 5_000_000)] // way more than balance

        for d in vm.schedule {
            #expect(d.remainingBalance >= 0, "Balance should never go negative")
        }
    }

    @Test func autoExtraPaymentsReactToRentChange() {
        let vm = MortgageViewModel()
        vm.useRentAsExtraPayments = true
        vm.monthlyRent = 20_000
        vm.vacancyMonths = 0
        let payments20k = vm.autoExtraPayments

        vm.monthlyRent = 40_000
        let payments40k = vm.autoExtraPayments

        #expect(!payments20k.isEmpty)
        #expect(!payments40k.isEmpty)
        #expect(payments40k[0].amount > payments20k[0].amount,
                "Higher rent should produce higher auto payments")
    }

    @Test func autoExtraPaymentsStopAtPayoff() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 3_000_000
        vm.ownCapitalPct = 10
        vm.mortgageYears = 30
        vm.interestRate = 4.0
        vm.monthlyRent = 50_000
        vm.vacancyMonths = 0
        vm.useRentAsExtraPayments = true

        let autoPayments = vm.autoExtraPayments
        let lastAutoYear = autoPayments.last?.year ?? 0
        #expect(lastAutoYear < 30, "With high rent, mortgage should be paid off early")
    }

    @Test func autoExtraPaymentsGrowWithRent() {
        let vm = MortgageViewModel()
        vm.useRentAsExtraPayments = true
        vm.monthlyRent = 25_000
        vm.vacancyMonths = 0
        vm.rentGrowthPct = 5.0

        let payments = vm.autoExtraPayments
        guard payments.count >= 3 else { return }

        #expect(payments[1].amount > payments[0].amount,
                "Auto payments should grow with rent growth")
        #expect(payments[2].amount > payments[1].amount)
    }
}

// MARK: - Operating Costs

struct OperatingCostsTests {

    @Test func operatingCostsReduceNetResult() {
        let vm = MortgageViewModel()
        vm.includeTax = false
        vm.annualInsurance = 0
        vm.monthlySVJ = 0
        vm.includeManagement = false

        let netWithout = vm.schedule[0].netYear

        vm.annualInsurance = 10_000
        vm.monthlySVJ = 3_000
        vm.includeManagement = true
        vm.managementFeePct = 10

        let netWith = vm.schedule[0].netYear
        #expect(netWith < netWithout, "Operating costs should reduce net result")
    }

    @Test func managementFeeIsPercentOfRent() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 30_000
        vm.vacancyMonths = 0
        vm.rentGrowthPct = 0
        vm.includeManagement = true
        vm.managementFeePct = 10
        vm.includeTax = false

        let d = vm.schedule[0]
        let expectedFee = d.rentalIncome * 0.10
        #expect(abs(d.managementFee - expectedFee) < 1)
    }

    @Test func managementDisabledIsZero() {
        let vm = MortgageViewModel()
        vm.includeManagement = false

        #expect(vm.schedule[0].managementFee == 0)
    }
}

// MARK: - Property Appreciation

struct AppreciationTests {

    @Test func appreciationIncreasesPropertyValue() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.includeAppreciation = true
        vm.propertyAppreciationPct = 3.0
        vm.mortgageYears = 10

        let year10 = vm.schedule[9]
        let expected = 10_000_000 * testPow(1.03, 10)
        #expect(abs(year10.propertyValue - expected) < 1)
    }

    @Test func noAppreciationKeepsOriginalPrice() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000
        vm.includeAppreciation = false
        vm.mortgageYears = 10

        let year10 = vm.schedule[9]
        #expect(year10.propertyValue == 10_000_000)
    }

    @Test func totalInvestmentIncludesAppreciation() {
        let vm = MortgageViewModel()
        vm.includeAppreciation = true
        vm.propertyAppreciationPct = 5.0

        let total = vm.finalTotalInvestment
        let netOnly = vm.finalBalance
        #expect(total > netOnly, "Total investment should exceed net result due to property value")
    }
}

// MARK: - Snapshot

struct SnapshotTests {

    @Test func snapshotAtYear1() {
        let vm = MortgageViewModel()
        vm.selectedYear = 1
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        #expect(vm.snapYear == 1)
        #expect(vm.snapCumPayments > 0)
        #expect(vm.snapCumInterest > 0)
        #expect(vm.snapRemainingDebt > 0)
        #expect(vm.snapRemainingDebt < vm.mortgageAmount)
    }

    @Test func snapshotNetStartsNegative() {
        let vm = MortgageViewModel()
        vm.selectedYear = 1
        vm.useRentAsExtraPayments = false

        #expect(vm.snapNet < 0, "Net result should be negative at year 1 (includes -downPayment)")
    }

    @Test func opportunityCostGrows() {
        let vm = MortgageViewModel()
        vm.includeOpportunityCost = true
        vm.alternativeReturnPct = 7.0

        vm.selectedYear = 5
        let cost5 = vm.snapOpportunityCost

        vm.selectedYear = 20
        let cost20 = vm.snapOpportunityCost

        #expect(cost20 > cost5, "Opportunity cost should grow over time")
    }

    @Test func inflationDiscountReducesValue() {
        let vm = MortgageViewModel()
        vm.includeInflation = true
        vm.inflationRate = 3.0
        vm.selectedYear = 20

        #expect(abs(vm.snapNetReal) < abs(vm.snapNet),
                "Inflation-discounted value should be smaller in absolute terms")
    }
}

// MARK: - Edge Cases

struct EdgeCaseTests {

    @Test func minimumValues() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 1_000_000
        vm.ownCapitalPct = 5
        vm.mortgageYears = 5
        vm.interestRate = 0.5
        vm.monthlyRent = 10_000
        vm.includeTax = false

        let schedule = vm.schedule
        #expect(schedule.count == 5)
        #expect(schedule.last!.remainingBalance >= 0)
    }

    @Test func maximumValues() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 30_000_000
        vm.ownCapitalPct = 50
        vm.mortgageYears = 30
        vm.interestRate = 10.0
        vm.monthlyRent = 80_000
        vm.includeTax = true

        let schedule = vm.schedule
        #expect(schedule.count == 30)
        #expect(schedule.last!.remainingBalance >= 0)
    }

    @Test func allFeaturesEnabled() {
        let vm = MortgageViewModel()
        vm.includeReconstruction = true
        vm.reconstructionAmount = 1_000_000
        vm.includeAppreciation = true
        vm.propertyAppreciationPct = 3.0
        vm.useRefixation = true
        vm.refixYear = 5
        vm.refixRate = 6.0
        vm.vacancyMonths = 2
        vm.includeManagement = true
        vm.managementFeePct = 10
        vm.annualInsurance = 15_000
        vm.monthlySVJ = 5_000
        vm.includeTax = true
        vm.taxMode = .skutecne
        vm.includeOpportunityCost = true
        vm.includeInflation = true
        vm.useRentAsExtraPayments = true
        vm.extraPayments = [ExtraPayment(year: 1, amount: 500_000)]

        let schedule = vm.schedule
        #expect(!schedule.isEmpty)
        for d in schedule {
            #expect(d.remainingBalance >= 0)
            #expect(d.propertyValue > 0)
            #expect(d.rentalIncome >= 0)
        }
    }

    @Test func noRentScenario() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 10_000  // minimum
        vm.vacancyMonths = 0
        vm.includeTax = false

        let schedule = vm.schedule
        #expect(!schedule.isEmpty)
        // Net should be very negative (paying mortgage, low rent)
        #expect(vm.finalBalance < 0)
    }

    @Test func largeRepairYears() {
        let vm = MortgageViewModel()
        vm.largeRepairEveryNYears = 5
        vm.largeRepairAmount = 500_000
        vm.mortgageYears = 20

        let repairYears = vm.schedule.filter { $0.isLargeRepairYear }
        #expect(repairYears.count == 4) // years 5, 10, 15, 20
        #expect(repairYears[0].year == 5)
    }
}

// MARK: - Financial Precision

struct PrecisionTests {

    @Test func annuityFormulaMatchesKnownValue() {
        // Known: 1,000,000 CZK at 6% for 20 years = 7,164.31 CZK/month
        let vm = MortgageViewModel()
        vm.propertyPrice = 1_000_000
        vm.ownCapitalPct = 0
        vm.mortgageYears = 20
        vm.interestRate = 6.0
        vm.includeReconstruction = false

        // ownCapitalPct min is 5 in UI, but we test formula directly
        vm.ownCapitalPct = 0
        let mp = vm.monthlyPayment
        #expect(abs(mp - 7164.31) < 1, "Annuity should match known value: got \(mp)")
    }

    @Test func totalPaymentsExceedMortgage() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000
        vm.ownCapitalPct = 20
        vm.mortgageYears = 20
        vm.interestRate = 5.0
        vm.includeTax = false
        vm.useRentAsExtraPayments = false

        let totalPayments = vm.schedule.reduce(0) { $0 + $1.annualPayment }
        #expect(totalPayments > vm.mortgageAmount,
                "Total payments should exceed mortgage due to interest")
    }

    @Test func interestDeclinesPrincipalIncreases() {
        let vm = MortgageViewModel()
        vm.mortgageYears = 20
        vm.interestRate = 5.0
        vm.includeTax = false
        vm.useRentAsExtraPayments = false
        vm.useRefixation = false

        let first = vm.schedule[0]
        let last = vm.schedule.last(where: { $0.annualPayment > 0 })!

        #expect(first.interestPaid > last.interestPaid,
                "Interest should be higher in early years")
        #expect(first.principalPaid < last.principalPaid,
                "Principal should be higher in later years")
    }
}

// MARK: - CalculationEngine Direct Tests

struct EngineDirectTests {

    @Test func engineMonthlyPayment() {
        // 1M at 6% for 20 years = 7,164.31
        let mp = CalculationEngine.monthlyPayment(principal: 1_000_000,
                                                   annualRate: 6.0,
                                                   years: 20)
        #expect(abs(mp - 7164.31) < 1)
    }

    @Test func engineZeroRate() {
        let mp = CalculationEngine.monthlyPayment(principal: 1_200_000,
                                                   annualRate: 0,
                                                   years: 10)
        #expect(abs(mp - 10_000) < 1)
    }

    @Test func engineTaxPausalni() {
        let tax = CalculationEngine.computeTax(
            rent: 360_000, interest: 0, repairs: 0,
            management: 0, insurance: 0, svj: 0,
            includeTax: true, taxMode: .pausalni, taxRate: 15
        )
        // base = 252,000, tax = 37,800
        #expect(abs(tax - 37_800) < 1)
    }

    @Test func engineTaxSkutecne() {
        let tax = CalculationEngine.computeTax(
            rent: 360_000, interest: 100_000, repairs: 50_000,
            management: 20_000, insurance: 10_000, svj: 36_000,
            includeTax: true, taxMode: .skutecne, taxRate: 15
        )
        // base = max(0, 360k - 100k - 50k - 20k - 10k - 36k) = 144,000
        // tax = 144,000 * 0.15 = 21,600
        #expect(abs(tax - 21_600) < 1)
    }

    @Test func engineTaxDisabled() {
        let tax = CalculationEngine.computeTax(
            rent: 360_000, interest: 0, repairs: 0,
            management: 0, insurance: 0, svj: 0,
            includeTax: false, taxMode: .pausalni, taxRate: 15
        )
        #expect(tax == 0)
    }

    @Test func engineScheduleWithDefaults() {
        let inputs = MortgageInputs()
        let auto = CalculationEngine.autoExtraPayments(inputs)
        let all = inputs.extraPayments + auto
        let schedule = CalculationEngine.computeSchedule(inputs, allExtraPayments: all)

        #expect(schedule.count == 30)
        #expect(schedule.last!.remainingBalance >= 0)
    }

    @Test func engineAutoPaymentsEmpty() {
        var inputs = MortgageInputs()
        inputs.useRentAsExtraPayments = false
        let auto = CalculationEngine.autoExtraPayments(inputs)
        #expect(auto.isEmpty)
    }

    @Test func engineAutoPaymentsGenerated() {
        var inputs = MortgageInputs()
        inputs.useRentAsExtraPayments = true
        let auto = CalculationEngine.autoExtraPayments(inputs)
        #expect(!auto.isEmpty)
        #expect(auto.allSatisfy { $0.autoGenerated })
    }

    @Test func mortgageInputsDerived() {
        var inputs = MortgageInputs()
        inputs.propertyPrice = 10_000_000
        inputs.ownCapitalPct = 20
        inputs.includeReconstruction = true
        inputs.reconstructionAmount = 500_000

        #expect(inputs.totalPropertyCost == 10_500_000)
        #expect(abs(inputs.downPayment - 2_100_000) < 1)
        #expect(abs(inputs.mortgageAmount - 8_400_000) < 1)
    }
}
