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

#import "EKEzvIncomingFileTransfer.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

/*
 * downloadFolder:path:url: creates each directory as it walks the peer-supplied tree. When a later
 * child fails (invalid name, depth cap), the directories created before the failure were left on
 * disk (issue #191). The walk must remove what it created on failure, leaving the temp root empty.
 */
@interface TestEKEzvIncomingFileTransferFolderCleanup : XCTestCase
@end

@implementation TestEKEzvIncomingFileTransferFolderCleanup

- (NSXMLElement *)dirElementNamed:(NSString *)name
{
	NSXMLElement *dir = [[NSXMLElement alloc] initWithName:@"dir"];
	NSXMLElement *nameElement = [[NSXMLElement alloc] initWithName:@"name"];
	[nameElement setStringValue:name];
	[dir addChild:nameElement];
	return dir;
}

/* Root <dir> "a" containing a nested <dir> whose name is invalid (".."). The walk creates
 * <tempRoot>/a, then fails validating the inner name; the created directory must be removed. */
- (void)testInvalidChildNameRemovesCreatedDirectories
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvFolderCleanupInvalidName"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	NSXMLElement *outer = [self dirElementNamed:@"a"];
	[outer addChild:[self dirElementNamed:@".."]];

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"];

	XCTAssertFalse(result, @"a nested <dir> with an invalid name must fail the transfer");
	NSString *createdDir = [tempRoot stringByAppendingPathComponent:@"a"];
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:createdDir],
				   @"directories created before the failing child must be removed");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* A tree nested past the depth cap creates dirs level-1..level-32 before failing at level-33. All
 * created directories must be removed, leaving the temp root empty. */
- (void)testDepthCapFailureRemovesCreatedDirectories
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvFolderCleanupDepthCap"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	NSXMLElement *node = [self dirElementNamed:@"level-1"];
	NSXMLElement *outer = node;
	for (NSUInteger i = 2; i <= 40; i++) {
		NSXMLElement *child = [self dirElementNamed:[NSString stringWithFormat:@"level-%lu", (unsigned long)i]];
		[node addChild:child];
		node = child;
	}

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	BOOL result = [transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"];

	XCTAssertFalse(result, @"folder tree nested past the depth cap must fail the transfer");
	NSArray *remaining = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempRoot error:NULL];
	XCTAssertEqual([remaining count], (NSUInteger)0, @"no directories may be left behind after a depth-cap failure");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/*
 * Issue #248: the #191 cleanup only covers the synchronous folder walk. A transfer that fails or is
 * cancelled after downloads have started leaves its partial file(s) and the created folder tree on
 * disk. The destination (single file or root folder), every in-progress download path, and the
 * created directory tree must all be removed on cancel and on async download error.
 */

/* Cancel must remove the in-flight partial file, the created folder tree, and the destination root.
 * The walk creates <tempRoot>/a and tracks it; a KVC-set downloadPaths simulates an in-flight task
 * whose partial file lives under that tree. */
- (void)testCancelDownloadRemovesPartialFilesAndCreatedDirectories
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvAsyncCancelCleanup"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];

	NSXMLElement *outer = [self dirElementNamed:@"a"];
	XCTAssertTrue([transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"],
				  @"a single valid <dir> child must complete the folder walk");

	NSString *partialFile = [tempRoot stringByAppendingPathComponent:@"a/partial.bin"];
	[[NSFileManager defaultManager] createFileAtPath:partialFile contents:[NSData data] attributes:nil];
	[transfer setValue:[@{@"fake-task" : partialFile} mutableCopy] forKey:@"downloadPaths"];

	[transfer cancelDownload];

	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:partialFile],
				   @"the partial file of a cancelled download must be removed");
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[tempRoot stringByAppendingPathComponent:@"a"]],
				   @"the created folder tree must be removed on cancel");
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempRoot],
				   @"the transfer destination must be removed on cancel");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* An async download error (via the session delegate callback) must remove the same artifacts: the
 * failed task's partial file, the created folder tree, and the destination root. */
- (void)testDownloadErrorRemovesPartialFilesAndCreatedDirectories
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvAsyncErrorCleanup"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];

	NSXMLElement *outer = [self dirElementNamed:@"a"];
	XCTAssertTrue([transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"],
				  @"a single valid <dir> child must complete the folder walk");

	NSString *partialFile = [tempRoot stringByAppendingPathComponent:@"a/partial.bin"];
	[[NSFileManager defaultManager] createFileAtPath:partialFile contents:[NSData data] attributes:nil];
	[transfer setValue:[@{@"fake-task" : partialFile} mutableCopy] forKey:@"downloadPaths"];

	NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil];
	/* The delegate method must not see a nil task (removeObjectForKey:nil throws); the real
	 * callback always passes a live task, so use a non-nil stand-in. */
	NSURLSessionDataTask *dummyTask = (NSURLSessionDataTask *)[[NSObject alloc] init];
	[transfer URLSession:nil task:dummyTask didCompleteWithError:error];

	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:partialFile],
				   @"the partial file of a failed download must be removed");
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[tempRoot stringByAppendingPathComponent:@"a"]],
				   @"the created folder tree must be removed on download error");
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempRoot],
				   @"the transfer destination must be removed on download error");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/*
 * Issue #260: the #248 cleanup runs on cancel and on failure, but nothing guards the success side —
 * a cancel issued after the transfer has fully received its file deletes the received artifacts.
 * Completion state must make a late cancel a no-op so a successful transfer is never cleaned up.
 */

/* Drive the transfer to successful completion (didCompleteWithError: with no error, full byte
 * count), then cancel. The received file, created folder tree, and destination root must survive. */
- (void)testCancelAfterSuccessfulDownloadLeavesFileOnDisk
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvCancelAfterSuccess"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];

	NSXMLElement *outer = [self dirElementNamed:@"a"];
	XCTAssertTrue([transfer downloadFolder:outer path:tempRoot url:@"http://example.com/base"],
				  @"a single valid <dir> child must complete the folder walk");

	NSString *receivedFile = [tempRoot stringByAppendingPathComponent:@"a/received.bin"];
	[[NSFileManager defaultManager] createFileAtPath:receivedFile contents:[NSData data] attributes:nil];

	/* Make the transfer believe it has received the full announced size. */
	[transfer setValue:[NSNumber numberWithLongLong:100] forKey:@"bytesReceived"];
	[transfer setSize:100];

	/* The success path reads [[dataTask originalRequest] URL], so the task must be a real
	 * NSURLSessionDataTask (a bare NSObject stand-in has no originalRequest). */
	NSURLSession *session =
		[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	NSURLSessionDataTask *task = [session
		dataTaskWithRequest:[NSURLRequest
								requestWithURL:[NSURL URLWithString:@"http://example.com/base/a/received.bin"]]];
	[transfer URLSession:nil task:task didCompleteWithError:nil];

	[transfer cancelDownload];

	XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:receivedFile],
				  @"a late cancel after a completed download must leave the received file on disk");
	XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[tempRoot stringByAppendingPathComponent:@"a"]],
				  @"a late cancel after a completed download must leave the folder tree intact");
	XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tempRoot],
				  @"a late cancel after a completed download must leave the destination root intact");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

@end
