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

NSString *AIHTTPDownloadSafeSaveName(NSString *remotePath, NSString *fallbackName)
{
	if (remotePath == nil) {
		return fallbackName;
	}

	NSString *lastPathComponent = [remotePath lastPathComponent];
	if (lastPathComponent == nil || [lastPathComponent length] == 0 || [lastPathComponent isEqualToString:@"."] ||
		[lastPathComponent isEqualToString:@".."] || [lastPathComponent isEqualToString:@"/"] ||
		// A name of only whitespace is empty once the OS trims it when writing; treat it as
		// degenerate too so the save panel gets a usable default (issue #175).
		([[lastPathComponent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
			 length] == 0)) {
		return fallbackName;
	}

	return lastPathComponent;
}
