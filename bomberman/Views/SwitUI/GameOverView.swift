//
//  GameOverView.swift
//  bomberman
//
//  Created by тимур on 12.12.2025.
//

import SwiftUI

struct GameOverView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("РАУНД ЗАВЕРШЕН")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if let winner = engine.players.first(where: { $0.alive }) {
                    Text("Победитель:")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text(winner.name)
                        .font(.system(size: 50, weight: .heavy))
                        .foregroundColor(.yellow)
                } else {
                    Text("НИЧЬЯ")
                        .font(.system(size: 50, weight: .heavy))
                        .foregroundColor(.gray)
                }

                Text("Ожидание нового раунда...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 20)
            }
            .padding(40)
            .background(Color(UIColor.darkGray))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}
