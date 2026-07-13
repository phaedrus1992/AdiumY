#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <XCTest/XCTest.h>

@interface AIUtilitiesCoverageSmokeTest : XCTestCase
@end

@implementation AIUtilitiesCoverageSmokeTest

- (void)testStringUUID
{
	NSString *uuid = [NSString uuid];
	XCTAssertNotNil(uuid);
	XCTAssertTrue([uuid length] > 0);
}

- (void)testStringEllipsis
{
	NSString *ellipsis = [NSString ellipsis];
	XCTAssertNotNil(ellipsis);
	XCTAssertEqualObjects(ellipsis, @"\u2026");
}

- (void)testStringCompactedString
{
	NSString *input = @"hello   world";
	NSString *compacted = [input compactedString];
	XCTAssertNotNil(compacted);
	XCTAssertFalse([compacted containsString:@"  "]);
}

- (void)testStringRandomString
{
	NSString *random = [NSString randomStringOfLength:12];
	XCTAssertNotNil(random);
	XCTAssertEqual([random length], 12U);
}

- (void)testStringIsCaseInsensitivelyEqual
{
	NSString *a = @"Hello";
	XCTAssertTrue([a isCaseInsensitivelyEqualToString:@"hello"]);
	XCTAssertFalse([a isCaseInsensitivelyEqualToString:@"world"]);
}

- (void)testArrayContainsObjectIdenticalTo
{
	NSArray *arr = @[ @"a", @"b", @"c" ];
	XCTAssertTrue([arr containsObjectIdenticalTo:@"b"]);
	XCTAssertFalse([arr containsObjectIdenticalTo:@"d"]);
}

- (void)testArrayValidateAsPropertyList
{
	NSArray *valid = @[ @"a", @{@"key" : @"val"}, @(1) ];
	XCTAssertTrue([valid validateAsPropertyList]);
}

- (void)testStringWithCGFloat
{
	CGFloat val = 3.14159;
	NSString *str = [NSString stringWithCGFloat:val maxDigits:2];
	XCTAssertNotNil(str);
	XCTAssertTrue([str length] > 0);
}

- (void)testStringAllLines
{
	NSString *multi = @"line1\nline2\nline3";
	NSArray *lines = [multi allLines];
	XCTAssertEqual([lines count], 3U);
	XCTAssertEqualObjects(lines[0], @"line1");
}

@end
