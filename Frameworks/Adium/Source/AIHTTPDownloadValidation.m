/*
 * Adium is the property of its developers, whose names are listed in the copyright file included
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
#import <AIUtilities/AIStringUtilities.h>

NSString *const AIHTTPDownloadErrorDomain = @"AIHTTPDownloadErrorDomain";

static NSError *AIHTTPDownloadValidationError(AIHTTPDownloadErrorCode code, NSString *reason)
{
	return [NSError errorWithDomain:AIHTTPDownloadErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : reason}];
}

NSError *AIHTTPDownloadValidationErrorForResponse(NSURLResponse *response)
{
	if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
		return AIHTTPDownloadValidationError(
			AIHTTPDownloadErrorNotHTTP,
			AILocalizedStringFromTable(@"Response is not HTTP; refusing to save.", nil, nil));
	}

	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
	NSInteger statusCode = [httpResponse statusCode];
	if (statusCode < 200 || statusCode > 299) {
		return AIHTTPDownloadValidationError(
			AIHTTPDownloadErrorBadStatus,
			[NSString stringWithFormat:AILocalizedStringFromTable(@"HTTP status %ld; refusing to save.", nil, nil),
									   (long)statusCode]);
	}

	return nil;
}

NSError *AIHTTPDownloadValidationErrorForTruncatedDownload(int64_t declaredLength, int64_t receivedBytes)
{
	// A non-positive declared length — including the unknown sentinel NSURLResponseUnknownLength
	// (-1) — carries no size contract: there is nothing to compare received bytes against, so a
	// short body is indistinguishable from a complete one (issue #263's declared==0 guard).
	if (declaredLength <= 0) {
		return nil;
	}

	if (receivedBytes < declaredLength) {
		return AIHTTPDownloadValidationError(
			AIHTTPDownloadErrorTruncated,
			[NSString stringWithFormat:AILocalizedStringFromTable(
										   @"Download was truncated: received %lld of %lld declared bytes.", nil, nil),
									   (long long)receivedBytes, (long long)declaredLength]);
	}

	return nil;
}

NSData *AIHTTPDownloadValidationSyncFetch(NSURLRequest *request, NSURLResponse **outResponse, NSError **outError)
{
	if (request == nil || [request URL] == nil) {
		/* A nil or URL-less request must not reach dataTaskWithRequest:, which returns nil and
		 * leaves the semaphore below unwoken forever (issue #273). */
		if (outResponse != nil) {
			*outResponse = nil;
		}
		if (outError != nil) {
			*outError = [NSError
				errorWithDomain:NSURLErrorDomain
						   code:NSURLErrorBadURL
					   userInfo:@{
						   NSLocalizedDescriptionKey : AILocalizedStringFromTable(@"The request has no URL.", nil, nil)
					   }];
		}
		return nil;
	}

	__block NSData *resultData = nil;
	__block NSURLResponse *resultResponse = nil;
	__block NSError *resultError = nil;
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	NSURLSessionDataTask *task =
		[[NSURLSession sharedSession] dataTaskWithRequest:request
										completionHandler:^(NSData *data, NSURLResponse *urlResponse, NSError *error) {
											resultData = data;
											resultResponse = urlResponse;
											resultError = error;
											dispatch_semaphore_signal(semaphore);
										}];
	[task resume];

	/* Bound the wait at the request's own timeoutInterval: a stalled request must never park the
	 * calling thread indefinitely, so the wait times out and surfaces a timeout error instead
	 * (issue #273). The data task runs on a background queue, so the wait only parks the caller
	 * thread. */
	dispatch_time_t waitUntil = dispatch_time(DISPATCH_TIME_NOW, (int64_t)([request timeoutInterval] * NSEC_PER_SEC));
	if (dispatch_semaphore_wait(semaphore, waitUntil) != 0) {
		[task cancel];
		/* The completion handler is still running on the session's background queue and can
		 * overwrite resultData/resultResponse/resultError at any moment, so write the out-params
		 * directly and return without reading those __block locals — touching them here would race
		 * the handler. A successful wait, by contrast, happens-after the handler ran and signaled,
		 * so its writes are visible to the reads below. */
		if (outResponse != nil) {
			*outResponse = nil;
		}
		if (outError != nil) {
			*outError = [NSError
				errorWithDomain:NSURLErrorDomain
						   code:NSURLErrorTimedOut
					   userInfo:@{
						   NSLocalizedDescriptionKey : AILocalizedStringFromTable(@"The request timed out.", nil, nil)
					   }];
		}
		return nil;
	}

	if (outResponse != nil) {
		*outResponse = resultResponse;
	}
	if (outError != nil) {
		*outError = resultError;
	}
	return resultData;
}

// YES iff name's last path component is a real, non-degenerate leaf: non-empty, not ".", "..",
// "/", and not whitespace-only (a name of only whitespace is empty once the OS trims it when
// writing, so the save panel would get no usable default — issue #175).
static NSString *AIHTTPSafeLeafForName(NSString *name)
{
	NSString *leaf = [name lastPathComponent];
	if (leaf == nil || [leaf length] == 0 || [leaf isEqualToString:@"."] || [leaf isEqualToString:@".."] ||
		[leaf isEqualToString:@"/"] ||
		([[leaf stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)) {
		return nil;
	}
	return leaf;
}

NSString *AIHTTPDownloadSafeSaveName(NSString *remotePath, NSString *fallbackName)
{
	NSString *safeName = AIHTTPSafeLeafForName(remotePath);
	if (safeName != nil) {
		return safeName;
	}

	// The fallback must satisfy the same leaf-safety contract, not pass through verbatim: a
	// degenerate fallback (empty, ".", "..", whitespace, or a path with separators) yields @""
	// — the rejection sentinel the file-transfer callers rely on to fail the transfer — rather
	// than a name that could escape the download folder (issues #175, #181).
	safeName = AIHTTPSafeLeafForName(fallbackName);
	return (safeName != nil) ? safeName : @"";
}
