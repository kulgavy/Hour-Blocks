//
//  HourBlock.swift
//  neon3
//
//  Created by James Saeed on 18/06/2019.
//  Copyright © 2019 James Saeed. All rights reserved.
//

import SwiftUI
import Combine
import CoreData

struct HourBlock: Hashable {
    
    let identifier: String
    let day: Date
    let hour: Int
    let minute: BlockMinute
    
    let title: String?
    var domain: BlockDomain?
    var hasReminder = false
    
    init(day: Date, hour: Int, minute: BlockMinute, title: String?) {
        self.identifier = UUID().uuidString
        self.day = day
        self.hour = hour
        self.minute = minute
        
        self.title = title
        self.domain = DomainsGateway.shared.determineDomain(for: title)
    }
    
    init(fromEntity entity: HourBlockEntity) {
        self.identifier = entity.identifier!
        self.day = entity.day!
        self.hour = Int(entity.hour)
        self.minute = BlockMinute(rawValue: Int(entity.minute))!
        
        self.title = entity.title
        self.domain = DomainsGateway.shared.determineDomain(for: title)
    }
    
    var formattedTime: String {
        if hour == 0 {
            return "12\(minute.rawValue.getFormattedMinute())AM"
        } else if hour < 12 {
            return "\(hour)\(minute.rawValue.getFormattedMinute())AM"
        } else if hour == 12 {
            return "\(hour)\(minute.rawValue.getFormattedMinute())PM"
        } else {
            return "\(hour - 12)\(minute.rawValue.getFormattedMinute())PM"
        }
    }
    
    @discardableResult
    func getEntity(context: NSManagedObjectContext) -> HourBlockEntity {
        let entity = HourBlockEntity(context: context)
        entity.identifier = identifier
        entity.title = title
        entity.day = day
        entity.hour = Int64(hour)
        entity.minute = Int64(minute.rawValue)
        
        return entity
    }
}

enum BlockMinute: Int {
    
    case oclock = 0
    case fifteen = 1
    case halfPast = 2
    case fourtyFive = 3
}

class HourBlocksStore: ObservableObject {
    
    @Published var todaysBlocks = [HourBlock]()
    @Published var futureBlocks = [HourBlock]()
    
    @Published var currentTitle = ""
    @Published var allDayEvent = ""
    
    init() {
        reloadTodayBlocks()
        reloadFutureBlocks()
    }
    
    func reloadTodayBlocks() {
        todaysBlocks.removeAll()
        
        for hour in 0...23 {
            todaysBlocks.append(HourBlock(day: Date(), hour: hour, minute: .oclock, title: nil))
            todaysBlocks.append(HourBlock(day: Date(), hour: hour, minute: .fifteen, title: nil))
            todaysBlocks.append(HourBlock(day: Date(), hour: hour, minute: .halfPast, title: nil))
            todaysBlocks.append(HourBlock(day: Date(), hour: hour, minute: .fourtyFive, title: nil))
        }
        
        if CalendarGateway.shared.hasPermission() {
            for event in CalendarGateway.shared.importTodaysEvents() {
                for i in event.startingHour...event.endingHour {
                    var block1 = HourBlock(day: Date(), hour: i, minute: .oclock, title: event.title)
                    block1.domain = DomainsGateway.shared.domains["calendar"]
                    syncTodayBlock(block: block1)
                    var block2 = HourBlock(day: Date(), hour: i, minute: .fifteen, title: event.title)
                    block2.domain = DomainsGateway.shared.domains["calendar"]
                    syncTodayBlock(block: block2)
                    var block3 = HourBlock(day: Date(), hour: i, minute: .halfPast, title: event.title)
                    block3.domain = DomainsGateway.shared.domains["calendar"]
                    syncTodayBlock(block: block3)
                    var block4 = HourBlock(day: Date(), hour: i, minute: .fourtyFive, title: event.title)
                    block4.domain = DomainsGateway.shared.domains["calendar"]
                    syncTodayBlock(block: block4)
                }
            }
        }
        
        for entity in DataGateway.shared.getHourBlockEntities() {
            let block = HourBlock(fromEntity: entity)
            
            if Calendar.current.isDateInToday(block.day) {
                syncTodayBlock(block: block)
            } else if block.day < Date() {
                DataGateway.shared.deleteHourBlock(block: block)
            }
        }
        
        self.loadAllDayEvent()
    }
    
    private func loadAllDayEvent() {
        allDayEvent = CalendarGateway.shared.allDayEvent?.title ?? ""
    }
    
    func reloadFutureBlocks() {
        DispatchQueue.global(qos: .userInteractive).async {
            let calendarBlocks: [HourBlock] = CalendarGateway.shared.importFutureEvents().map { event in
                var block = HourBlock(day: event.startDate, hour: 0, minute: .oclock, title: event.title)
                block.domain = DomainsGateway.shared.domains["calendar"]
                
                return block
            }
            
            let storedBlocks: [HourBlock] = DataGateway.shared.getHourBlockEntities().map { entity in
                return HourBlock(fromEntity: entity)
            }.filter { block in !Calendar.current.isDateInToday(block.day) || block.day > Date() }
            
            DispatchQueue.main.async {
                self.futureBlocks = calendarBlocks + storedBlocks
            }
        }
    }
    
    private func syncTodayBlock(block: HourBlock) {
        todaysBlocks[(block.hour * 4) + block.minute.rawValue] = block
    }
    
    func setTodayBlock(for hour: Int, _ minute: BlockMinute, with title: String) {
        let block = HourBlock(day: Date(), hour: hour, minute: minute, title: title)
        
        syncTodayBlock(block: block)
        DataGateway.shared.saveHourBlock(block: block)
        
        if let domainKey = block.domain?.key {
            DataGateway.shared.saveSuggestion(for: domainKey, at: block.hour)
        }
    }
    
    func removeTodayBlock(for hour: Int, _ minute: BlockMinute = .oclock) {
        DataGateway.shared.deleteHourBlock(block: todaysBlocks[(hour * 4) + minute.rawValue])
        syncTodayBlock(block: HourBlock(day: Date(), hour: hour, minute: minute, title: nil))
    }
    
    func addFutureBlock(for date: Date, _ hour: Int, _ minute: BlockMinute = .oclock, with title: String) {
        let block = HourBlock(day: date, hour: hour, minute: minute, title: title)
        
        futureBlocks.append(block)
        DataGateway.shared.saveHourBlock(block: block)
    }
    
    func removeFutureBlock(for block: HourBlock) {
        futureBlocks.removeAll { $0.identifier == block.identifier }
        DataGateway.shared.deleteHourBlock(block: block)
    }
    
    func setReminder(_ status: Bool, for block: HourBlock) {
        for i in 0 ..< todaysBlocks.count {
            if (block.identifier == todaysBlocks[i].identifier) {
                todaysBlocks[i].hasReminder = status
            }
        }
    }
}
