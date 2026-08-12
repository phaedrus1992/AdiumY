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

#import "AIPropertyTestUtilities.h"
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

/* Filters a string to the XML-valid, round-trippable text-content domain. Control characters below
 * 0x20 are not representable as XML text, and \r is normalized to \n by every XML processor, so both
 * are dropped — PBTRandomUnicodeString can generate them, and they are not the escaper's concern.
 * Unlike attribute values, \n and \t survive text content intact, so they are kept. */
- (NSString *)xmlTextValidCopy:(NSString *)string
{
	NSMutableString *valid = [NSMutableString stringWithCapacity:[string length]];
	for (NSUInteger i = 0; i < [string length]; i++) {
		unichar character = [string characterAtIndex:i];
		if (character == '\n' || character == '\t' ||
			((character >= 0x20 && character <= 0xD7FF) || (character >= 0xE000 && character <= 0xFFFD))) {
			[valid appendString:[NSString stringWithCharacters:&character length:1]];
		}
	}
	return [valid copy];
}

/* Property: the wire round-trip is a bijection up to the <br> → <br /> normalization. For every
 * XML-valid plaintext, the peer-visible <body> text (after NSXMLDocument decode) equals the
 * normalized sent text — the serializer escapes & < > exactly once, and decoding recovers the
 * original, so nothing is double-escaped (issue #259). Mirrors the attribute-value property tests
 * but over the text path -sendMessage:withHtml: writes. */
- (void)assertPlaintextRoundTrip:(NSString *)message
{
	/* Whitespace-only plaintext cannot round-trip through this decode step: NSXMLDocument (options:0)
	 * drops whitespace-only text nodes, so <body> </body> decodes to "". Such a message carries no
	 * escapable characters — the single-escape property has nothing to pin — so it is excluded from
	 * the domain here, the same way xmlTextValidCopy: excludes unrepresentable control characters. */
	if ([[message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
		return;
	}

	AWEzvContact *contact = [[AWEzvContact alloc] init];
	[contact setUniqueID:@"bob@example.com"];
	[contact setValue:@"127.0.0.1" forKey:@"ipAddr"];
	TestContactRecordingStream *stream = [self streamForContact:contact];

	[contact sendMessage:message withHtml:@"<b>bold</b>"];

	NSString *wire = [stream sentString];
	NSError *error = nil;
	NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:wire options:0 error:&error];
	XCTAssertNotNil(document, @"serialized message must parse (message %@, error %@)", message, error);
	if (document != nil) {
		NSXMLElement *body = [[[document rootElement] elementsForName:@"body"] firstObject];
		NSString *expected = [message stringByReplacingOccurrencesOfString:@"<br>"
																withString:@"<br />"
																   options:NSCaseInsensitiveSearch
																	 range:NSMakeRange(0, [message length])];
		XCTAssertEqualObjects([body stringValue], expected,
							  @"decoded plaintext must equal the normalized sent text (message %@)", message);
	}
}

/* ASCII values guarantee the escapable & < > characters appear, pinning single-escape. */
- (void)testOutboundPlaintextRoundTripsOverRandomASCII
{
	PBTCheckDefault({ [self assertPlaintextRoundTrip:PBTRandomASCIIString(64)]; });
}

/* Unicode values cover multi-byte and combining marks; the printable range rarely includes the
 * escapable characters, so the ASCII test above carries the escaping weight. */
- (void)testOutboundPlaintextRoundTripsOverRandomUnicode
{
	PBTCheckDefault({ [self assertPlaintextRoundTrip:[self xmlTextValidCopy:PBTRandomUnicodeString(64)]]; });
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
