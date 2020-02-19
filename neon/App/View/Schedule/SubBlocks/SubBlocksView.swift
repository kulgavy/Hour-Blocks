//
//  SubBlocksView.swift
//  neon
//
//  Created by James Saeed on 26/11/2019.
//  Copyright © 2019 James Saeed. All rights reserved.
//

import SwiftUI

struct SubBlocksView: View {
    
    @Binding var isPresented: Bool
    
    @EnvironmentObject var viewModel: ScheduleViewModel
    
    let hourBlock: HourBlock
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.currentSubBlocks.filter({ $0.hour == hourBlock.hour }).count > 0 {
                    ForEach(viewModel.currentSubBlocks.filter({ $0.hour == hourBlock.hour })) { subBlock in
                        SubBlockCard(currentHourBlock: self.hourBlock, currentSubBlock: subBlock)
                    }
                }
                EmptySubBlockCard(currentHourBlock: hourBlock)
            }.navigationBarTitle("Today at \(hourBlock.formattedTime.lowercased())")
            .navigationBarItems(trailing: Button(action: dismiss, label: {
                Text("Close")
            }))
        }.accentColor(Color("secondary"))
    }
    
    func dismiss() {
        isPresented = false
    }
}
