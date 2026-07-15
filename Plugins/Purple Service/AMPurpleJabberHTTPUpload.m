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

#import "AMPurpleJabberHTTPUpload.h"
#import "ESPurpleJabberAccount.h"
#import <Adium/AIAccount.h>
#import <Adium/AIListContact.h>
#import <Adium/ESFileTransfer.h>
#import <libpurple/jabber.h>

#define NS_HTTP_UPLOAD @"urn:xmpp:http:upload:0"
#define NS_DISCO_ITEMS @"http://jabber.org/protocol/disco#items"
#define NS_DISCO_INFO @"http://jabber.org/protocol/disco#info"

// ponytail: only 3 whitelisted headers per XEP-0363 §3.2
static NSSet *AllowedSlotHeaders(void)
{
	static NSSet *headers = nil;
	if (!headers) {
		headers = [[NSSet alloc] initWithObjects:@"Authorization", @"Cookie", @"Expires", nil];
	}
	return headers;
}

static NSString *ContentTypeForFile(NSString *path)
{
	NSString *ext = [[path pathExtension] lowercaseString];
	if ([ext isEqualToString:@"png"])
		return @"image/png";
	if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"])
		return @"image/jpeg";
	if ([ext isEqualToString:@"gif"])
		return @"image/gif";
	if ([ext isEqualToString:@"pdf"])
		return @"application/pdf";
	if ([ext isEqualToString:@"txt"])
		return @"text/plain";
	if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"])
		return @"text/html";
	if ([ext isEqualToString:@"xml"])
		return @"application/xml";
	if ([ext isEqualToString:@"zip"])
		return @"application/zip";
	if ([ext isEqualToString:@"mp3"])
		return @"audio/mpeg";
	if ([ext isEqualToString:@"mp4"])
		return @"video/mp4";
	if ([ext isEqualToString:@"mov"])
		return @"video/quicktime";
	return @"application/octet-stream";
}

#pragma mark - Class Extension

@interface AMPurpleJabberHTTPUpload () <NSURLSessionTaskDelegate>

- (void)_sendDiscoveryItems;
- (void)_sendDiscoveryInfoForJID:(NSString *)jid;
- (void)_handleDiscoveryItemsResult:(xmlnode *)query;
- (void)_handleDiscoveryInfoResult:(xmlnode *)query from:(NSString *)fromJID;
- (void)_handleSlotResult:(xmlnode *)slot;
- (void)_doUpload;
- (void)_sendShareMessage;
- (void)_handleUploadFailure:(NSString *)reason;
- (void)_cleanupUpload;

@end

#pragma mark - C Callback

static void AMPurpleJabberHTTPUpload_received_data_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {
		@try {
			AMPurpleJabberHTTPUpload *self = (__bridge AMPurpleJabberHTTPUpload *)data;
			xmlnode *node = *packet;

			if (!node || !gc || !self) {
				return;
			}

			// Only process IQ stanzas
			if (strcmp(node->name, "iq") != 0) {
				return;
			}

			const char *type = xmlnode_get_attrib(node, "type");
			if (!type) {
				return;
			}

			const char *iq_id = xmlnode_get_attrib(node, "id");
			if (!iq_id) {
				return;
			}

			NSString *idStr = @(iq_id);

			// Handle discovery items result
			if (self->_discoveryItemsID && [self->_discoveryItemsID isEqualToString:idStr]) {
				if (strcmp(type, "result") == 0) {
					xmlnode *query = xmlnode_get_child_with_namespace(node, "query", NS_DISCO_ITEMS.UTF8String);
					if (query) {
						[self _handleDiscoveryItemsResult:query];
					}
				} else if (strcmp(type, "error") == 0) {
					AILog(@"AMPurpleJabberHTTPUpload: Discovery items query failed for id=%s", iq_id);
					self->_discoveryInfoIDs = nil;
				}
				self->_discoveryItemsID = nil;
				return;
			}

			// Handle discovery info results
			if (self->_discoveryInfoIDs && [self->_discoveryInfoIDs containsObject:idStr]) {
				if (strcmp(type, "result") == 0) {
					xmlnode *query = xmlnode_get_child_with_namespace(node, "query", NS_DISCO_INFO.UTF8String);
					if (query) {
						const char *from = xmlnode_get_attrib(node, "from");
						if (from) {
							[self _handleDiscoveryInfoResult:query from:@(from)];
						}
					}
				}
				[self->_discoveryInfoIDs removeObject:idStr];
				if ([self->_discoveryInfoIDs count] == 0) {
					AILog(@"AMPurpleJabberHTTPUpload: No HTTP Upload service found after probing all items");
					self->_discoveryInfoIDs = nil;
				}
				return;
			}

			// Handle slot request result
			if (self->_slotQueryID && [self->_slotQueryID isEqualToString:idStr]) {
				if (strcmp(type, "result") == 0) {
					xmlnode *slot = xmlnode_get_child_with_namespace(node, "slot", NS_HTTP_UPLOAD.UTF8String);
					if (slot) {
						[self _handleSlotResult:slot];
					} else {
						AILog(@"AMPurpleJabberHTTPUpload: Slot response missing <slot> element");
						[self _handleUploadFailure:@"Slot response missing <slot> element"];
					}
				} else if (strcmp(type, "error") == 0) {
					// Try to extract error text for better diagnostics
					xmlnode *errorNode = xmlnode_get_child(node, "error");
					const char *errorText = NULL;
					if (errorNode) {
						xmlnode *text = xmlnode_get_child_with_namespace(
							errorNode, "text", @"urn:ietf:params:xml:ns:xmpp-stanzas".UTF8String);
						if (text && text->child && (text->child->type == XMLNODE_TYPE_DATA)) {
							errorText = text->child->data;
						}
					}
					NSString *reason = errorText ? @(errorText) : @"Slot request rejected by server";
					AILog(@"AMPurpleJabberHTTPUpload: Slot request failed: %@", reason);
					[self _handleUploadFailure:reason];
				}
				self->_slotQueryID = nil;
				return;
			}

		} @catch (NSException *e) {
			AILog(@"AMPurpleJabberHTTPUpload: Exception in received_data_cb: %@", e);
		}
	}
}

#pragma mark - Implementation

@implementation AMPurpleJabberHTTPUpload

#pragma mark - Lifecycle

- (id)initWithAccount:(ESPurpleJabberAccount *)account
{
	if ((self = [super init])) {
		_account = account;
		_maxFileSize = -1; // unknown until discovered

		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber) {
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", (__bridge void *)self,
								  PURPLE_CALLBACK(AMPurpleJabberHTTPUpload_received_data_cb), (__bridge void *)self);
			AILog(@"AMPurpleJabberHTTPUpload: Connected to jabber-receiving-xmlnode signal");
		}
	}
	return self;
}

- (void)dealloc
{
	purple_signals_disconnect_by_handle((__bridge void *)self);
	[_session invalidateAndCancel];
}

#pragma mark - Public

- (void)startDiscovery
{
	// Already discovered or in progress
	if (_uploadServiceJID || _discoveryItemsID) {
		return;
	}

	_maxFileSize = -1;
	[self _sendDiscoveryItems];
}

- (BOOL)isUploadAvailableForFileSize:(unsigned long long)fileSize
{
	if (!_uploadServiceJID) {
		return NO;
	}
	if (_maxFileSize > 0 && (long long)fileSize > _maxFileSize) {
		return NO;
	}
	return YES;
}

- (BOOL)sendFileTransfer:(ESFileTransfer *)fileTransfer
{
	if (!_uploadServiceJID) {
		return NO;
	}

	// Don't start if we're already handling a transfer
	if (_activeFileTransfer || _slotQueryID) {
		return NO;
	}

	_activeFileTransfer = fileTransfer;
	[self _requestSlotForTransfer:fileTransfer];
	return YES;
}

#pragma mark - Private: Discovery

- (void)_sendDiscoveryItems
{
	NSString *domain = [self _serverDomain];
	if (!domain) {
		AILog(@"AMPurpleJabberHTTPUpload: No server domain available for discovery");
		return;
	}

	NSString *queryID = [NSString stringWithFormat:@"httpupload-disc-items-%x", arc4random()];
	_discoveryItemsID = queryID;

	// Allocate the set for tracking disco#info queries
	_discoveryInfoIDs = [[NSMutableSet alloc] init];

	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (!gc) {
		AILog(@"AMPurpleJabberHTTPUpload: Connection gone, skipping discovery items");
		_discoveryItemsID = nil;
		_discoveryInfoIDs = nil;
		return;
	}

	NSString *iq = [NSString stringWithFormat:@"<iq type='get' id='%@' to='%@'>"
											  @"<query xmlns='%@'/>"
											  @"</iq>",
											  queryID, domain, NS_DISCO_ITEMS];

	jabber_prpl_send_raw(gc, [iq UTF8String], -1);
	AILog(@"AMPurpleJabberHTTPUpload: Sent discovery items query to %@", domain);
}

- (void)_sendDiscoveryInfoForJID:(NSString *)jid
{
	NSString *queryID = [NSString stringWithFormat:@"httpupload-disc-info-%x", arc4random()];
	[_discoveryInfoIDs addObject:queryID];

	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (!gc) {
		[_discoveryInfoIDs removeObject:queryID];
		if ([_discoveryInfoIDs count] == 0) {
			_discoveryInfoIDs = nil;
		}
		return;
	}

	NSString *iq = [NSString stringWithFormat:@"<iq type='get' id='%@' to='%@'>"
											  @"<query xmlns='%@'/>"
											  @"</iq>",
											  queryID, jid, NS_DISCO_INFO];

	jabber_prpl_send_raw(gc, [iq UTF8String], -1);
	AILog(@"AMPurpleJabberHTTPUpload: Sent discovery info query to %@", jid);
}

- (void)_handleDiscoveryItemsResult:(xmlnode *)query
{
	// Iterate over <item> children
	for (xmlnode *item = query->child; item; item = item->next) {
		if (item->type != XMLNODE_TYPE_TAG || strcmp(item->name, "item") != 0) {
			continue;
		}
		const char *jid = xmlnode_get_attrib(item, "jid");
		if (jid) {
			[self _sendDiscoveryInfoForJID:@(jid)];
		}
	}
}

- (void)_handleDiscoveryInfoResult:(xmlnode *)query from:(NSString *)fromJID
{
	// Check for the HTTP Upload feature
	for (xmlnode *child = query->child; child; child = child->next) {
		if (child->type != XMLNODE_TYPE_TAG || strcmp(child->name, "feature") != 0) {
			continue;
		}
		const char *var = xmlnode_get_attrib(child, "var");
		if (var && strcmp(var, [NS_HTTP_UPLOAD UTF8String]) == 0) {
			// Found the upload service
			_uploadServiceJID = fromJID;

			// Try to extract max-file-size from data form
			xmlnode *x = xmlnode_get_child_with_namespace(query, "x", [@"jabber:x:data" UTF8String]);
			if (x) {
				for (xmlnode *field = x->child; field; field = field->next) {
					if (field->type != XMLNODE_TYPE_TAG || strcmp(field->name, "field") != 0) {
						continue;
					}
					const char *var = xmlnode_get_attrib(field, "var");
					if (var && strcmp(var, "max-file-size") == 0) {
						xmlnode *valueNode = xmlnode_get_child(field, "value");
						if (valueNode && valueNode->child && (valueNode->child->type == XMLNODE_TYPE_DATA)) {
							_maxFileSize = atoll((const char *)valueNode->child->data);
						}
					}
				}
			}

			AILog(@"AMPurpleJabberHTTPUpload: Found upload service at %@ (max size: %lld)", fromJID, _maxFileSize);

			// Clean up remaining discovery state
			_discoveryInfoIDs = nil;
			return;
		}
	}
}

- (NSString *)_serverDomain
{
	NSString *uid = [_account UID];
	NSRange atRange = [uid rangeOfString:@"@"];
	if (atRange.location == NSNotFound || atRange.location + 1 >= [uid length]) {
		return nil;
	}
	return [uid substringFromIndex:atRange.location + 1];
}

#pragma mark - Private: Slot Request

- (void)_requestSlotForTransfer:(ESFileTransfer *)fileTransfer
{
	NSString *filename = [[fileTransfer localFilename] lastPathComponent];
	unsigned long long fileSize = [fileTransfer size];
	NSString *contentType = ContentTypeForFile([fileTransfer localFilename]);

	NSString *queryID = [NSString stringWithFormat:@"httpupload-slot-%x", arc4random()];
	_slotQueryID = queryID;

	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (!gc) {
		[self _handleUploadFailure:@"Connection lost during slot request"];
		return;
	}

	// XML-escape the filename to prevent injection
	NSString *escapedFilename = [self _xmlEscape:filename];

	NSString *iq =
		[NSString stringWithFormat:@"<iq type='get' id='%@' to='%@'>"
								   @"<request xmlns='%@' filename='%@' size='%llu' content-type='%@'/>"
								   @"</iq>",
								   queryID, _uploadServiceJID, NS_HTTP_UPLOAD, escapedFilename, fileSize, contentType];

	jabber_prpl_send_raw(gc, [iq UTF8String], -1);
	AILog(@"AMPurpleJabberHTTPUpload: Requested slot for %@ (%llu bytes) from %@", filename, fileSize,
		  _uploadServiceJID);
}

- (void)_handleSlotResult:(xmlnode *)slot
{
	// Extract <put url='...'>
	xmlnode *putNode = xmlnode_get_child(slot, "put");
	if (!putNode) {
		[self _handleUploadFailure:@"Slot response missing <put> element"];
		return;
	}
	const char *putURLStr = xmlnode_get_attrib(putNode, "url");
	if (!putURLStr) {
		[self _handleUploadFailure:@"Slot response <put> missing url attribute"];
		return;
	}

	// Parse whitelisted <header> children from <put> (XEP-0363 §3.2)
	NSMutableDictionary *headers = [NSMutableDictionary dictionary];
	for (xmlnode *child = putNode->child; child; child = child->next) {
		if (child->type != XMLNODE_TYPE_TAG || strcmp(child->name, "header") != 0) {
			continue;
		}
		const char *nameAttr = xmlnode_get_attrib(child, "name");
		const char *valueAttr = xmlnode_get_attrib(child, "value");
		if (nameAttr && valueAttr) {
			NSString *name = @(nameAttr);
			if ([AllowedSlotHeaders() containsObject:name]) {
				[headers setObject:@(valueAttr) forKey:name];
			}
		}
	}
	if ([headers count] > 0) {
		_putHeaders = [headers copy];
	}

	// Extract <get url='...'>
	xmlnode *getNode = xmlnode_get_child(slot, "get");
	if (!getNode) {
		[self _handleUploadFailure:@"Slot response missing <get> element"];
		return;
	}
	const char *getURLStr = xmlnode_get_attrib(getNode, "url");
	if (!getURLStr) {
		[self _handleUploadFailure:@"Slot response <get> missing url attribute"];
		return;
	}

	NSURL *putURL = [NSURL URLWithString:@(putURLStr)];
	NSURL *getURL = [NSURL URLWithString:@(getURLStr)];

	if (!putURL || !getURL) {
		[self _handleUploadFailure:@"Slot response contained invalid URLs"];
		return;
	}

	_putURL = putURL;
	_getURL = getURL;

	AILog(@"AMPurpleJabberHTTPUpload: Got slot: PUT %@ -> GET %@", _putURL, _getURL);

	// Clean up slot query state before upload
	_slotQueryID = nil;

	[self _doUpload];
}

#pragma mark - Private: HTTP Upload

- (void)_doUpload
{
	if (!_putURL || !_activeFileTransfer) {
		[self _handleUploadFailure:@"Missing upload parameters"];
		return;
	}

	NSString *localPath = [_activeFileTransfer localFilename];
	if (!localPath) {
		[self _handleUploadFailure:@"File transfer has no local filename"];
		return;
	}

	// Build the PUT request with slot headers
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_putURL];
	[request setHTTPMethod:@"PUT"];

	// Don't allow ATS exceptions per design decision
	// ATS will block http:// URLs as required

	// Set Content-Type from the transfer's content type (we already sent it in the slot request)
	NSString *contentType = ContentTypeForFile(localPath);
	[request setValue:contentType forHTTPHeaderField:@"Content-Type"];

	// Content-Length is derived from the file
	unsigned long long fileSize = [_activeFileTransfer size];
	[request setValue:[NSString stringWithFormat:@"%llu", fileSize] forHTTPHeaderField:@"Content-Length"];

	// Forward whitelisted headers from the slot response (XEP-0363 §3.2)
	for (NSString *headerName in _putHeaders) {
		[request setValue:[_putHeaders objectForKey:headerName] forHTTPHeaderField:headerName];
	}

	NSURL *fileURL = [NSURL fileURLWithPath:localPath];

	// Create the session for this upload
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
	_session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];

	NSURLSessionUploadTask *task = [_session uploadTaskWithRequest:request fromFile:fileURL];
	[task resume];

	AILog(@"AMPurpleJabberHTTPUpload: Uploading %@ to %@", localPath, _putURL);
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
						task:(NSURLSessionTask *)task
			 didSendBodyData:(int64_t)bytesSent
			  totalBytesSent:(int64_t)totalBytesSent
	totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
	if (!_activeFileTransfer) {
		return;
	}

	// Update progress on the main thread
	ESFileTransfer *ft = _activeFileTransfer;
	if (totalBytesExpectedToSend > 0) {
		CGFloat percent = (CGFloat)totalBytesSent / (CGFloat)totalBytesExpectedToSend;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (![ft isStopped]) {
				[ft setPercentDone:percent bytesSent:(unsigned long long)totalBytesSent];
			}
		});
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	if (error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _handleUploadFailure:[NSString stringWithFormat:@"Upload failed: %@", [error localizedDescription]]];
		});
		return;
	}

	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
	NSInteger statusCode = [httpResponse statusCode];

	if (statusCode == 201) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _sendShareMessage];
		});
	} else {
		NSString *msg = [NSString stringWithFormat:@"Upload returned HTTP %ld", (long)statusCode];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _handleUploadFailure:msg];
		});
	}
}

#pragma mark - Private: Success / Failure

- (void)_sendShareMessage
{
	if (!_activeFileTransfer) {
		[self _cleanupUpload];
		return;
	}

	AIListContact *contact = [_activeFileTransfer contact];
	NSString *bareJID = [contact UID];
	if (!bareJID) {
		[self _handleUploadFailure:@"File transfer has no contact"];
		return;
	}

	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (!gc) {
		[self _handleUploadFailure:@"Connection lost after upload"];
		return;
	}

	NSString *body = [_getURL absoluteString];

	NSString *message =
		[NSString stringWithFormat:@"<message to='%@' type='chat'>"
								   @"<body>%@</body>"
								   @"<x xmlns='jabber:x:oob'><url>%@</url></x>"
								   @"</message>",
								   [self _xmlEscape:bareJID], [self _xmlEscape:body], [self _xmlEscape:body]];

	jabber_prpl_send_raw(gc, [message UTF8String], -1);
	AILog(@"AMPurpleJabberHTTPUpload: Sent share message for %@", body);

	[_activeFileTransfer setRemoteFilename:body];
	[_activeFileTransfer setStatus:Complete_FileTransfer];

	[self _cleanupUpload];
}

- (void)_handleUploadFailure:(NSString *)reason
{
	AILog(@"AMPurpleJabberHTTPUpload: Failure: %@", reason);

	if (_activeFileTransfer && ![_activeFileTransfer isStopped]) {
		[_activeFileTransfer setStatus:Failed_FileTransfer];
		// Set remote filename to the error for diagnostic visibility
		[_activeFileTransfer setRemoteFilename:reason];
	}

	[self _cleanupUpload];
}

- (void)_cleanupUpload
{
	_slotQueryID = nil;
	_activeFileTransfer = nil;
	_putHeaders = nil;
	_getURL = nil;
	_putURL = nil;
	[_session invalidateAndCancel];
	_session = nil;
}

#pragma mark - Private: Helpers

- (NSString *)_xmlEscape:(NSString *)str
{
	if (!str) {
		return @"";
	}
	NSMutableString *result = [str mutableCopy];
	[result replaceOccurrencesOfString:@"&"
							withString:@"&amp;"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [result length])];
	[result replaceOccurrencesOfString:@"<"
							withString:@"&lt;"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [result length])];
	[result replaceOccurrencesOfString:@">"
							withString:@"&gt;"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [result length])];
	[result replaceOccurrencesOfString:@"'"
							withString:@"&apos;"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [result length])];
	[result replaceOccurrencesOfString:@"\""
							withString:@"&quot;"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [result length])];
	return result;
}

@end
