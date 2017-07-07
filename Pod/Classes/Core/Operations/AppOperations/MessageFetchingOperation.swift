//
//  MessageFetchingOperation.swift
//
//  Created by Andrey K. on 20/06/16.
//

import Foundation
import CoreData

struct MessageFetchingSettings {
	static let messageArchiveLengthDays: Double = 7  // consider messages not older than 7 days
	static let fetchLimit = 100 // consider 100 most recent messages
	static let fetchingIterationLimit = 2 // fetching may trigger message handling, which in turn may trigger message fetching. This constant is here to break possible inifinite recursion.
}

final class MessageFetchingOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: ((MessagesSyncResult) -> Void)?
	var result = MessagesSyncResult.Cancel
	let mmContext: MobileMessaging
	let handlingIteration: Int
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, handlingIteration: Int = 0, finishBlock: ((MessagesSyncResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.handlingIteration = handlingIteration
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Message fetching] Starting operation...")
		guard mmContext.currentUser?.internalId != nil else {
			self.result = MessagesSyncResult.Failure(NSError(type: MMInternalErrorType.NoRegistration))
			finish()
			return
		}
		syncMessages()
	}
	
	private func syncMessages() {
		context.reset()
		context.performAndWait {
			let date = MobileMessaging.date.timeInterval(sinceNow: -60 * 60 * 24 * MessageFetchingSettings.messageArchiveLengthDays)
			
			let nonReportedMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "reportSent == false"), context: self.context)
			let archivedMessages = MessageManagedObject.MM_find(withPredicate: NSPredicate(format: "reportSent == true && creationDate > %@", date as CVarArg), fetchLimit: MessageFetchingSettings.fetchLimit, sortedBy: "creationDate", ascending: false, inContext: self.context)
			
			let nonReportedMessageIds = nonReportedMessages?.map{ $0.messageId }
			let archveMessageIds = archivedMessages?.map{ $0.messageId }
			
			MMLogDebug("[Message fetching] Found \(String(describing: nonReportedMessageIds?.count)) not reported messages. \(String(describing: archivedMessages?.count)) archive messages.")
			
			self.mmContext.remoteApiManager.syncMessages(archiveMsgIds: archveMessageIds, dlrMsgIds: nonReportedMessageIds) { result in
                self.result = result
				self.handleRequestResponse(result: result, nonReportedMessageIds: nonReportedMessageIds) {
					self.finish()
				}
            }
		}
	}

	private func handleRequestResponse(result: MessagesSyncResult, nonReportedMessageIds: [String]?, completion: @escaping () -> Void) {
		context.performAndWait {
			switch result {
			case .Success(let fetchResponse):
				let fetchedMessages = fetchResponse.messages
				MMLogDebug("[Message fetching] succeded: received \(String(describing: fetchedMessages?.count))")
				
				if let nonReportedMessageIds = nonReportedMessageIds {
					self.dequeueDeliveryReports(messageIDs: nonReportedMessageIds, completion: completion)
					MMLogDebug("[Message fetching] delivery report sent for messages: \(nonReportedMessageIds)")
					if !nonReportedMessageIds.isEmpty {
						NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationDeliveryReportSent, userInfo: [MMNotificationKeyDLRMessageIDs: nonReportedMessageIds])
					}
				} else {
					completion()
				}
			case .Failure(_):
				MMLogError("[Message fetching] request failed")
				completion()
			case .Cancel:
				MMLogDebug("[Message fetching] cancelled")
				completion()
			}
		}
	}
	
	private func dequeueDeliveryReports(messageIDs: [String], completion: @escaping () -> Void) {
		guard let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIDs), context: context)
			, !messages.isEmpty else
        {
			completion()
			return
		}
		
		messages.forEach {
			$0.reportSent = true
			$0.deliveryReportedDate = MobileMessaging.date.now
		}
		
		MMLogDebug("[Message fetching] marked as delivered: \(messages.map{ $0.messageId })")
		context.MM_saveToPersistentStoreAndWait()
		
		updateMessageStorage(with: messages, completion: completion)
	}
	
	private func updateMessageStorage(with messages: [MessageManagedObject], completion: @escaping () -> Void) {
		guard let storage = mmContext.messageStorageAdapter, !messages.isEmpty else
		{
			completion()
			return
		}
		
		storage.batchDeliveryStatusUpdate(messages: messages, completion: completion)
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message fetching] finished with errors: \(errors)")

		switch result {
		case .Success(let fetchResponse):
			if let messages = fetchResponse.messages, !messages.isEmpty, handlingIteration < MessageFetchingSettings.fetchingIterationLimit {
				MMLogDebug("[Message fetching] triggering handling for fetched messages \(messages.count)...")
				self.mmContext.messageHandler.handleMTMessages(messages, notificationTapped: false, handlingIteration: handlingIteration + 1, completion: { _ in
					self.finishBlock?(self.result)
				})
			} else {
				fallthrough
			}
		default:
			self.finishBlock?(result)
		}
	}
}
