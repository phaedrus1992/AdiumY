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

#import "AIHTTPDownloadValidation.h"
#import "AIPropertyTestUtilities.h"
#import "XtrasInstaller.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/*
 * Issue #268: XtrasInstaller's completion gate (URLSession:task:didCompleteWithError:) keys only on the
 * transport — no error means downloadDidFinish runs and the Xtra is decompressed and installed, no
 * matter how many bytes actually arrived. A truncated download (server cut short, or a lying
 * Content-Length) must be treated as a failure before downloadDidFinish, mirroring the EKEzv check of
 * issue #263.
 */
@interface XtrasInstaller (TestDownloadTruncation)
- (BOOL)downloadWasTruncated;
@end

/* Spy that records which completion path ran instead of showing a modal error sheet or installing. */
@interface TestXtrasInstallerSpy : XtrasInstaller
@property(nonatomic) BOOL didFinishCalled;
@property(nonatomic) BOOL errorCalled;
@property(nonatomic) NSError *presentedError;
@end

@implementation TestXtrasInstallerSpy

- (void)downloadDidFinish
{
	self.didFinishCalled = YES;
}

- (void)presentDownloadError:(NSError *)error
{
	self.errorCalled = YES;
	self.presentedError = error;
}

@end

@interface TestXtrasInstallerDownloadTruncation : XCTestCase
@end

@implementation TestXtrasInstallerDownloadTruncation

- (void)testPredicateShortDownloadTruncates
{
	XtrasInstaller *installer = [[XtrasInstaller alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:50] forKey:@"amountDownloaded"];

	XCTAssertTrue([installer downloadWasTruncated],
				  @"50 of 100 declared bytes is a truncated download and must be flagged (issue #268)");
}

- (void)testPredicateEqualSizeNotTruncated
{
	XtrasInstaller *installer = [[XtrasInstaller alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"amountDownloaded"];

	XCTAssertFalse([installer downloadWasTruncated],
				   @"a download that received its full declared size must not be flagged (issue #268)");
}

- (void)testPredicateOverrunNotTruncated
{
	XtrasInstaller *installer = [[XtrasInstaller alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:150] forKey:@"amountDownloaded"];

	XCTAssertFalse([installer downloadWasTruncated],
				   @"a download that received more than its declared size is not truncated (issue #268)");
}

- (void)testPredicateZeroSizeNeverTruncates
{
	XtrasInstaller *installer = [[XtrasInstaller alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:0] forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:0] forKey:@"amountDownloaded"];

	XCTAssertFalse([installer downloadWasTruncated],
				   @"a zero declared size disables the truncation check (issue #268)");
}

- (void)testPredicateUnknownLengthNeverTruncates
{
	/* NSURLResponseUnknownLength (-1) assigned to the unsigned long long ivar wraps to ULLONG_MAX. */
	XtrasInstaller *installer = [[XtrasInstaller alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:(unsigned long long)NSURLResponseUnknownLength]
				 forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"amountDownloaded"];

	XCTAssertFalse([installer downloadWasTruncated],
				   @"an unknown declared length must disable the truncation check (issue #268)");
}

- (void)testTruncatedDownloadFailsBeforeFinish
{
	TestXtrasInstallerSpy *installer = [[TestXtrasInstallerSpy alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:50] forKey:@"amountDownloaded"];

	[installer URLSession:nil task:nil didCompleteWithError:nil];

	XCTAssertTrue(installer.errorCalled, @"a truncated download must present an error (issue #268)");
	XCTAssertFalse(installer.didFinishCalled, @"a truncated download must not reach downloadDidFinish (issue #268)");
	XCTAssertEqualObjects(installer.presentedError.domain, AIHTTPDownloadErrorDomain,
						  @"a truncated download must surface the shared AIHTTPDownloadErrorDomain (issue #280)");
	XCTAssertEqual(installer.presentedError.code, AIHTTPDownloadErrorTruncated,
				   @"a truncated download must surface AIHTTPDownloadErrorTruncated (issue #280)");
}

- (void)testCompleteDownloadFinishes
{
	TestXtrasInstallerSpy *installer = [[TestXtrasInstallerSpy alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"amountDownloaded"];

	[installer URLSession:nil task:nil didCompleteWithError:nil];

	XCTAssertFalse(installer.errorCalled, @"a complete download must not present an error (issue #268)");
	XCTAssertTrue(installer.didFinishCalled, @"a complete download must proceed to downloadDidFinish (issue #268)");
}

- (void)testUnknownLengthDownloadFinishes
{
	TestXtrasInstallerSpy *installer = [[TestXtrasInstallerSpy alloc] init];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:(unsigned long long)NSURLResponseUnknownLength]
				 forKey:@"downloadSize"];
	[installer setValue:[NSNumber numberWithUnsignedLongLong:100] forKey:@"amountDownloaded"];

	[installer URLSession:nil task:nil didCompleteWithError:nil];

	XCTAssertFalse(installer.errorCalled, @"an unknown-length download must not present an error (issue #268)");
	XCTAssertTrue(installer.didFinishCalled,
				  @"an unknown-length download must proceed to downloadDidFinish (issue #268)");
}

// Property: downloadWasTruncated agrees with the shared validator over the full unsigned domain. The
// predicate delegates to AIHTTPDownloadValidationErrorForTruncatedDownload after casting the unsigned
// ivars to int64_t, so values at or above 2^63 wrap to negative — "no size contract" for a declared
// length, and always-short for a received count against a positive declaration. The oracle applies
// the same casts, locking the wrap boundary as part of the contract; the hand-written unsigned
// comparison this delegation replaced (issue #280) disagreed on exactly that quadrant.
- (void)testPredicateAgreesWithValidatorOverUnsignedDomain
{
	PBTCheckDefault({
		uint64_t const declared = PBTUniformUInt64(UINT64_MAX);
		uint64_t const received = PBTUniformUInt64(UINT64_MAX);

		XtrasInstaller *installer = [[XtrasInstaller alloc] init];
		[installer setValue:[NSNumber numberWithUnsignedLongLong:declared] forKey:@"downloadSize"];
		[installer setValue:[NSNumber numberWithUnsignedLongLong:received] forKey:@"amountDownloaded"];

		NSError *oracleError = AIHTTPDownloadValidationErrorForTruncatedDownload((int64_t)declared, (int64_t)received);
		BOOL expected = (oracleError != nil);
		BOOL truncated = [installer downloadWasTruncated];

		XCTAssertEqual(truncated, expected,
					   @"declared=%llu received=%llu: downloadWasTruncated disagreed with the validator", declared,
					   received);
	});
}

@end
