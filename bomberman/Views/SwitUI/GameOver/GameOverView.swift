import SwiftUI

struct GameOverView<ViewModel: GameOverViewModel>: View {
    
    // MARK: - Init
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("РАУНД ЗАВЕРШЕН")
                    .font(.pixelifySans(size: 40.0, fontWeight: .bold))
                    .foregroundColor(.white)

                if let winner = viewModel.winner {
                    Text("Победитель:")
                        .font(.pixelifySans(size: 20.0, fontWeight: .bold))
                        .foregroundColor(.gray)
                    Text(winner.name)
                        .font(.pixelifySans(size: 50.0, fontWeight: .bold))
                        .foregroundColor(.yellow)
                } else {
                    Text("НИЧЬЯ")
                        .font(.pixelifySans(size: 50.0, fontWeight: .bold))
                        .foregroundColor(.gray)
                }

                Text("Ожидание нового раунда...")
                    .font(.pixelifySans(size: 15.0, fontWeight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 20)
            }
            .padding(40)
            .background(Color(UIColor.darkGray))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
    
    // MARK: - Private Properties
    
    @ObservedObject private var viewModel: ViewModel
}
