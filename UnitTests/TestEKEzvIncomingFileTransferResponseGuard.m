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
 * Issue #252: URLSession:dataTask:didReceiveResponse:completionHandler: can be called for a task
 * after the transfer has already failed or been cancelled. A concurrent failure's cleanup (issue
 * #248) removes the task's path from downloadPaths, so fileHandleForWritingAtPath: returns nil and
 * -[NSMutableDictionary setObject:forKey:] raises NSInvalidArgumentException (a crash). The delegate
 * must reject late responses: cancel them, and never create the destination file or insert a nil
 * handle.
 */
/* NSMutableDictionary copies its keys — empirically setObject:forKey: invokes copyWithZone: — and a
 * plain NSObject has no copyWithZone:, so a raw NSObject cannot be a dictionary key. This stand-in
 * returns self from copyWithZone:, so the dictionary's key-copy keeps the same instance and
 * objectForKey: round-trips (like an immutable Cocoa value class). */
@interface EKEzvResponseGuardTask : NSObject <NSCopying>
@end

@implementation EKEzvResponseGuardTask

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end

@interface TestEKEzvIncomingFileTransferResponseGuard : XCTestCase
@end

@implementation TestEKEzvIncomingFileTransferResponseGuard

- (NSHTTPURLResponse *)okResponse
{
	return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com/file.bin"]
									   statusCode:200
									  HTTPVersion:@"HTTP/1.1"
									 headerFields:@{}];
}

/* A response arriving after the transfer already failed must be rejected: the completion handler
 * receives cancel and no destination file is created. */
- (void)testResponseAfterTransferFailedIsCancelled
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvResponseGuardFailed"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:tempRoot
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];
	NSString *destFile = [tempRoot stringByAppendingPathComponent:@"file.bin"];

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];
	[transfer setValue:@YES forKey:@"transferFailed"];

	EKEzvResponseGuardTask *dummyTask = [[EKEzvResponseGuardTask alloc] init];
	/* The transfer already failed, so the task's path is still registered — only the
	 * transferFailed guard may reject this response. */
	NSMutableDictionary *paths = [[NSMutableDictionary alloc] init];
	[paths setObject:destFile forKey:dummyTask];
	[transfer setValue:paths forKey:@"downloadPaths"];
	[transfer setValue:[[NSMutableDictionary alloc] init] forKey:@"downloadFileHandles"];

	__block NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;
	[transfer URLSession:nil
				  dataTask:dummyTask
		didReceiveResponse:[self okResponse]
		 completionHandler:^(NSURLSessionResponseDisposition d) {
			 disposition = d;
		 }];

	XCTAssertEqual(disposition, NSURLSessionResponseCancel,
				   @"a response for a transfer that already failed must be rejected");
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:destFile],
				   @"no destination file may be created after the transfer failed");

	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];
}

/* A response for a task whose path was already removed by a concurrent failure's cleanup must not
 * crash on a nil file handle; the response is rejected. */
- (void)testResponseForRemovedTaskDoesNotCrash
{
	NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"EKEzvResponseGuardRemoved"];
	[[NSFileManager defaultManager] removeItemAtPath:tempRoot error:NULL];

	EKEzvIncomingFileTransfer *transfer = [[EKEzvIncomingFileTransfer alloc] init];
	[transfer setLocalFilename:tempRoot];

	EKEzvResponseGuardTask *dummyTask = [[EKEzvResponseGuardTask alloc] init];
	/* The task is deliberately absent from downloadPaths, as after a concurrent cleanup. */
	[transfer setValue:[[NSMutableDictionary alloc] init] forKey:@"downloadPaths"];
	[transfer setValue:[[NSMutableDictionary alloc] init] forKey:@"downloadFileHandles"];

	__block NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;
	[transfer URLSession:nil
				  dataTask:dummyTask
		didReceiveResponse:[self okResponse]
		 completionHandler:^(NSURLSessionResponseDisposition d) {
			 disposition = d;
		 }];

	XCTAssertEqual(disposition, NSURLSessionResponseCancel,
				   @"a response for an unknown task must be rejected, not accepted");
}

@end
