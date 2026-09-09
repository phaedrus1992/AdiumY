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

#import "AWEzvRendezvousData.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <dns_sd.h>

/*
 * -avDataAsDNSTXT and -dataAsTXTRecordRef hex-encode an NSData field value with a loop hardcoded to
 * 20 iterations (issue #340). For a value shorter than 20 bytes this reads past the NSData's own
 * bytes and writes past the `length * 2 + 1`-byte malloc — a heap out-of-bounds read and write. For a
 * value longer than 20 bytes the encoded hex silently truncates. The fix bounds the loop to the
 * value's own length.
 */
@interface TestAWEzvRendezvousDataHexEncoding : XCTestCase
@end

@implementation TestAWEzvRendezvousDataHexEncoding

- (NSString *)expectedHexForData:(NSData *)data
{
	NSMutableString *hex = [NSMutableString stringWithCapacity:[data length] * 2];
	const unsigned char *bytes = [data bytes];
	for (NSUInteger i = 0; i < [data length]; i++) {
		[hex appendFormat:@"%.2x", bytes[i]];
	}
	return hex;
}

/* Extracts the value for "key=" up to the next field separator (\001) or end of string. */
- (NSString *)avTxtValueForKey:(NSString *)key inRecord:(NSString *)record
{
	NSString *marker = [NSString stringWithFormat:@"%@=", key];
	NSRange markerRange = [record rangeOfString:marker];
	XCTAssertNotEqual(markerRange.location, (NSUInteger)NSNotFound, @"field %@ must be present in %@", key, record);
	NSUInteger valueStart = markerRange.location + markerRange.length;
	NSRange separatorRange = [record rangeOfString:@"\001"
										   options:0
											 range:NSMakeRange(valueStart, [record length] - valueStart)];
	NSUInteger valueEnd = (separatorRange.location == NSNotFound) ? [record length] : separatorRange.location;
	return [record substringWithRange:NSMakeRange(valueStart, valueEnd - valueStart)];
}

- (void)assertAvDataAsDNSTXTEncodesData:(NSData *)data
{
	AWEzvRendezvousData *rdata = [[AWEzvRendezvousData alloc] initWithDictionary:@{@"testkey" : data}];
	NSString *value = [self avTxtValueForKey:@"testkey" inRecord:[rdata avDataAsDNSTXT]];
	XCTAssertEqualObjects(value, [self expectedHexForData:data],
						  @"avDataAsDNSTXT must hex-encode the full %lu-byte value, not a fixed 20 bytes",
						  (unsigned long)[data length]);
}

- (void)assertDataAsTXTRecordRefEncodesData:(NSData *)data
{
	AWEzvRendezvousData *rdata = [[AWEzvRendezvousData alloc] initWithDictionary:@{@"testkey" : data}];
	TXTRecordRef record = [rdata dataAsTXTRecordRef];
	uint8_t valueLen = 0;
	const void *valuePtr =
		TXTRecordGetValuePtr(TXTRecordGetLength(&record), TXTRecordGetBytesPtr(&record), "testkey", &valueLen);
	NSString *value = [[NSString alloc] initWithBytes:valuePtr length:valueLen encoding:NSASCIIStringEncoding];
	TXTRecordDeallocate(&record);
	XCTAssertEqualObjects(value, [self expectedHexForData:data],
						  @"dataAsTXTRecordRef must hex-encode the full %lu-byte value, not a fixed 20 bytes",
						  (unsigned long)[data length]);
}

- (void)testAvDataAsDNSTXTEncodesShortValueWithoutOverrun
{
	uint8_t bytes[] = {0x01, 0x02, 0x03};
	[self assertAvDataAsDNSTXTEncodesData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)testAvDataAsDNSTXTEncodesLongValueWithoutTruncation
{
	uint8_t bytes[25];
	for (NSUInteger i = 0; i < sizeof(bytes); i++) {
		bytes[i] = (uint8_t)(i + 1);
	}
	[self assertAvDataAsDNSTXTEncodesData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)testDataAsTXTRecordRefEncodesShortValueWithoutOverrun
{
	uint8_t bytes[] = {0xAA, 0xBB};
	[self assertDataAsTXTRecordRefEncodesData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)testDataAsTXTRecordRefEncodesLongValueWithoutTruncation
{
	uint8_t bytes[25];
	for (NSUInteger i = 0; i < sizeof(bytes); i++) {
		bytes[i] = (uint8_t)(i + 1);
	}
	[self assertDataAsTXTRecordRefEncodesData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

@end
