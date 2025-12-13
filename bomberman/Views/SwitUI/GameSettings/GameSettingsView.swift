import SwiftUI

struct GameSettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: GameSettingsViewModelImpl
    @FocusState private var isTextFieldFocused: Bool
    
    init(engine: GameEngine) {
        self._model = StateObject(wrappedValue: GameSettingsViewModelImpl(engine: engine))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        HStack {
                            Text("НАСТРОЙКИ")
                                .font(.pixelifySans(size: 40.0, fontWeight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                model.onDismiss()
                                dismiss()
                            }) {
                                Text("✕")
                                    .font(.pixelifySans(size: 30.0, fontWeight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("ИМЯ ИГРОКА")
                                .font(.pixelifySans(size: 20.0, fontWeight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("Введите имя", text: $model.playerName)
                                .font(.pixelifySans(size: 25.0, fontWeight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isTextFieldFocused ? Color.white.opacity(0.6) : Color.white.opacity(0.3), lineWidth: 2)
                                )
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($isTextFieldFocused)
                        }
                        .padding(.bottom, 5)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("ЦВЕТ ИГРОКА")
                                .font(.pixelifySans(size: 20.0, fontWeight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack {
                                Text(model.playerName.isEmpty ? "Игрок" : model.playerName)
                                    .font(.pixelifySans(size: 25.0, fontWeight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(model.playerColor.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(model.playerColor, lineWidth: 3)
                                    )
                                    .cornerRadius(12)
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 15) {
                                ForEach(0..<model.availableColors.count, id: \.self) { index in
                                    let color = model.availableColors[index]
                                    let isSelected = model.selectedColorIndex == index
                                    Button(action: {
                                        model.selectedColorIndex = index
                                    }) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: isSelected ? 4 : 0)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                            )
                                            .shadow(color: color.opacity(0.5), radius: isSelected ? 10 : 0)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical, 30)
                        .padding(.horizontal, 40)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
        }
        .onAppear {
            model.saveInitialName()
        }
    }
}
