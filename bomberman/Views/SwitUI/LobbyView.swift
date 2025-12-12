//
//  LobbyView.swift
//  bomberman
//
//  Created by тимур on 12.12.2025.
//

import SwiftUI

struct LobbyView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        VStack(spacing: 30) {
            Text("ЛОББИ")
                .font(.system(size: 40, weight: .heavy))
                .foregroundColor(.white)
                .padding(.top, 50)

            // Список игроков
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(engine.players) { player in
                        HStack {
                            Text(player.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Spacer()

                            if player.ready == true {
                                Text("ГОТОВ")
                                    .foregroundColor(.green)
                                    .fontWeight(.bold)
                            } else {
                                Text("ЖДЕМ...")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(player.id == engine.myPlayerId ? Color.yellow : Color.clear, lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Кнопка готовности (только для себя)
            if let me = engine.players.first(where: { $0.id == engine.myPlayerId }) {
                Button(action: {
                    engine.setReady()
                }) {
                    Text(me.ready == true ? "ОТМЕНА" : "Я ГОТОВ!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(me.ready == true ? Color.red : Color.green)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }
}
