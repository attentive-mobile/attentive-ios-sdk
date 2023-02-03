//
//  ContentView.swift
//  ExampleSwift
//
//  Created by Wyatt Davis on 1/29/23.
//

import SwiftUI

struct CustomViewControllerSwift : UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    
    var viewController : UIViewController = UIViewController()
        
    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // TODO
    }
}

struct ContentView: View {
    @EnvironmentObject var attentiveData: AttentiveData
    
    let view : CustomViewControllerSwift = CustomViewControllerSwift()

    var body: some View {
        VStack {
            view
            Button("Load Creative") {
                print("Done")
                attentiveData.sdk?.trigger(view.viewController.view)
            }
            Button("Show Product Page") {
                
            }
            Button("Logout User") {
                // TODO
            }
            Button("Send user identifers") {
                // TODO
            }
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
    }
}

func triggerCreative() {
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
