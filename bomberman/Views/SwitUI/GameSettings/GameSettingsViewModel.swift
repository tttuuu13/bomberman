import Combine
import SwiftUI
import UIKit

@MainActor
protocol GameSettingsViewModel: ObservableObject {
    var playerName: String { get set }
    var playerColor: Color { get set }
    var selectedColorIndex: Int { get set }
    var availableColors: [Color] { get }
    func saveInitialName()
    func onDismiss()
}

final class GameSettingsViewModelImpl: GameSettingsViewModel {
    
    init(engine: GameEngine? = nil) {
        self.engine = engine
        let defaults = UserDefaults.standard
        defaults.synchronize()
        
        _initialPlayerName = defaults.string(forKey: "playerName") ?? ""
        _initialColorRed = defaults.object(forKey: "playerColorRed") as? Double ?? 1.0
        _initialColorGreen = defaults.object(forKey: "playerColorGreen") as? Double ?? 0.0
        _initialColorBlue = defaults.object(forKey: "playerColorBlue") as? Double ?? 0.0
    }
    
    private weak var engine: GameEngine?
    private var _initialPlayerName: String = ""
    private var _initialColorRed: Double = 1.0
    private var _initialColorGreen: Double = 0.0
    private var _initialColorBlue: Double = 0.0
    
    private var initialPlayerName: String {
        get {
            if _initialPlayerName.isEmpty {
                _initialPlayerName = playerName
            }
            return _initialPlayerName
        }
        set {
            _initialPlayerName = newValue
        }
    }
    
    @AppStorage("playerName") var playerName: String = "" {
        didSet {
            if _initialPlayerName.isEmpty && !playerName.isEmpty {
                _initialPlayerName = playerName
            }
        }
    }
    @AppStorage("playerColorRed") private var colorRed: Double = 1.0
    @AppStorage("playerColorGreen") private var colorGreen: Double = 0.0
    @AppStorage("playerColorBlue") private var colorBlue: Double = 0.0
    
    var playerColor: Color {
        get {
            Color(red: colorRed, green: colorGreen, blue: colorBlue)
        }
        set {
            let uiColor = UIColor(newValue)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                colorRed = Double(red)
                colorGreen = Double(green)
                colorBlue = Double(blue)
            } else {
                let cgColor = uiColor.cgColor
                let components = cgColor.components ?? [1.0, 0.0, 0.0]
                if cgColor.numberOfComponents >= 3 {
                    colorRed = Double(components[0])
                    colorGreen = Double(components[1])
                    colorBlue = Double(components[2])
                }
            }
        }
    }
    
    var selectedColorIndex: Int {
        get {
            let currentRed = colorRed
            let currentGreen = colorGreen
            let currentBlue = colorBlue
            
            for (index, color) in availableColors.enumerated() {
                let uiColor = UIColor(color)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                
                var colorRed: Double
                var colorGreen: Double
                var colorBlue: Double
                
                if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    colorRed = Double(red)
                    colorGreen = Double(green)
                    colorBlue = Double(blue)
                } else {
                    let cgColor = uiColor.cgColor
                    let components = cgColor.components ?? [0, 0, 0]
                    if cgColor.numberOfComponents >= 3 {
                        colorRed = Double(components[0])
                        colorGreen = Double(components[1])
                        colorBlue = Double(components[2])
                    } else {
                        continue
                    }
                }
                
                if abs(currentRed - colorRed) < 0.01 &&
                   abs(currentGreen - colorGreen) < 0.01 &&
                   abs(currentBlue - colorBlue) < 0.01 {
                    return index
                }
            }
            return 0
        }
        set {
            guard newValue >= 0 && newValue < availableColors.count else { return }
            playerColor = availableColors[newValue]
        }
    }
    
    let availableColors: [Color] = [
        .red,
        .cyan,
        .green,
        .yellow,
        .orange,
        .blue,
        .purple,
        .pink,
        .white
    ]
    
    func saveInitialName() {
        _initialPlayerName = playerName
        _initialColorRed = colorRed
        _initialColorGreen = colorGreen
        _initialColorBlue = colorBlue
    }
    
    func onDismiss() {
        UserDefaults.standard.synchronize()
        
        let currentNameRaw = playerName
        let currentName = currentNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialNameRaw = _initialPlayerName
        let initialNameTrimmed = initialNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let nameChanged = initialNameTrimmed != currentName
        
        let colorRedChanged = abs(colorRed - _initialColorRed) >= 0.01
        let colorGreenChanged = abs(colorGreen - _initialColorGreen) >= 0.01
        let colorBlueChanged = abs(colorBlue - _initialColorBlue) >= 0.01
        let colorChanged = colorRedChanged || colorGreenChanged || colorBlueChanged
        
        if nameChanged || colorChanged {
            if !currentName.isEmpty {
                UserDefaults.standard.set(currentName, forKey: "playerName")
            }
            UserDefaults.standard.set(colorRed, forKey: "playerColorRed")
            UserDefaults.standard.set(colorGreen, forKey: "playerColorGreen")
            UserDefaults.standard.set(colorBlue, forKey: "playerColorBlue")
            UserDefaults.standard.synchronize()
        }
        
        if nameChanged || colorChanged {
            if let engine = engine {
                if nameChanged {
                    print("✓ Имя изменилось - переподключаемся к игре")
                }
                if colorChanged {
                    print("✓ Цвет изменился - переподключаемся к игре")
                }
                engine.reconnectWithNewName()
            }
        }
    }
}
