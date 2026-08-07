/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AIContentMessage class for the contact-alert plugin TUs to compile without an AdiumY.framework
 * binary. Only the messageInChat:withSource:destination:date:message:autoreply: factory is used.
 */
#import <Foundation/Foundation.h>

#import <AdiumY/AIChat.h>
#import <AdiumY/AIContentObject.h>

#define CONTENT_MESSAGE_TYPE @"Message"

@interface AIContentMessage : AIContentObject
+ (id)messageInChat:(AIChat *)inChat
		 withSource:(id)inSource
		destination:(id)inDest
			   date:(NSDate *)inDate
			message:(NSAttributedString *)inMessage
		  autoreply:(BOOL)inAutoreply;
@end
