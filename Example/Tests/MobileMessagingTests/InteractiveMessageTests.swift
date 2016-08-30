//
//  InteractiveMessageTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 08.07.16.
//

import XCTest
@testable import MobileMessaging

class InteractiveMessageTests: XCTestCase {
	
	func messageWithAllActions(_ categoryId: String, buttonId: String) -> [AnyHashable: Any] {
		return
			[
				"messageId": "m1" ,
				"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "category": "\(categoryId)", "badge": 6, "sound": "default"],
				MMAPIKeys.kInternalData:
				[
					    MMAPIKeys.kInteractive:
					    [
							MMAPIKeys.kButtonActions : [ "\(buttonId)" : ["mark_as_seen", "reply"]]
						]
				],
				MMAPIKeys.kCustomPayload: ["customKey": "customValue"]
		    ]
	}

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testHandlersCalled() {
		let buttonId = "apply"
		
		let replyExp = expectation(description: "Reply handler called")
		let mssExp = expectation(description: "Mark as Seen handler called")
		
		MMActionReply.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			mssExp.fulfill()
		}
		
		MMMessage.performAction(identifier: buttonId, userInfo: messageWithAllActions("category", buttonId: buttonId), responseInfo: nil) { () in
			
		}

		
		self.waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testHandlersNotCalledForPredefinedCategory() {
		let buttonId = "reply"
		let replyExp = expectation(description: "Reply handler called")

		MMActionReply.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setActionHandler { (result) in
			XCTFail()
		}
		
		MMActionOpenURL.setActionHandler { (result) in
			XCTFail()
		}
		
		MMMessage.performAction(identifier: buttonId, userInfo: messageWithAllActions("chatMessage", buttonId: buttonId), responseInfo: nil) { () in
			
		}
		
		self.waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testReplyText() {
		let buttonId = "reply"
		let replyText = "Hello world!"
		
		let replyExp = expectation(description: "Reply handler called")
		
		MMActionReply.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			
			if #available(iOS 9.0, *) {
				XCTAssertEqual(result.text, replyText)
			}
			
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setActionHandler { (result) in
			XCTFail()
		}
		
		MMActionOpenURL.setActionHandler { (result) in
			XCTFail()
		}
		
		if #available(iOS 9.0, *) {
			MMMessage.performAction(identifier: buttonId,
			                        userInfo: messageWithAllActions("chatMessage", buttonId: buttonId),
			                        responseInfo: [UIUserNotificationActionResponseTypedTextKey : replyText])
			{ () in
				
			}

		} else {
			MMMessage.performAction(identifier: buttonId, userInfo: messageWithAllActions("chatMessage", buttonId: buttonId), responseInfo: nil) { () in
				
			}
		}
		
		self.waitForExpectations(timeout: 10, handler: nil)
	}
}
