import Foundation

// MARK: - Сообщения, отправляемые на сервер

struct ClientMessage: Encodable {
    let type: String
}

struct MoveMessage: Encodable {
    let type = "move"
    let dx: Int
    let dy: Int
}

struct JoinMessage: Encodable {
    let type = "join"
    let role: String
    let name: String
    let color: ColorData?
    
    enum CodingKeys: String, CodingKey {
        case type, role, name, color
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(role, forKey: .role)
        try container.encode(name, forKey: .name)
        if let color = color {
            try container.encode(color, forKey: .color)
        }
    }
}

struct ColorData: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
}


// MARK: - Сообщения, получаемые от сервера

struct ServerMessageWrapper: Decodable {
    let type: String
    let payload: GameState?
}

struct AssignIdMessage: Decodable {
    let type: String
    let payload: String
}

struct Coordinate: Decodable {
    let x: Int
    let y: Int
}

struct ExplosionEvent: Decodable {
    let type: String
    let payload: ExplosionPayload
}

struct ExplosionPayload: Decodable {
    let cells: [Coordinate]
}

struct GameState: Decodable {
    let state: String // "WAITING", "IN_PROGRESS", "GAME_OVER"
    let winner: String?
    let time_remaining: Double?
    let map: [[String]]
    let players: [PlayerModel]
    let bombs: [BombModel]
}

// Модели объектов в игре
struct PlayerModel: Decodable, Identifiable, Equatable {
    let id: String
    let x: Int
    let y: Int
    let name: String
    let alive: Bool
    let ready: Bool?
    let color: ColorData?
}

struct BombModel: Decodable, Identifiable, Equatable {
    var id: String { "\(x)-\(y)" }
    let x: Int
    let y: Int
}

enum Direction: String, Decodable, CaseIterable {
    case up, down, left, right
}
