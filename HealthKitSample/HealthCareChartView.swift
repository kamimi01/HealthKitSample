//
//  HealthCareChartView.swift
//  HealthKitSample
//
//  Created by mikaurakawa on 2023/08/25.
//

import Foundation
import SwiftUI
import Charts

enum Frequency: String, CaseIterable, Identifiable {
    case hourly = "日"
    case weekly = "週"
    case monthly = "月"
    case everySixMonths = "6ヶ月ごと"
    case yearly = "年"

    var id: String { rawValue }
}

struct HealthCareChartView: View {
    @ObservedObject private var viewModel = HealthCareChartViewModel()

    var body: some View {
        VStack {
            Picker("", selection: $viewModel.selectedFrequency) {
                ForEach(Frequency.allCases) { frequency in
                    Text(frequency.rawValue).tag(frequency)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            switch viewModel.selectedFrequency {
            case .hourly: dailyChart()
            case .weekly: weeklyChart()
            case .monthly: monthlyChart()
            case .everySixMonths: everySixMonthsChart()
            case .yearly: yearlyChart()
            }
            Spacer()
        }
        .alert(isPresented: $viewModel.isShowingError) {
            Alert(title: Text("エラー"), message: Text(viewModel.errorMessage))
        }
        .task {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

private extension HealthCareChartView {
    func dailyChart() -> some View {
        Chart {
            ForEach(viewModel.hourlySteps) { item in
                BarMark(
                    x: .value("時間", item.startDate, unit: .hour),
                    y: .value("歩数", item.value)
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                AxisValueLabel()
                AxisGridLine()
                AxisTick()
            }
        }
    }

    func weeklyChart() -> some View {
        Chart {
            ForEach(viewModel.weeklySteps) { item in
                BarMark(
                    x: .value("日付", item.startDate, unit: .day),
                    y: .value("歩数", item.value)
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 1)) { value in
                AxisValueLabel(format: .dateTime.weekday())
                AxisGridLine()
                AxisTick()
            }
        }
    }

    func monthlyChart() -> some View {
        Chart {
            ForEach(viewModel.monthlySteps) { item in
                BarMark(
                    x: .value("日付", item.startDate, unit: .day),
                    y: .value("歩数", item.value)
                )
            }
        }
    }

    func everySixMonthsChart() -> some View {
        Chart {
            ForEach(viewModel.everySixMonthsSteps) { item in
                BarMark(
                    x: .value("月", item.startDate, unit: .month),
                    y: .value("歩数", item.value)
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisValueLabel()
                AxisGridLine()
                AxisTick()
            }
        }
    }

    func yearlyChart() -> some View {
        Chart {
            ForEach(viewModel.yearlySteps) { item in
                BarMark(
                    x: .value("月", item.startDate, unit: .month),
                    y: .value("歩数", item.value)
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisValueLabel(format: .dateTime.day().month())
                AxisGridLine()
                AxisTick()
            }
        }
    }
}

struct HealthCareChartView_Previews: PreviewProvider {
    static var previews: some View {
        HealthCareChartView()
    }
}
