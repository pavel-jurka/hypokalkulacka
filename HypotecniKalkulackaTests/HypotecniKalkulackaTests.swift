/// Unit testy pro výpočetní logiku hypoteční kalkulačky.
/// XCTest framework — kompatibilní se všemi verzemi Xcode.

import XCTest
@testable import HypotecniKalkulacka

// MARK: - Annuity Formula

final class AnnuityTests: XCTestCase {

    func testStandardAnnuity() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.ownCapitalPct = 20
        vm.mortgageYears = 30; vm.interestRate = 5.0; vm.includeReconstruction = false
        XCTAssertEqual(vm.monthlyPayment, 42_944, accuracy: 1000)
    }

    func testZeroInterestRate() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 3_600_000; vm.ownCapitalPct = 10
        vm.mortgageYears = 30; vm.interestRate = 0.0; vm.includeReconstruction = false
        XCTAssertEqual(vm.monthlyPayment, 9_000, accuracy: 1)
    }

    func testShortMortgage() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000; vm.ownCapitalPct = 50
        vm.mortgageYears = 5; vm.interestRate = 4.0; vm.includeReconstruction = false
        XCTAssertEqual(vm.monthlyPayment, 46_063, accuracy: 1000)
    }

    func testReconstructionIncreasesPayment() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.ownCapitalPct = 10
        vm.mortgageYears = 20; vm.interestRate = 5.0
        vm.includeReconstruction = false
        let without = vm.monthlyPayment
        vm.includeReconstruction = true; vm.reconstructionAmount = 1_000_000
        XCTAssertGreaterThan(vm.monthlyPayment, without)
    }
}

// MARK: - Down Payment & Mortgage Amount

final class MortgageAmountTests: XCTestCase {

    func testBasicMortgageAmount() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.ownCapitalPct = 20; vm.includeReconstruction = false
        XCTAssertEqual(vm.mortgageAmount, 8_000_000)
        XCTAssertEqual(vm.downPayment, 2_000_000)
    }

    func testReconstructionAffectsBoth() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.ownCapitalPct = 10
        vm.includeReconstruction = true; vm.reconstructionAmount = 1_000_000
        XCTAssertEqual(vm.totalPropertyCost, 11_000_000)
        XCTAssertEqual(vm.downPayment, 1_100_000, accuracy: 1)
        XCTAssertEqual(vm.mortgageAmount, 9_900_000, accuracy: 1)
    }
}

// MARK: - Schedule / Amortization

final class ScheduleTests: XCTestCase {

    func testScheduleLength() {
        let vm = MortgageViewModel()
        vm.mortgageYears = 25; vm.includeTax = false
        XCTAssertEqual(vm.schedule.count, 25)
    }

    func testBalanceReachesZero() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000; vm.ownCapitalPct = 20
        vm.mortgageYears = 20; vm.interestRate = 5.0
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        XCTAssertEqual(vm.schedule.last!.remainingBalance, 0, accuracy: 1)
    }

    func testPrincipalPlusInterestEqualsPayment() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000; vm.ownCapitalPct = 20
        vm.mortgageYears = 10; vm.interestRate = 4.0
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        for d in vm.schedule where d.annualPayment > 0 {
            XCTAssertEqual(d.annualPayment, d.interestPaid + d.principalPaid, accuracy: 1,
                           "Year \(d.year)")
        }
    }

    func testCumulativeInterestMonotonicallyIncreases() {
        let vm = MortgageViewModel()
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        var prev = 0.0
        for d in vm.schedule {
            XCTAssertGreaterThanOrEqual(d.cumulativeInterest, prev)
            prev = d.cumulativeInterest
        }
    }

    func testRemainingBalanceMonotonicallyDecreases() {
        let vm = MortgageViewModel()
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        var prev = vm.mortgageAmount + 1
        for d in vm.schedule {
            XCTAssertLessThanOrEqual(d.remainingBalance, prev, "Year \(d.year)")
            prev = d.remainingBalance
        }
    }

    func testTotalPrincipalPaidEqualsMortgage() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 8_000_000; vm.ownCapitalPct = 10
        vm.mortgageYears = 20; vm.interestRate = 5.0
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        let totalPrincipal = vm.schedule.reduce(0) { $0 + $1.principalPaid }
        let totalExtra = vm.schedule.reduce(0) { $0 + $1.extraPayment }
        XCTAssertEqual(totalPrincipal + totalExtra, vm.mortgageAmount, accuracy: 1)
    }
}

// MARK: - Rental Income

final class RentalIncomeTests: XCTestCase {

    func testRentGrowsGeometrically() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 20_000; vm.rentGrowthPct = 3.0
        vm.vacancyMonths = 0; vm.mortgageYears = 5; vm.includeTax = false
        XCTAssertEqual(vm.schedule[0].rentalIncome, 240_000, accuracy: 1)
        let expected5 = 240_000 * Darwin.pow(1.03, 4)
        XCTAssertEqual(vm.schedule[4].rentalIncome, expected5, accuracy: 1)
    }

    func testVacancyReducesRent() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 30_000; vm.rentGrowthPct = 0
        vm.mortgageYears = 5; vm.includeTax = false
        vm.vacancyMonths = 0
        XCTAssertEqual(vm.schedule[0].rentalIncome, 360_000, accuracy: 1)
        vm.vacancyMonths = 2
        XCTAssertEqual(vm.schedule[0].rentalIncome, 300_000, accuracy: 1)
    }
}

// MARK: - Tax Computation

final class TaxTests: XCTestCase {

    func testPausalniFlatRate() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 30_000; vm.vacancyMonths = 0; vm.rentGrowthPct = 0
        vm.mortgageYears = 5; vm.includeTax = true
        vm.taxMode = .pausalni; vm.taxRate = 15
        XCTAssertEqual(vm.schedule[0].taxAmount, 37_800, accuracy: 1)
    }

    func testSkutecneCostsDeductAll() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000; vm.ownCapitalPct = 20
        vm.mortgageYears = 20; vm.interestRate = 5.0
        vm.monthlyRent = 30_000; vm.vacancyMonths = 0; vm.rentGrowthPct = 0
        vm.includeTax = true; vm.taxMode = .skutecne; vm.taxRate = 15
        vm.annualRepairs = 50_000; vm.annualInsurance = 10_000
        vm.monthlySVJ = 2_000; vm.includeManagement = true; vm.managementFeePct = 10
        let d = vm.schedule[0]
        let deductible = d.interestPaid + d.repairCost + d.managementFee + d.insuranceCost + d.svjCost
        let expectedTax = max(0, d.rentalIncome - deductible) * 0.15
        XCTAssertEqual(d.taxAmount, expectedTax, accuracy: 1)
    }

    func testTaxDisabledReturnsZero() {
        let vm = MortgageViewModel(); vm.includeTax = false
        for d in vm.schedule { XCTAssertEqual(d.taxAmount, 0) }
    }
}

// MARK: - Refixation

final class RefixationTests: XCTestCase {

    func testRefixChangesPayment() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.ownCapitalPct = 20
        vm.mortgageYears = 20; vm.interestRate = 4.0
        vm.useRefixation = true; vm.refixYear = 5; vm.refixRate = 6.0; vm.includeTax = false
        let ratioBefore = vm.schedule[4].interestPaid / vm.schedule[4].annualPayment
        let ratioAfter = vm.schedule[5].interestPaid / vm.schedule[5].annualPayment
        XCTAssertGreaterThan(ratioAfter, ratioBefore)
    }

    func testRefixYearIsMarked() {
        let vm = MortgageViewModel()
        vm.useRefixation = true; vm.refixYear = 5; vm.mortgageYears = 20; vm.includeTax = false
        XCTAssertTrue(vm.schedule[5].isRefixYear)
        XCTAssertFalse(vm.schedule[4].isRefixYear)
    }
}

// MARK: - Extra Payments

final class ExtraPaymentTests: XCTestCase {

    func testExtraPaymentReducesBalance() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.ownCapitalPct = 20
        vm.mortgageYears = 20; vm.interestRate = 5.0
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        let without = vm.schedule[4].remainingBalance
        vm.extraPayments = [ExtraPayment(year: 3, amount: 1_000_000)]
        XCTAssertLessThan(vm.schedule[4].remainingBalance, without)
    }

    func testExtraPaymentCappedAtBalance() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 2_000_000; vm.ownCapitalPct = 10
        vm.mortgageYears = 10; vm.interestRate = 3.0
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        vm.extraPayments = [ExtraPayment(year: 1, amount: 5_000_000)]
        for d in vm.schedule { XCTAssertGreaterThanOrEqual(d.remainingBalance, 0) }
    }

    func testAutoExtraPaymentsReactToRentChange() {
        let vm = MortgageViewModel()
        vm.useRentAsExtraPayments = true; vm.vacancyMonths = 0
        vm.monthlyRent = 20_000
        let low = vm.autoExtraPayments
        vm.monthlyRent = 40_000
        let high = vm.autoExtraPayments
        XCTAssertFalse(low.isEmpty); XCTAssertFalse(high.isEmpty)
        XCTAssertGreaterThan(high[0].amount, low[0].amount)
    }

    func testAutoExtraPaymentsStopAtPayoff() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 3_000_000; vm.ownCapitalPct = 10
        vm.mortgageYears = 30; vm.interestRate = 4.0
        vm.monthlyRent = 50_000; vm.vacancyMonths = 0; vm.useRentAsExtraPayments = true
        XCTAssertLessThan(vm.autoExtraPayments.last!.year, 30)
    }

    func testAutoExtraPaymentsGrowWithRent() {
        let vm = MortgageViewModel()
        vm.useRentAsExtraPayments = true; vm.monthlyRent = 25_000
        vm.vacancyMonths = 0; vm.rentGrowthPct = 5.0
        let p = vm.autoExtraPayments
        guard p.count >= 3 else { return }
        XCTAssertGreaterThan(p[1].amount, p[0].amount)
        XCTAssertGreaterThan(p[2].amount, p[1].amount)
    }
}

// MARK: - Operating Costs

final class OperatingCostsTests: XCTestCase {

    func testOperatingCostsReduceNetResult() {
        let vm = MortgageViewModel()
        vm.includeTax = false; vm.annualInsurance = 0; vm.monthlySVJ = 0; vm.includeManagement = false
        let without = vm.schedule[0].netYear
        vm.annualInsurance = 10_000; vm.monthlySVJ = 3_000
        vm.includeManagement = true; vm.managementFeePct = 10
        XCTAssertLessThan(vm.schedule[0].netYear, without)
    }

    func testManagementFeeIsPercentOfRent() {
        let vm = MortgageViewModel()
        vm.monthlyRent = 30_000; vm.vacancyMonths = 0; vm.rentGrowthPct = 0
        vm.includeManagement = true; vm.managementFeePct = 10; vm.includeTax = false
        XCTAssertEqual(vm.schedule[0].managementFee, vm.schedule[0].rentalIncome * 0.10, accuracy: 1)
    }

    func testManagementDisabledIsZero() {
        let vm = MortgageViewModel(); vm.includeManagement = false
        XCTAssertEqual(vm.schedule[0].managementFee, 0)
    }
}

// MARK: - Property Appreciation

final class AppreciationTests: XCTestCase {

    func testAppreciationIncreasesPropertyValue() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.includeAppreciation = true
        vm.propertyAppreciationPct = 3.0; vm.mortgageYears = 10
        let expected = 10_000_000 * Darwin.pow(1.03, 10)
        XCTAssertEqual(vm.schedule[9].propertyValue, expected, accuracy: 1)
    }

    func testNoAppreciationKeepsOriginalPrice() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 10_000_000; vm.includeAppreciation = false; vm.mortgageYears = 10
        XCTAssertEqual(vm.schedule[9].propertyValue, 10_000_000)
    }

    func testTotalInvestmentIncludesAppreciation() {
        let vm = MortgageViewModel()
        vm.includeAppreciation = true; vm.propertyAppreciationPct = 5.0
        XCTAssertGreaterThan(vm.finalTotalInvestment, vm.finalBalance)
    }
}

// MARK: - Snapshot

final class SnapshotTests: XCTestCase {

    func testSnapshotAtYear1() {
        let vm = MortgageViewModel()
        vm.selectedYear = 1; vm.includeTax = false; vm.useRentAsExtraPayments = false
        XCTAssertEqual(vm.snapYear, 1)
        XCTAssertGreaterThan(vm.snapCumPayments, 0)
        XCTAssertGreaterThan(vm.snapCumInterest, 0)
        XCTAssertLessThan(vm.snapRemainingDebt, vm.mortgageAmount)
    }

    func testSnapshotNetStartsNegative() {
        let vm = MortgageViewModel()
        vm.selectedYear = 1; vm.useRentAsExtraPayments = false
        XCTAssertLessThan(vm.snapNet, 0)
    }

    func testOpportunityCostGrows() {
        let vm = MortgageViewModel()
        vm.includeOpportunityCost = true; vm.alternativeReturnPct = 7.0
        vm.selectedYear = 5; let cost5 = vm.snapOpportunityCost
        vm.selectedYear = 20; let cost20 = vm.snapOpportunityCost
        XCTAssertGreaterThan(cost20, cost5)
    }

    func testInflationDiscountReducesValue() {
        let vm = MortgageViewModel()
        vm.includeInflation = true; vm.inflationRate = 3.0; vm.selectedYear = 20
        XCTAssertLessThan(abs(vm.snapNetReal), abs(vm.snapNet))
    }
}

// MARK: - Edge Cases

final class EdgeCaseTests: XCTestCase {

    func testMinimumValues() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 1_000_000; vm.ownCapitalPct = 5
        vm.mortgageYears = 5; vm.interestRate = 0.5
        vm.monthlyRent = 10_000; vm.includeTax = false
        XCTAssertEqual(vm.schedule.count, 5)
        XCTAssertGreaterThanOrEqual(vm.schedule.last!.remainingBalance, 0)
    }

    func testMaximumValues() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 30_000_000; vm.ownCapitalPct = 50
        vm.mortgageYears = 30; vm.interestRate = 10.0
        vm.monthlyRent = 80_000; vm.includeTax = true
        XCTAssertEqual(vm.schedule.count, 30)
        XCTAssertGreaterThanOrEqual(vm.schedule.last!.remainingBalance, 0)
    }

    func testAllFeaturesEnabled() {
        let vm = MortgageViewModel()
        vm.includeReconstruction = true; vm.reconstructionAmount = 1_000_000
        vm.includeAppreciation = true; vm.propertyAppreciationPct = 3.0
        vm.useRefixation = true; vm.refixYear = 5; vm.refixRate = 6.0
        vm.vacancyMonths = 2; vm.includeManagement = true; vm.managementFeePct = 10
        vm.annualInsurance = 15_000; vm.monthlySVJ = 5_000
        vm.includeTax = true; vm.taxMode = .skutecne
        vm.includeOpportunityCost = true; vm.includeInflation = true
        vm.useRentAsExtraPayments = true
        vm.extraPayments = [ExtraPayment(year: 1, amount: 500_000)]
        XCTAssertFalse(vm.schedule.isEmpty)
        for d in vm.schedule {
            XCTAssertGreaterThanOrEqual(d.remainingBalance, 0)
            XCTAssertGreaterThan(d.propertyValue, 0)
        }
    }

    func testLargeRepairYears() {
        let vm = MortgageViewModel()
        vm.largeRepairEveryNYears = 5; vm.largeRepairAmount = 500_000; vm.mortgageYears = 20
        let repairYears = vm.schedule.filter { $0.isLargeRepairYear }
        XCTAssertEqual(repairYears.count, 4)
        XCTAssertEqual(repairYears[0].year, 5)
    }
}

// MARK: - Financial Precision

final class PrecisionTests: XCTestCase {

    func testAnnuityFormulaMatchesKnownValue() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 1_000_000; vm.ownCapitalPct = 0
        vm.mortgageYears = 20; vm.interestRate = 6.0; vm.includeReconstruction = false
        XCTAssertEqual(vm.monthlyPayment, 7164.31, accuracy: 1)
    }

    func testTotalPaymentsExceedMortgage() {
        let vm = MortgageViewModel()
        vm.propertyPrice = 5_000_000; vm.ownCapitalPct = 20
        vm.mortgageYears = 20; vm.interestRate = 5.0
        vm.includeTax = false; vm.useRentAsExtraPayments = false
        let total = vm.schedule.reduce(0) { $0 + $1.annualPayment }
        XCTAssertGreaterThan(total, vm.mortgageAmount)
    }

    func testInterestDeclinesPrincipalIncreases() {
        let vm = MortgageViewModel()
        vm.mortgageYears = 20; vm.interestRate = 5.0
        vm.includeTax = false; vm.useRentAsExtraPayments = false; vm.useRefixation = false
        let first = vm.schedule[0]
        let last = vm.schedule.last(where: { $0.annualPayment > 0 })!
        XCTAssertGreaterThan(first.interestPaid, last.interestPaid)
        XCTAssertLessThan(first.principalPaid, last.principalPaid)
    }
}

// MARK: - CalculationEngine Direct Tests

final class EngineDirectTests: XCTestCase {

    func testEngineMonthlyPayment() {
        let mp = CalculationEngine.monthlyPayment(principal: 1_000_000, annualRate: 6.0, years: 20)
        XCTAssertEqual(mp, 7164.31, accuracy: 1)
    }

    func testEngineZeroRate() {
        let mp = CalculationEngine.monthlyPayment(principal: 1_200_000, annualRate: 0, years: 10)
        XCTAssertEqual(mp, 10_000, accuracy: 1)
    }

    func testEngineTaxPausalni() {
        let tax = CalculationEngine.computeTax(
            rent: 360_000, interest: 0, repairs: 0,
            management: 0, insurance: 0, svj: 0,
            includeTax: true, taxMode: .pausalni, taxRate: 15)
        XCTAssertEqual(tax, 37_800, accuracy: 1)
    }

    func testEngineTaxSkutecne() {
        let tax = CalculationEngine.computeTax(
            rent: 360_000, interest: 100_000, repairs: 50_000,
            management: 20_000, insurance: 10_000, svj: 36_000,
            includeTax: true, taxMode: .skutecne, taxRate: 15)
        XCTAssertEqual(tax, 21_600, accuracy: 1)
    }

    func testEngineTaxDisabled() {
        let tax = CalculationEngine.computeTax(
            rent: 360_000, interest: 0, repairs: 0,
            management: 0, insurance: 0, svj: 0,
            includeTax: false, taxMode: .pausalni, taxRate: 15)
        XCTAssertEqual(tax, 0)
    }

    func testEngineScheduleWithDefaults() {
        let inputs = MortgageInputs()
        let auto = CalculationEngine.autoExtraPayments(inputs)
        let schedule = CalculationEngine.computeSchedule(inputs, allExtraPayments: inputs.extraPayments + auto)
        XCTAssertEqual(schedule.count, 30)
        XCTAssertGreaterThanOrEqual(schedule.last!.remainingBalance, 0)
    }

    func testEngineAutoPaymentsEmpty() {
        var inputs = MortgageInputs(); inputs.useRentAsExtraPayments = false
        XCTAssertTrue(CalculationEngine.autoExtraPayments(inputs).isEmpty)
    }

    func testEngineAutoPaymentsGenerated() {
        var inputs = MortgageInputs(); inputs.useRentAsExtraPayments = true
        let auto = CalculationEngine.autoExtraPayments(inputs)
        XCTAssertFalse(auto.isEmpty)
        XCTAssertTrue(auto.allSatisfy { $0.autoGenerated })
    }

    func testMortgageInputsDerived() {
        var inputs = MortgageInputs()
        inputs.propertyPrice = 10_000_000; inputs.ownCapitalPct = 20
        inputs.includeReconstruction = true; inputs.reconstructionAmount = 500_000
        XCTAssertEqual(inputs.totalPropertyCost, 10_500_000)
        XCTAssertEqual(inputs.downPayment, 2_100_000, accuracy: 1)
        XCTAssertEqual(inputs.mortgageAmount, 8_400_000, accuracy: 1)
    }
}
