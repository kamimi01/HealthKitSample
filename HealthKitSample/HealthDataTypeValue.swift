//
//  HealthDataTypeValue.swift
//  HealthKitSample
//
//  Created by mikaurakawa on 2023/08/25.
//

import Foundation

/// A representation of health data to use for `HealthDataTypeTableViewController`.
struct HealthDataTypeValue: Identifiable {
    let id = UUID().uuidString
    let startDate: Date
    let endDate: Date
    var value: Double
}
