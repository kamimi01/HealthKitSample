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
    case everySixMonths = "6ヶ月"
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
        }
        .padding(.horizontal, 16)
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
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(viewModel.hourlySteps) { item in
                    BarMark(
                        x: .value("時間", item.endDate, unit: .hour),
                        y: .value("歩数", item.animate ? item.value : 0)
                    )
                }
            }
            .frame(height: 300)
            .frame(width: CGFloat(viewModel.hourlySteps.count) * 130)
            .chartXAxis {
                AxisMarks(preset: .extended, values: .stride(by: .hour, count: 1)) { value in
                    AxisValueLabel()
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYScale(domain: [0, maxStepCount(stepCount: viewModel.hourlySteps)])
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animate()
                }
            }
            .onDisappear {
                for index in viewModel.hourlySteps.indices {
                    viewModel.hourlySteps[index].animate = false
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    func maxStepCount(stepCount: [HealthDataTypeValue]) -> Double {
        let max = stepCount.max(by: { (a, b) -> Bool in
            return a.value < b.value //ここの不等号の向き要注意！
        })
        guard let max else { return 1000.0 }
        return max.value * 1.5
    }

    func weeklyChart() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(viewModel.weeklySteps) { item in
                    BarMark(
                        x: .value("日付", item.endDate, unit: .day),
                        y: .value("歩数", item.animate ? item.value : 0)
                    )
                }
            }
            .frame(width: 400, height: 300)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                    AxisValueLabel(format: .dateTime.weekday())
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYScale(domain: [0, maxStepCount(stepCount: viewModel.weeklySteps)])
            .onAppear {
                print("onAppear2呼ばれた")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateWeeklySteps()
                }
            }
            .onDisappear {
                print("onDisapper2呼ばれた")
                for index in viewModel.weeklySteps.indices {
                    viewModel.weeklySteps[index].animate = false
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    func monthlyChart() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(viewModel.monthlySteps) { item in
                    BarMark(
                        x: .value("日付", item.endDate, unit: .day),
                        y: .value("歩数", item.animate ? item.value : 0)
                    )
                }
            }
            .frame(width: 400, height: 300)
            .chartYScale(domain: [0, maxStepCount(stepCount: viewModel.monthlySteps)])
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateMonthlySteps()
                }
            }
            .onDisappear {
                for index in viewModel.monthlySteps.indices {
                    viewModel.monthlySteps[index].animate = false
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    func everySixMonthsChart() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(viewModel.everySixMonthsSteps) { item in
                    BarMark(
                        x: .value("月", item.endDate, unit: .month),
                        y: .value("歩数", item.animate ? item.value : 0)
                    )
                }
            }
            .frame(width: 400, height: 300)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { value in
                    AxisValueLabel()
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYScale(domain: [0, maxStepCount(stepCount: viewModel.everySixMonthsSteps)])
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateEverySixMonthsSteps()
                }
            }
            .onDisappear {
                for index in viewModel.everySixMonthsSteps.indices {
                    viewModel.everySixMonthsSteps[index].animate = false
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    func yearlyChart() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(viewModel.yearlySteps) { item in
                    BarMark(
                        x: .value("月", item.endDate, unit: .month),
                        y: .value("歩数", item.animate ? item.value : 0)
                    )
                }
            }
            .frame(width: 400, height: 300)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { value in
                    AxisValueLabel(format: .dateTime.day().month())
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYScale(domain: [0, maxStepCount(stepCount: viewModel.yearlySteps)])
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateYearlySteps()
                }
            }
            .onDisappear {
                for index in viewModel.yearlySteps.indices {
                    viewModel.yearlySteps[index].animate = false
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    func animate() {
        print(#function)
        for (index, _) in viewModel.hourlySteps.enumerated() {
            print("hourlySteps:", viewModel.hourlySteps[index].animate)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.linear(duration: 0.8)) {
                    viewModel.hourlySteps[index].animate = true
                }
            }
        }
    }

    func animateWeeklySteps() {
        print(#function)
        for (index, _) in viewModel.weeklySteps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    viewModel.weeklySteps[index].animate = true
                }
            }
        }
    }

    func animateMonthlySteps() {
        print(#function)
        for (index, _) in viewModel.monthlySteps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    viewModel.monthlySteps[index].animate = true
                }
            }
        }
    }

    func animateEverySixMonthsSteps() {
        print(#function)
        for (index, _) in viewModel.everySixMonthsSteps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    viewModel.everySixMonthsSteps[index].animate = true
                }
            }
        }
    }

    func animateYearlySteps() {
        print(#function)
        for (index, _) in viewModel.yearlySteps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    viewModel.yearlySteps[index].animate = true
                }
            }
        }
    }
}

struct HealthCareChartView_Previews: PreviewProvider {
    static var previews: some View {
        HealthCareChartView()
    }
}
