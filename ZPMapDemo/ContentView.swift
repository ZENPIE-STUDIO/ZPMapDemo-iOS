//
//  ContentView.swift
//
//  Created by EddieHua.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        //MapViewControllerBridge()
        TabView {
            MapViewControllerBridge()
                .tabItem {
                    Image("TabMap")
                    Text("Map")
                }
                .tag(1)
                    
            Text("👻")
                .tabItem {
                    Image("TabInfo")
                    Text("Info")
                }
                .tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
