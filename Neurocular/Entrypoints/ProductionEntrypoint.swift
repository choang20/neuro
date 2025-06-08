//
//  ProductionEntrypoint.swift
//  Neurocular
//
//  Created by Max Taggart on 5/26/25.
//

import SwiftUI

struct ProductionEntrypoint: View {
    @State private var show_splash = true;
    
    var body: some View {
        if show_splash {
            Splash()
                .task {
                try! await Task.sleep(for: .milliseconds(1500));
                show_splash = false;
            }
        } else {
            Home()
        }
    }
}

#Preview {
    ProductionEntrypoint()
}
