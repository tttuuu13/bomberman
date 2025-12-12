import SwiftUI

struct GameSettingsView<Model: GameSettingsViewModel>: View {
    
    // MARK: - Init
    
    init(model: Model) {
        self.model = model
    }
    
    // MARK: - Body
    
    var body: some View {
        Button("dismiss") {
            dismiss()
        }
    }
    
    // MARK: - Private Properties
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var model: Model
}
