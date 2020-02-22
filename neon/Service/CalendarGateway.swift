//
//  CalendarGateway.swift
//  neon
//
//  Created by James Saeed on 25/02/2019.
//  Copyright © 2019 James Saeed. All rights reserved.
//

import Foundation
import EventKit

class CalendarGateway {
    
    static let shared = CalendarGateway()
    
    var eventStore = EKEventStore()
	
	var allDayEvent: ImportedCalendarEvent?
    
    func hasPermission() -> Bool {
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
        return status == EKAuthorizationStatus.authorized
    }
    
    func handlePermissions(completion: @escaping () -> ()) {
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
        
        if status == EKAuthorizationStatus.notDetermined {
            eventStore.requestAccess(to: .event) { granted, error in
                self.eventStore = EKEventStore()
                completion()
            }
        }
    }
    
    func importEvents(for date: Date) -> [ImportedCalendarEvent] {
        let eventsPredicate = eventStore.predicateForEvents(withStart: date.toLocalTime().dateAtStartOf(.day),
                                                            end: date.toLocalTime().dateAtEndOf(.day),
                                                            calendars: getEnabledCalendars())
        
        return eventStore.events(matching: eventsPredicate).map({ ImportedCalendarEvent(from: $0) })
    }
    
    func rename(event: EKEvent, to newTitle: String) {
        event.title = newTitle
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch let error {
            print(error)
        }
    }
    
    func clear(event: EKEvent) {
        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch let error {
            print(error)
        }
    }
	
	private func getEnabledCalendars() -> [EKCalendar] {
        var calendars = [EKCalendar]()
        
        let userCalendars = DataGateway.shared.getUserCalendarEntities().compactMap({ UserCalendar(fromEntity: $0 )})
        
        for calendar in getAllCalendars() {
            if userCalendars.first(where: { $0.identifier == calendar.calendarIdentifier })?.enabled == false {
                continue
            } else {
                calendars.append(calendar)
            }
        }
        
        return calendars
	}
	
	func getAllCalendars() -> [EKCalendar] {
		return eventStore.calendars(for: .event)
	}
}

struct ImportedCalendarEvent {
    
    let eventEntity: EKEvent
    let title: String
    let date: Date
    
    var isAllDay: Bool
    var startingHour: Int
    var endingHour: Int
    
    init(from event: EKEvent) {
        self.eventEntity = event
        self.title = event.title
        self.date = event.startDate
        self.isAllDay = event.isAllDay
        
        self.startingHour = Calendar.current.component(.hour, from: event.startDate)
        self.endingHour = Calendar.current.component(.hour, from: event.endDate)
		
        // Calibrate hours
        if startingHour > Calendar.current.component(.hour, from: event.endDate) {
            endingHour = 23
        } else if startingHour == Calendar.current.component(.hour, from: event.endDate) {
            endingHour = startingHour
        } else {
            if Calendar.current.component(.minute, from: event.endDate) == 0 {
                endingHour = Calendar.current.component(.hour, from: event.endDate) - 1
            } else {
                endingHour = Calendar.current.component(.hour, from: event.endDate)
            }
        }
    }
}
