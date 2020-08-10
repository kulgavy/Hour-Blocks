//
//  CalendarOptionsViewModel.swift
//  Hour Blocks
//
//  Created by James Saeed on 22/07/2020.
//  Copyright © 2020 James Saeed. All rights reserved.
//

import Foundation
import EventKit

class CalendarOptionsViewModel: ObservableObject {
    
    let calendarGateway: CalendarGateway
    
    @Published var allCalendars = [EKCalendar]()
    @Published var enabledCalendars = [String: Bool]()
    
    init(calendarGateway: CalendarGateway) {
        self.calendarGateway = calendarGateway
        
        loadCalendars()
    }
    
    convenience init() {
        self.init(calendarGateway: CalendarGateway())
    }
    
    func loadCalendars() {
        allCalendars = calendarGateway.getAllCalendars()
        
        enabledCalendars = UserDefaults.standard.dictionary(forKey: "enabledCalendars") as? [String: Bool] ?? calendarGateway.initialiseEnabledCalendars()
    }
    
    func updateCalendar(for identifier: String, with value: Bool) {
        enabledCalendars[identifier] = value
        
        UserDefaults.standard.set(enabledCalendars, forKey: "enabledCalendars")
        
        NotificationCenter.default.post(name: Notification.Name("RefreshSchedule"), object: nil)
    }
}
