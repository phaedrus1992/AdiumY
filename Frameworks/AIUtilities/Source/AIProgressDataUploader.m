//
//  AIProgressDataUploader.m
//  Adium
//
//  Created by Zachary West on 2009-05-27.
//
// Copyright (c) 2004-2006 Lukhnos D. Liu (lukhnos {at} gmail.com)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Neither the name of ObjectiveFlickr nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "AIProgressDataUploader.h"

#define TIMEOUT_INTERVAL 30.0

@interface AIProgressDataUploader () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@end

@implementation AIProgressDataUploader
/*!
 * @brief Create a data uploader.
 *
 * @param delegate The delegate
 * @param context The context for this upload
 *
 * Uploading does not begin until -upload is called.
 */
+ (id)dataUploaderWithData:(NSData *)uploadData
					   URL:(NSURL *)url
				   headers:(NSDictionary *)headers
				  delegate:(id<AIProgressDataUploaderDelegate>)delegate
				   context:(id)context
{
	return [[self alloc] initWithData:uploadData URL:url headers:headers delegate:delegate context:context];
}

- (id)initWithData:(NSData *)inUploadData
			   URL:(NSURL *)inURL
		   headers:(NSDictionary *)inHeaders
		  delegate:(id<AIProgressDataUploaderDelegate>)inDelegate
		   context:(id)inContext
{
	if ((self = [super init])) {
		uploadData = inUploadData;
		delegate = inDelegate;
		context = inContext;
		url = inURL;
		headers = inHeaders;
	}

	return self;
}

- (void)dealloc
{
	[session invalidateAndCancel];
}

/*!
 * @brief Begin the upload.
 *
 * Immediately begins the upload.
 */
- (void)upload
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:uploadData];

	for (NSString *headerKey in headers) {
		[request setValue:[headers objectForKey:headerKey] forHTTPHeaderField:headerKey];
	}

	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
	[configuration setTimeoutIntervalForRequest:TIMEOUT_INTERVAL];
	[configuration setTimeoutIntervalForResource:TIMEOUT_INTERVAL];

	session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];

	returnedData = [[NSMutableData alloc] init];
	totalSize = [uploadData length];

	uploadTask = [session uploadTaskWithRequest:request fromData:uploadData];
	[uploadTask resume];
}

/*!
 * @brief Cancel the upload.
 *
 * Cancels the upload and returns no further status messages to the delegate.
 */
- (void)cancel
{
	[uploadTask cancel];
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)theSession
				  task:(NSURLSessionTask *)task
		didSendBodyData:(int64_t)bytesSentDelta
		 totalBytesSent:(int64_t)totalBytesSent
	totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
	if (totalBytesSent > bytesSent) {
		bytesSent = totalBytesSent;

		[delegate updateUploadProgress:(NSUInteger)bytesSent total:(NSUInteger)totalSize context:context];
	}
}

- (void)URLSession:(NSURLSession *)theSession task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	[theSession invalidateAndCancel];

	if (error != nil) {
		if ([error code] != NSURLErrorCancelled) {
			[delegate uploadFailed:context];
		}
	} else {
		[delegate uploadCompleted:context result:returnedData];
	}
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)theSession
			  dataTask:(NSURLSessionDataTask *)dataTask
		didReceiveData:(NSData *)data
{
	[returnedData appendData:data];
}

@end
