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
        os_log("addChildAction")
        addChildAction?()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let webview : WKWebView
        for subview in self.view.subviews {
            if (subview as? WKWebView) != nil {
                subview.frame = self.view.frame
            }
        }
        os_log("viewWillLayoutSubviews")
    }
}

class CustomView : UIView {
    public var removeFromSuperViewAction : (() -> Void)?
    
    override func removeFromSuperview() {
        os_log("removeFromSuperview called")
        super.removeFromSuperview()
        self.removeFromSuperViewAction?()
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        os_log("addSubview called")
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if (subview as? WKWebView) != nil {
            os_log("didAddSubview for WebView")
        }
        os_log("didAddSubview for non-WebView")
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        if (subview as? WKWebView) != nil {
            os_log("willRemoveSubview for WebView")
        } else {
            os_log("willRemoveSubview for non-WebView")
        }
    }
}

struct CustomViewControllerSwift : UIViewControllerRepresentable {
    
    @State var showingPopover = false

    typealias UIViewControllerType = CustomViewController
    
    var viewController : CustomViewController = CustomViewController()
        
    func makeUIViewController(context: Context) -> CustomViewController {
        os_log("makeUIViewController")
        let customView : CustomView = CustomView()
        customView.removeFromSuperViewAction = { () -> Void in showingPopover = false; os_log("remove from superview called, so removing popover");}
        
        viewController.view = customView
        viewController.addChildAction = { () -> Void in showingPopover = true }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: CustomViewController, context: Context) {
        os_log("updateUIViewController")
        // TODO
    }
}

struct CreativeView : View {
    let view : CustomViewControllerSwift = CustomViewControllerSwift()

    var body: some View {
        view
    }
    
    init() {
        os_log("create CreativeView")
    }
    
    func getView() -> UIView {
        return view.viewController.view
    }
    
    func getViewController() -> UIViewController {
        return view.viewController
    }
}

struct ContentView: View {
    @EnvironmentObject var attentiveData: AttentiveData
    
    @State private var showingPopover = false
    
    // TODO ignoresSafeArea ?
    
    //let view : CustomViewControllerSwift = CustomViewControllerSwift()
    let creative : CreativeView = CreativeView()
    let customView : CustomViewSwift = CustomViewSwift()

    var body: some View {
        VStack {
            Button("Load Creative") {
                print("Done")
                //attentiveData.sdk?.trigger(creative.getView())
                showingPopover.toggle()
            }.fullScreenCover(isPresented: $showingPopover) {
                creative
                    .border(.green, width: 4).onAppear(perform: {
                        attentiveData.sdk?.trigger(creative.getView())
                    })
                 
            }
            .border(.red, width: 4)
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
