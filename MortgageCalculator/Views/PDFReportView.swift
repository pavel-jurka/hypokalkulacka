/// PDFReportView.swift — View renderovaný do PDF (šířka 1000 pt)

import SwiftUI
import Charts

struct PDFReportView: View {
    var vm: MortgageViewModel

    private var dateStr: String {
        let f = DateFormatter()
        f.dateStyle = .long; f.locale = Locale(identifier: "cs_CZ")
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Hlavička
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hypoteční kalkulačka").font(.title).fontWeight(.bold)
                    Text("Výsledky simulace · \(dateStr)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "house.fill").font(.largeTitle).foregroundStyle(.blue)
            }
            .padding(.bottom, 4)

            Divider()

            // Parametry
            Text("PARAMETRY").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                PDFParam("Cena nemovitosti", czk(vm.propertyPrice))
                PDFParam("Vlastní kapitál", String(format: "%.0f %% = %@", vm.ownCapitalPct, czk(vm.downPayment)))
                if vm.includeReconstruction {
                    PDFParam("Rekonstrukce", czk(vm.reconstructionAmount))
                }
                PDFParam("Hypotéka", czk(vm.mortgageAmount))
                PDFParam("Měsíční splátka", czk(vm.monthlyPayment))
                PDFParam("Úroková sazba", String(format: "%.2f %%", vm.interestRate))
                PDFParam("Délka hypotéky", "\(Int(vm.mortgageYears)) let")
                PDFParam("Měsíční nájem (rok 1)", czk(vm.monthlyRent))
                PDFParam("Růst nájmu", String(format: "%.2f %% / rok", vm.rentGrowthPct))
                if vm.vacancyMonths > 0 {
                    PDFParam("Neobsazenost", String(format: "%.1f měs. / rok", vm.vacancyMonths))
                }
                if vm.useRefixation {
                    PDFParam("Refixace po", "\(Int(vm.refixYear)) letech → \(String(format: "%.2f %%", vm.refixRate))")
                    PDFParam("Splátka po refixaci", czk(vm.monthlyPaymentAfterRefix))
                }
                if vm.includeAppreciation {
                    PDFParam("Zhodnocení nemovitosti", String(format: "%.2f %% / rok", vm.propertyAppreciationPct))
                }
                PDFParam("Pojištění", czk(vm.annualInsurance) + " / rok")
                PDFParam("SVJ / fond oprav", czk(vm.monthlySVJ) + " / měs.")
                if vm.includeManagement {
                    PDFParam("Správa nemovitosti", String(format: "%.0f %% z nájmu", vm.managementFeePct))
                }
                PDFParam("Roční opravy", czk(vm.annualRepairs))
                PDFParam("Velká údržba", "každých \(Int(vm.largeRepairEveryNYears)) let / \(czk(vm.largeRepairAmount))")
                if vm.includeTax {
                    PDFParam("Daň z nájmu", "\(vm.taxMode.rawValue), \(String(format: "%.0f %%", vm.taxRate))")
                }
            }

            Divider()

            // Výsledky
            Text("VÝSLEDKY ZA \(Int(vm.mortgageYears)) LET").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                PDFResult("Celkem zaplaceno úroků", czk(vm.totalInterest), .red)
                PDFResult("Celkem příjmy z nájmu", czk(vm.totalRent), .green)
                PDFResult("Celkem opravy", czk(vm.totalRepairs), .orange)
                if vm.totalOperating > 0 {
                    PDFResult("Celkem provoz", czk(vm.totalOperating), .secondary)
                }
                if vm.includeTax {
                    PDFResult("Celkem daň", czk(vm.totalTax), .purple)
                }
                if let y = vm.breakEvenYear {
                    PDFResult("Bod zvratu", "rok \(y)", .blue)
                }
                PDFResult("Čistý výsledek", czk(vm.finalBalance), vm.finalBalance >= 0 ? .green : .red)
                if vm.includeAppreciation {
                    PDFResult("Hodnota nemovitosti", czk(vm.finalPropertyValue), .blue)
                    PDFResult("Celkový výsledek investice", czk(vm.finalTotalInvestment),
                              vm.finalTotalInvestment >= 0 ? .green : .red)
                }
            }

            Divider()

            // Grafy
            Text("GRAFY").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kumulativní čistý výsledek").font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(.linearGradient(colors: [.green.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(d.cumulativeNet >= 0 ? Color.green : Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in AxisGridLine(); AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } } }}
                    .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let val = v.as(Double.self) { Text(czk(val, compact: true)).font(.system(size: 7)) } } }}
                    .frame(height: 160)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Čistý výsledek po letech").font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.netYear))
                            .foregroundStyle(d.netYear >= 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8)).cornerRadius(2)
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in AxisGridLine(); AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } } }}
                    .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let val = v.as(Double.self) { Text(czk(val, compact: true)).font(.system(size: 7)) } } }}
                    .frame(height: 160)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Složení splátky: jistina vs. úroky").font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.principalPaid), stacking: .normalized).foregroundStyle(Color.blue.opacity(0.75))
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.interestPaid), stacking: .normalized).foregroundStyle(Color.red.opacity(0.75))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in AxisGridLine(); AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } } }}
                    .chartYAxis { AxisMarks(values: [0, 0.5, 1.0]) { v in AxisGridLine(); AxisValueLabel { if let val = v.as(Double.self) { Text("\(Int(val * 100)) %").font(.system(size: 7)) } } }}
                    .frame(height: 160)
                    HStack(spacing: 8) {
                        Label("Jistina", systemImage: "rectangle.fill").foregroundStyle(.blue)
                        Label("Úroky", systemImage: "rectangle.fill").foregroundStyle(.red)
                    }.font(.system(size: 7))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zbývající dluh a celkové úroky").font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance), series: .value("Typ", "Zbývající dluh")).foregroundStyle(by: .value("Typ", "Zbývající dluh")).opacity(0.15)
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance), series: .value("Typ", "Zbývající dluh")).foregroundStyle(by: .value("Typ", "Zbývající dluh")).lineStyle(StrokeStyle(lineWidth: 2))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeInterest), series: .value("Typ", "Kumulativní úroky")).foregroundStyle(by: .value("Typ", "Kumulativní úroky")).lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartForegroundStyleScale(["Zbývající dluh": Color.blue, "Kumulativní úroky": Color.red])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in AxisGridLine(); AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } } }}
                    .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let val = v.as(Double.self) { Text(czk(val, compact: true)).font(.system(size: 7)) } } }}
                    .frame(height: 160)
                }
            }

            Divider()

            // Tabulka
            Text("PŘEHLED ROK PO ROKU").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            HStack(spacing: 0) {
                PDFCell("Rok", width: 35, bold: true)
                PDFCell("Úroky", width: 85, bold: true)
                PDFCell("Jistina", width: 85, bold: true)
                PDFCell("Dluh", width: 90, bold: true)
                PDFCell("Nájem", width: 85, bold: true)
                if vm.includeTax { PDFCell("Daň", width: 70, bold: true) }
                PDFCell("Opravy", width: 75, bold: true)
                PDFCell("Provoz", width: 75, bold: true)
                PDFCell("Čistý", width: 80, bold: true)
                PDFCell("Kumul.", width: 90, bold: true)
            }
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(4)

            ForEach(vm.schedule) { d in
                HStack(spacing: 0) {
                    PDFCell("\(d.year).\(d.isLargeRepairYear ? " 🔧" : "")\(d.isRefixYear ? " ↺" : "")", width: 35)
                    PDFCell(czk(d.interestPaid, compact: true), width: 85, color: .red)
                    PDFCell(czk(d.principalPaid, compact: true), width: 85)
                    PDFCell(czk(d.remainingBalance, compact: true), width: 90, color: .orange)
                    PDFCell(czk(d.rentalIncome, compact: true), width: 85, color: .green)
                    if vm.includeTax {
                        PDFCell(d.taxAmount > 0 ? czk(d.taxAmount, compact: true) : "—", width: 70, color: .purple)
                    }
                    PDFCell(czk(d.repairCost, compact: true), width: 75, color: d.isLargeRepairYear ? .orange : .secondary)
                    PDFCell(d.operatingCosts > 0 ? czk(d.operatingCosts, compact: true) : "—", width: 75, color: .secondary)
                    PDFCell(czk(d.netYear, compact: true), width: 80, color: d.netYear >= 0 ? .green : .red)
                    PDFCell(czk(d.cumulativeNet, compact: true), width: 90, color: d.cumulativeNet >= 0 ? .green : .red, bold: true)
                }
                .background(d.year % 2 == 0 ? Color.secondary.opacity(0.07) : .clear)
            }
        }
        .padding(32)
        .background(Color.white)
    }
}

// MARK: - PDF Helper Views

struct PDFParam: View {
    let label: String; let value: String
    init(_ l: String, _ v: String) { label = l; value = v }
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct PDFResult: View {
    let label: String; let value: String; let color: Color
    init(_ l: String, _ v: String, _ c: Color) { label = l; value = v; color = c }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundStyle(color)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct PDFCell: View {
    let text: String; let width: CGFloat
    var color: Color = .primary; var bold: Bool = false
    init(_ t: String, width: CGFloat, color: Color = .primary, bold: Bool = false) {
        text = t; self.width = width; self.color = color; self.bold = bold
    }
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: bold ? .semibold : .regular))
            .foregroundStyle(color)
            .frame(width: width, alignment: .trailing)
            .padding(.vertical, 3)
            .padding(.horizontal, 3)
    }
}
