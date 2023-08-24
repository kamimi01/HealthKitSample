//
//  HealthCareChartViewModel.swift
//  HealthKitSample
//
//  Created by mikaurakawa on 2023/08/25.
//

import Foundation
import SwiftUI
import HealthKit

@MainActor
class HealthCareChartViewModel: ObservableObject {
    // Published という変数が他で定義されている影響なのか、「'Published' is ambiguous for type lookup in this context」のエラーが発生したので、 @SwiftUI を冒頭につけて回避
    // - seealso: https://www.reddit.com/r/iOSProgramming/comments/1070i8z/comment/j3jxr6m/?utm_source=share&utm_medium=web2x&context=3
    @SwiftUI.Published var isShowingError = false
    @SwiftUI.Published private(set) var errorMessage = ""
    /// 毎日の歩数
    @SwiftUI.Published private(set) var dailySteps: [HealthDataTypeValue] = []
    @SwiftUI.Published var selectedFrequency: Frequency = .daily

    private var healthStore: HKHealthStore?
    private var query: HKStatisticsCollectionQuery?

    func onAppear() {
        setupHealthKit()
    }

    private func setupHealthKit() {
        if HKHealthStore.isHealthDataAvailable() == false {
            isShowingError = true
            errorMessage = "ヘルスデータが利用できません。😢"
            return
        }

        healthStore = HKHealthStore()

        Task {
            await requestWriteAccessToHealthData()
            calculateStepCount()
        }
    }

    /// 読み込みアクセスのリクエスト
    private func requestWriteAccessToHealthData() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータへのアクセスに失敗しました。😢"
            return
        }

        // async/await バージョン
        do {
            try await healthStore?.requestAuthorization(toShare: [], read: [stepType])
        } catch {
            self.isShowingError = true
            self.errorMessage = error.localizedDescription
            return
        }
    }

    /// ヘルスデータの読み込み
    func calculateStepCount() {
        guard let stepType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータの読み込みに失敗しました。😢"
            return
        }
        let today = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let daily = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: today)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: sevenDaysAgo,
            intervalComponents: daily
        )

        query.initialResultsHandler = { [weak self] query, statisticsCollection, error in
            guard let self else { return }

            if statisticsCollection == nil || error != nil {
                DispatchQueue.main.async {
                    self.isShowingError = true
                    self.errorMessage = error?.localizedDescription ?? "予測できないエラーが発生しました。😢"
                }
                return
            }

            if let statisticsCollection {
                self.updateUIFromStatistics(statisticsCollection)
            }
        }

        /// バックグラウンドで更新されてもデータを取得できるように
        query.statisticsUpdateHandler = { [weak self] query, statistics, statisticsCollection, error in
            guard let self else { return }

            if statisticsCollection == nil || error != nil {
                DispatchQueue.main.async {
                    self.isShowingError = true
                    self.errorMessage = error?.localizedDescription ?? "予測できないエラーが発生しました。😢"
                }
                return
            }

            if let statisticsCollection {
                self.updateUIFromStatistics(statisticsCollection)
            }
        }

        healthStore?.execute(query)
        self.query = query
    }

    private func updateUIFromStatistics(_ statisticsCollection: HKStatisticsCollection) {

        let today = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let endDate = today

        statisticsCollection.enumerateStatistics(from: startDate, to: endDate) { [weak self] statistics, stop in
            guard let self else { return }

            var dataValue = HealthDataTypeValue(
                startDate: statistics.startDate,
                endDate: statistics.endDate,
                value: 0
            )

            // 取得した8つ目のデータが nil になる
            guard let quantity = statistics.sumQuantity() else { return }
            let unit: HKUnit = .count()
            dataValue.value = quantity.doubleValue(for: unit)

            DispatchQueue.main.async {
                print("dataだよ：", dataValue)
                self.dailySteps.append(dataValue)
            }
        }
    }

//    private func createAnchorDate() -> Date {
//        // Set the arbitrary anchor date to Monday at 3:00 a.m.
//        let calendar: Calendar = .current
//        var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())
//        let offset = (7 + (anchorComponents.weekday ?? 0) - 2) % 7
//
//        anchorComponents.day! -= offset
//        anchorComponents.hour = 3
//
//        let anchorDate = calendar.date(from: anchorComponents)!
//
//        return anchorDate
//    }

    func onDisappear() {
        if let query {
            healthStore?.stop(query)
        }
    }
}
