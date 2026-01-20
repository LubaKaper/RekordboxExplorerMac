//
//  Formatters.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/17/26.
//

import Foundation

enum Formatters {
    static func duration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
