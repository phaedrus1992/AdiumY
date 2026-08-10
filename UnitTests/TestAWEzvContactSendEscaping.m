/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AWEzvContact.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/* Stand-in for the outgoing XML stream that records the exact bytes handed to -sendString: — the
 * wire payload a peer would receive. Injected via KVC so the test compiles without the private
 * header's typed setter. */
@interface TestContactRecordingStream : NSObject
@property(nonatomic, strong) NSString *sentString;
/* The real AWEzvXMLStream exposes a delegate; -[AWEzvContact dealloc] nils it out, so the stand-in
 * must respond to setDelegate: or ARC teardown of the contact raises an unrecognized selector. */
@property(nonatomic, weak) id delegate;
- (void)sendString:(NSString *)string;
@end

@implementation TestContactRecordingStream

- (void)sendString:(NSString *)string
{
	[self setSentString:string];
}

@end

/*
 * Wire-escaping tests for AWEzvContact -sendMessage:withHtml: (issue #259). The text serializer
 * (AWEzvXMLText) escapes & < > exactly once; -sendMessage: must not pre-escape the plaintext or
 * the wire carries a double-escaped body (&amp;amp;). Round-trip property: the peer-visible
 * plaintext (the <body> text after XML decode) equals the sent plaintext.
 */
@interface TestAWEzvContactSendEscaping : XCTestCase
@end

@implementation TestAWEzvContactSendEscaping

- (TestContactRecordingStream *)streamForContact:(AWEzvContact *)contact
{
	TestContactRecordingStream *stream = [[TestContactRecordingStream alloc] init];
	[contact setValue:stream forKey:@"stream"];
	return stream;
}

- (void)testOutboundPlaintextEscapedExactlyOnce
{
	AWEzvContact *contact = [[AWEzvContact alloc] init];
	[contact setUniqueID:@"bob@example.com"];
	[contact setValue:@"127.0.0.1" forKey:@"ipAddr"];
	TestContactRecordingStream *stream = [self streamForContact:contact];

	[contact sendMessage:@"5 < 6 & 7 > 4" withHtml:@"<b>bold</b>"];

	NSString *wire = [stream sentString];
	XCTAssertNotNil(wire, @"a message to a contact with a stream must be written to the wire");
	XCTAssertTrue([wire containsString:@"5 &lt; 6 &amp; 7 &gt; 4"],
				  @"plaintext must be escaped exactly once on the wire (got: %@)", wire);
	XCTAssertFalse([wire containsString:@"&amp;amp;"], @"& must not be double-escaped (got: %@)", wire);
	XCTAssertFalse([wire containsString:@"&amp;lt;"], @"< must not be double-escaped (got: %@)", wire);
	XCTAssertFalse([wire containsString:@"&amp;gt;"], @"> must not be double-escaped (got: %@)", wire);
}

/* Round-trip property: decoding the wire XML recovers the original plaintext, so a peer renders
 * exactly what was sent. */
- (void)testOutboundPlaintextRoundTripsThroughXmlDecode
{
	AWEzvContact *contact = [[AWEzvContact alloc] init];
	[contact setUniqueID:@"bob@example.com"];
	[contact setValue:@"127.0.0.1" forKey:@"ipAddr"];
	TestContactRecordingStream *stream = [self streamForContact:contact];

	NSString *message = @"5 < 6 & 7 > 4";
	[contact sendMessage:message withHtml:@"<b>bold</b>"];

	NSString *wire = [stream sentString];
	NSError *error = nil;
	NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:wire options:0 error:&error];
	XCTAssertNotNil(document, @"serialized message must parse (error %@)", error);
	if (document != nil) {
		NSXMLElement *body = [[[document rootElement] elementsForName:@"body"] firstObject];
		XCTAssertEqualObjects([body stringValue], message, @"the peer-visible plaintext must equal the sent plaintext");
	}
}

@end
