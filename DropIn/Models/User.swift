//
//  User.swift
//  DropIn
//

import Foundation

struct User: Identifiable, Codable {
    var id: String = UUID().uuidString
    let name: String
    let email: String
    var avatarUrl: String?
}
