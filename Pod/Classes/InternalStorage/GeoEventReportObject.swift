//
//  GeoEventReportObject.swift
//  
//
//  Created by Andrey K. on 21/10/2016.
//
//

import Foundation
import CoreData


final class GeoEventReportObject: NSManagedObject, Fetchable {

// Insert code here to add functionality to your managed object subclass
	
	class func createEntity(withCampaignId campaignId: String, eventType: String, regionId: String, messageId: String, in context: NSManagedObjectContext) -> GeoEventReportObject {
		let newEvent = GeoEventReportObject.MM_createEntityInContext(context: context)
		newEvent.campaignId = campaignId
		newEvent.eventType = eventType
		newEvent.eventDate = Date()
		newEvent.geoAreaId = regionId
		newEvent.messageId = messageId
		return newEvent
	}
}
