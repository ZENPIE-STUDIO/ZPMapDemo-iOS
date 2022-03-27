//
//  MapViewControllerBridge.swift
//
//  Created by EddieHua.
//

import SwiftUI
import UIKit

struct MapViewControllerBridge : UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MapViewController {
        return MapViewController()
    }

    func updateUIViewController(_ controller: MapViewController, context: Context) {
        
    }
}
