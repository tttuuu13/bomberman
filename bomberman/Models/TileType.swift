//
//  TileType.swift
//  bomberman
//
//  Created by тимур on 07.12.2025.
//

import Foundation

enum TileType: String, Codable {
    case wall = "#"
    case brick = "."
    case empty = " "
    case spawn = "p"
}
