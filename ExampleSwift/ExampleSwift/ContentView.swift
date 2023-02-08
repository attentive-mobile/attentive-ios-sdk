//
//  ContentView.swift
//  ExampleSwift
//
//  Created by Wyatt Davis on 1/29/23.
//

import SwiftUI
import os

struct CustomViewSwift : UIViewRepresentable {
typealias UIViewType = UIView
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CustomViewSwift.self)
    )
    
    var view : UIView = UIView()
    
    func makeUIView(context: Context) -> UIView {
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // TODO
        CustomViewSwift.logger.info("Updated uiview")
    }
}

class CustomViewController : UIViewController {
    var addChildAction : (() -> Void)?
    
    override func addChild(_ childController: UIViewController) {
        super.addChild(childController)
        addChildAction?()
    }
}

class CustomView : UIView {
    public var removeFromSuperViewAction : (() -> Void)?
    
    override func removeFromSuperview() {
        os_log("removeFromSuperview called")
        super.removeFromSuperview()
        self.removeFromSuperViewAction?()
    }
}

struct CustomViewControllerSwift : UIViewControllerRepresentable {
    
    @State var showingPopover = false

    typealias UIViewControllerType = CustomViewController
    
    var viewController : CustomViewController = CustomViewController()
        
    func makeUIViewController(context: Context) -> CustomViewController {
        let customView : CustomView = CustomView()
        customView.removeFromSuperViewAction = { () -> Void in showingPopover = false; os_log("remove from superview called, so removing popover");}
        
        viewController.view = customView
        viewController.addChildAction = { () -> Void in showingPopover = true }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: CustomViewController, context: Context) {
        // TODO
    }
}

struct CreativeView : View {
    @State var shouldShow : Bool
    
    let view : CustomViewControllerSwift = CustomViewControllerSwift()

    var body: some View {
        view
    }
    
    func getView() -> UIView {
        return view.viewController.view
    }
}

struct ContentView: View {
    @EnvironmentObject var attentiveData: AttentiveData
    
    @State private var showingPopover = false
    
    //let view : CustomViewControllerSwift = CustomViewControllerSwift()
    let creative : CreativeView = CreativeView(shouldShow: false)
    let customView : CustomViewSwift = CustomViewSwift()

    var body: some View {
        VStack {
            //view
            Button("Load Creative") {
                print("Done")
                attentiveData.sdk?.trigger(creative.getView())
                //showingPopover = true
            }.fullScreenCover(isPresented: $showingPopover) {
                creative
            }
            Button("Show Product Page") {
                
            }
            Button("Logout User") {
                attentiveData.sdk?.clearUser()
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
