/// ChartPanel.swift — 4 interaktivní grafy

import SwiftUI
import Charts

struct ChartPanel: View {
    var vm: MortgageViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Graf 1 — Složení splátky (amortizace)
                GroupBox {
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.principalPaid),
                                stacking: .normalized)
                            .foregroundStyle(Color.blue.opacity(0.75))
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.interestPaid),
                                stacking: .normalized)
                            .foregroundStyle(Color.red.opacity(0.75))
                        if vm.useRefixation {
                            RuleMark(x: .value("Rok", Int(vm.refixYear)))
                                .foregroundStyle(Color.indigo.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                        }
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)") } }
                    }}
                    .chartYAxis { AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text("\(Int(val * 100)) %").font(.caption) }}
                    }}
                    .frame(height: 180).padding(.top, 4)

                    HStack(spacing: 20) {
                        Label("Jistina", systemImage: "rectangle.fill").foregroundStyle(.blue)
                        Label("Úroky", systemImage: "rectangle.fill").foregroundStyle(.red)
                        if vm.useRefixation {
                            Label("Refixace rok \(Int(vm.refixYear))", systemImage: "line.diagonal")
                                .foregroundStyle(.indigo)
                        }
                    }
                    .font(.caption).padding(.top, 4)
                } label: {
                    Label("Složení splátky: jistina vs. úroky", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                }

                // Graf 2 — Kumulativní čistý výsledek
                GroupBox {
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(.linearGradient(
                                colors: [.green.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(d.cumulativeNet >= 0 ? Color.green : Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)") } }
                    }}
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.caption) }}
                    }}
                    .frame(height: 260).padding(.top, 4)
                } label: {
                    Label("Kumulativní čistý výsledek", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                }

                // Graf 3 — Zbývající dluh vs. kumulativní úroky
                GroupBox {
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance),
                                 series: .value("Typ", "Zbývající dluh"))
                            .foregroundStyle(by: .value("Typ", "Zbývající dluh")).opacity(0.12)
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance),
                                 series: .value("Typ", "Zbývající dluh"))
                            .foregroundStyle(by: .value("Typ", "Zbývající dluh"))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeInterest),
                                 series: .value("Typ", "Kumulativní úroky"))
                            .foregroundStyle(by: .value("Typ", "Kumulativní úroky"))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartForegroundStyleScale([
                        "Zbývající dluh": Color.blue, "Kumulativní úroky": Color.red
                    ])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)") } }
                    }}
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.caption) }}
                    }}
                    .frame(height: 220).padding(.top, 4)
                } label: {
                    Label("Zbývající dluh a celkové úroky", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                }

                // Graf 4 — Čistý roční výsledek
                GroupBox {
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.netYear))
                            .foregroundStyle(d.netYear >= 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                            .cornerRadius(3)
                            .annotation(position: d.isLargeRepairYear ? .top : .overlay) {
                                if d.isLargeRepairYear {
                                    Image(systemName: "wrench.fill")
                                        .font(.system(size: 8)).foregroundStyle(.orange)
                                }
                            }
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.caption) }}
                    }}
                    .frame(height: 200).padding(.top, 4)

                    HStack {
                        Image(systemName: "wrench.fill").foregroundStyle(.orange)
                        Text("= rok velké údržby").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Čistý výsledek po letech (nájem − úroky − opravy − provoz − daň)", systemImage: "chart.bar.fill")
                        .font(.headline)
                }
            }
            .padding()
        }
    }
}
