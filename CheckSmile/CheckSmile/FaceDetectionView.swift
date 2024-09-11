//
//  FaceDetectionView.swift
//  CheckSmile
//
//  Created by Mohamed Salah on 11/09/2024.
//

import SwiftUI

struct FaceDetectionView: View {
    @StateObject var viewModel: FaceDetectionViewModel = FaceDetectionViewModel()
    
    init() {
    }
    var body: some View {
        VStack {
            ZStack{
                ARViewContainer(arViewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        viewModel.resumeSession()
                    }
                    .clipShape(Ellipse())
                    .overlay(
                        Ellipse()
                            .stroke(canPass() ? .green : .red, lineWidth: 3)
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 150)
                VStack {
                    Text("Number of Faces \(viewModel.numberOfFaces)")
                        .padding()
                        .foregroundColor(.orange)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color(UIColor.systemBackground)))
                    Text(viewModel.isSmiling.currentSmileCase)
                        .padding()
                        .foregroundColor(viewModel.isSmiling == .smiling ? .green : .red)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color(UIColor.systemBackground)))
                    Spacer()
                }
            }
            Spacer()
                .frame(height: 200)
        }
        .onAppear {
            viewModel.resumeSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .background(.white)
    }
    func canPass() -> Bool {
        return viewModel.faceDetected && viewModel.numberOfFaces == 1 && viewModel.isSmiling == .smiling
    }
}

#Preview {
    FaceDetectionView()
}
