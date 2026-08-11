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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The domain for errors returned by AIHTTPDownloadValidationErrorForResponse.
FOUNDATION_EXPORT NSString *const AIHTTPDownloadErrorDomain;

/// Reasons a remote file download was rejected before committing to the destination
/// (issues #175, #176, #177).
typedef NS_ENUM(NSInteger, AIHTTPDownloadErrorCode) {
	/// The response was not an NSHTTPURLResponse at all.
	AIHTTPDownloadErrorNotHTTP = 1,
	/// The HTTP status was outside 2xx.
	AIHTTPDownloadErrorBadStatus,
	/// The received bytes fell short of the declared Content-Length (issues #263, #273).
	AIHTTPDownloadErrorTruncated,
};

/// Validates an NSURLSession response before committing a downloaded file to a destination
/// path. Returns nil when the response is acceptable (an NSHTTPURLResponse with a 2xx status),
/// or an NSError in AIHTTPDownloadErrorDomain describing the rejection.
///
/// @param response The NSURLSession response, possibly nil.
/// @return nil when acceptable; an error describing the violated check otherwise.
NSError *_Nullable AIHTTPDownloadValidationErrorForResponse(NSURLResponse *_Nullable response);

/// Rejects a download whose received byte count falls short of the declared Content-Length.
/// Returns nil when there is no size contract to enforce — an unknown declared length
/// (NSURLResponseUnknownLength, -1) or a non-positive one — so a server that omits
/// Content-Length is not treated as truncated (issue #263's declared==0 guard). Any separate
/// cap on absolute size (e.g. AIWKMaxRemoteImageDownloadBytes) is the caller's to enforce.
///
/// @param declaredLength The response's expectedContentLength, possibly NSURLResponseUnknownLength.
/// @param receivedBytes The actual number of bytes received.
/// @return nil when acceptable; an NSError in AIHTTPDownloadErrorDomain with code
///         AIHTTPDownloadErrorTruncated when receivedBytes < declaredLength (issue #273).
NSError *_Nullable AIHTTPDownloadValidationErrorForTruncatedDownload(int64_t declaredLength, int64_t receivedBytes);

/// Returns a safe default name for a network-provided filename or path: the path's last path
/// component, unless that is empty, ".", "..", "/", or whitespace-only (a degenerate name that
/// would point a save panel at a directory or be silently discarded). `fallbackName` is then
/// used subject to the same leaf-safety rule; a degenerate `fallbackName` yields @"" (the
/// rejection sentinel callers use to fail the transfer) rather than passing through verbatim.
///
/// @param remotePath The remote filename or path, possibly nil.
/// @param fallbackName The name to use when `remotePath` has no usable last component.
/// @return A single non-degenerate leaf name: `remotePath`'s last path component, else
///         `fallbackName`'s last path component, else @"".
NSString *AIHTTPDownloadSafeSaveName(NSString *_Nullable remotePath, NSString *fallbackName);

NS_ASSUME_NONNULL_END
