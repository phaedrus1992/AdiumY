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

// YES iff name's last path component is a real, non-degenerate leaf: non-empty, not ".", "..",
// "/", and not whitespace-only (a name of only whitespace is empty once the OS trims it when
// writing, so the save panel would get no usable default — issue #175).
static NSString *AIHTTPSafeLeafForName(NSString *name)
{
	NSString *leaf = [name lastPathComponent];
	if (leaf == nil || [leaf length] == 0 || [leaf isEqualToString:@"."] ||
		[leaf isEqualToString:@".."] || [leaf isEqualToString:@"/"] ||
		([[leaf stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
			 length] == 0)) {
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
