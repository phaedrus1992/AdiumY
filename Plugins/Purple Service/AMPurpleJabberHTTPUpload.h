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

#import <Foundation/Foundation.h>

@class ESPurpleJabberAccount, ESFileTransfer;

NS_ASSUME_NONNULL_BEGIN

@interface AMPurpleJabberHTTPUpload : NSObject {
	ESPurpleJabberAccount *_account;

	// Discovery state
	NSString *_discoveryItemsID;
	NSMutableSet *_discoveryInfoIDs;
	NSString *_uploadServiceJID;
	long long _maxFileSize;

	// Slot request state
	NSString *_slotQueryID;

	// Upload state
	ESFileTransfer *_activeFileTransfer;
	NSDictionary *_putHeaders;
	NSURL *_getURL;
	NSURL *_putURL;
	NSURLSession *_session;
}

/// Initialize with the owning Jabber account.
///
/// @param account The ESPurpleJabberAccount that owns this controller
/// @return An initialized instance
- (id)initWithAccount:(ESPurpleJabberAccount *)account;

/// Begin service discovery against the server domain.
///
/// Sends a disco#items query to the domain, then probes each item for the
/// urn:xmpp:http:upload:0 feature. Results are stored internally for subsequent
/// upload requests. Safe to call multiple times — subsequent calls are no-ops
/// once discovery is in progress or complete.
- (void)startDiscovery;

/// Check whether an HTTP Upload service has been discovered and can handle the given file size.
///
/// @param fileSize The size of the file to upload in bytes
/// @return YES if an upload service was found and \c fileSize does not exceed the
///         service's max-file-size limit (or no limit was advertised)
- (BOOL)isUploadAvailableForFileSize:(unsigned long long)fileSize;

/// Start an HTTP Upload for the given file transfer.
///
/// Requests a slot from the upload service, then uploads the file to the returned
/// PUT URL. On success the GET URL is sent as a chat message to the transfer's
/// contact. Only one transfer can be active at a time.
///
/// @param fileTransfer The file transfer to upload
/// @return YES if the upload was queued, NO if no service is available or a
///         transfer is already in progress
- (BOOL)sendFileTransfer:(ESFileTransfer *)fileTransfer;

@end

NS_ASSUME_NONNULL_END
