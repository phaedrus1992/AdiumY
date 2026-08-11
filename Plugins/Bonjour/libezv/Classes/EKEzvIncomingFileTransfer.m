//
//  EKEzvIncomingFileTransfer.m
//  Adium
//
//  Created by Erich Kreutzer on 8/14/07.
//

#import "EKEzvIncomingFileTransfer.h"
#import "AWEzv.h"
#import "AWEzvContactManager.h"
#import "AWEzvSupportRoutines.h"
#import <AdiumY/AIHTTPDownloadValidation.h>
#import <Cocoa/Cocoa.h>
#import <errno.h>
#import <sys/xattr.h>

#define APPLE_SINGLE_HEADER_LENGTH 26
#define APPLE_SINGLE_MAGIC_NUMBER 0x00051600
#define APPLE_SINGLE_VERSION_NUMBER 0x00020000

/* Maximum nesting depth for a peer-supplied folder tree in downloadFolder:path:url:depth:.
 * Past this the <dir> recursion would be unbounded, so the transfer fails instead (issue #187). */
#define EKEZVFOLDER_MAX_DEPTH 32

#define AS_ENTRY_DATA_FORK 1
#define AS_ENTRY_RESOURCE_FORK 2
#define AS_ENTRY_REAL_NAME 3
#define AS_ENTRY_COMMENT 4
#define AS_ENTRY_ICON_BW 5
#define AS_ENTRY_ICON_COLOR 6
#define AS_ENTRY_DATE_INFO 8
#define AS_ENTRY_FINDER_INFO 9
#define AS_ENTRY_MACINTOSH_FILE_INFO 10
#define AS_ENTRY_PRODOS_FILE_INFO 11
#define AS_ENTRY_MSDOS_FILE_INFO 12
#define AS_ENTRY_AFP_SHORT_NAME 13
#define AS_ENTRY_AFP_FILE_INFO 14
#define AS_ENTRY_AFP_DIRECTORY_ID 15

struct AppleSingleHeader {
	UInt32 magicNumber;
	UInt32 versionNumber;
	char filler[16];
	UInt16 numberEntries;
};
typedef struct AppleSingleHeader AppleSingleHeader;

struct AppleSingleEntry {
	UInt32 entryID;
	UInt32 offset;
	UInt32 length;
};
typedef struct AppleSingleEntry AppleSingleEntry;

struct AppleSingleFinderInfo {
	struct FileInfo finderInfo;
	struct FXInfo extendedFinderInfo;
};
typedef struct AppleSingleFinderInfo AppleSingleFinderInfo;

@interface EKEzvIncomingFileTransfer () {
	/* Directories created by the in-progress downloadFolder:path:url:depth: walk. On failure
	 * the walk removes them (deepest first) so no partial folder tree is left on disk (#191). */
	NSMutableArray *createdDirectories;
	/* Set once any failure or cancel path has run, so -dealloc can remove partial artifacts without
	 * ever deleting a successfully-received transfer (issue #248). */
	BOOL transferFailed;
	/* Set once the transfer is fully received and accepted, so a late -cancelDownload or -dealloc
	 * never removes artifacts of a transfer the user owns (issue #260). */
	BOOL transferSucceeded;
	/* Accumulated AppleSingle envelope overhead (header + entry table + Finder info) subtracted from
	 * bytesReceived by -transferWasTruncated, so a truncated raw body cannot hide behind envelope
	 * bytes (issue #269). A resource-fork-only/dual-fork body counts its whole content as overhead and
	 * can false-positive a truncation; that is pathological for EZV and fails loudly on untrusted data. */
	unsigned long long appleSingleEnvelopeBytes;
}
- (bool)downloadFolder:(NSXMLElement *)root path:(NSString *)rootPath url:(NSString *)rootURL depth:(NSUInteger)depth;
- (bool)downloadChildElements:(NSXMLElement *)dir path:(NSString *)path url:(NSString *)url depth:(NSUInteger)depth;
- (void)removeCreatedDirectories;
- (void)removePartialTransferArtifacts;
- (void)failTransfer;
- (BOOL)transferWasTruncated;
@end

@implementation EKEzvIncomingFileTransfer
#pragma mark Downloading

- (void)dealloc
{
	[downloadSession invalidateAndCancel];
	if (!transferSucceeded) {
		/* Safety net (issues #248, #265): a transfer released before it was marked succeeded must
		 * not leave partial files or the created folder tree on disk. Covers both the failed-but-
		 * cleanup-ran case and a transfer released mid-flight whose downloads never completed or
		 * failed. A successful transfer's received files are never removed (issue #260). The client
		 * is not notified from dealloc: reporting here would hand the deallocating transfer to the
		 * manager/client chain, which may itself be tearing down — unsafe under ARC. Removing the
		 * partial artifacts is the leak this closes. */
		[self removePartialTransferArtifacts];
	}
}
- (void)startDownload
{
	currentDownloads = [[NSMutableArray alloc] initWithCapacity:10];
	encodedDownloads = [[NSMutableArray alloc] initWithCapacity:10];
	downloadPaths = [[NSMutableDictionary alloc] initWithCapacity:10];
	downloadFileHandles = [[NSMutableDictionary alloc] initWithCapacity:10];
	if (type == EKEzvFile_Transfer) {
		[self downloadFile];
	} else if (type == EKEzvDirectory_Transfer) {
		[self downloadFolder];
	} else {
		[[[manager client] client] reportError:@"Don't know what type of item we are downloading" ofLevel:AWEzvError];
		[self failTransfer];
	}
}

- (void)cancelDownload
{
	if (transferSucceeded) {
		/* A completed transfer's received artifacts belong to the user; a late cancel is a no-op
		 * (issue #260). */
		return;
	}
	if ([currentDownloads count] > 0) {
		NSURLSessionDataTask *download;
		for (download in currentDownloads) {
			[download cancel];
		}
		currentDownloads = nil;
		encodedDownloads = nil;
	}
	[downloadSession invalidateAndCancel];
	downloadSession = nil;
	/* A cancelled transfer must not leave its partial files or the created folder tree on disk
	 * (issue #248). */
	transferFailed = YES;
	[self removePartialTransferArtifacts];
}
- (void)downloadFolder
{
	/*We need to first get the xml for the layout */
	NSURL *URL = [NSURL URLWithString:url];
	if (URL == nil) {
		/* A peer-supplied base URL that does not parse must fail the transfer loudly rather than
		 * hand nil to initWithContentsOfURL:, which raises NSInvalidArgumentException (variant of
		 * issue #264 found in pre-PR review). */
		[[[[self manager] client] client]
			reportError:[NSString stringWithFormat:@"Could not download transfer because its URL is invalid: %@", url]
				ofLevel:AWEzvError];
		[self failTransfer];
		return;
	}
	NSError *error = nil;
	NSXMLDocument *documentRoot = [[NSXMLDocument alloc] initWithContentsOfURL:URL options:0 error:&error];
	if (error) {
		[[[[self manager] client] client] reportError:[error localizedDescription] ofLevel:AWEzvError];
		[self failTransfer];
		return;
	}
	/*NO error so we have the xml */
	NSXMLElement *root = [documentRoot rootElement];
	/*We don't care about the root name because the user can rename it*/
	NSString *posixFlags = [[root attributeForName:@"posixflags"] objectValue];

	NSFileManager *fileManager = [NSFileManager defaultManager];

	BOOL isDirectory = NO;
	BOOL exists = [fileManager fileExistsAtPath:localFilename isDirectory:&isDirectory];
	if (exists && isDirectory) {
		/*We need to remove this file*/
		if (![fileManager removeItemAtPath:localFilename error:NULL]) {
			[[[[self manager] client] client] reportError:@"Could not replace old file at path" ofLevel:AWEzvError];
			[self failTransfer];
			return;
		}
	}

	if (![fileManager createDirectoryAtPath:localFilename
				withIntermediateDirectories:YES
								 attributes:[self posixAttributesFromString:posixFlags]
									  error:NULL]) {
		[[[[self manager] client] client]
			reportError:@"There was an error creating the root directory for the file tranfer"
				ofLevel:AWEzvError];
		[self failTransfer];
		return;
	}

	bool folderSuccess = YES;
	bool fileSuccess = YES;

	itemsToDownload = [NSMutableDictionary dictionaryWithCapacity:10];
	permissionsToApply = [[NSMutableDictionary alloc] initWithCapacity:10];

	/*Call downloadFolder:path:url: for dir children */
	for (NSXMLElement *nextElement in [root elementsForName:@"dir"]) {
		folderSuccess = [self downloadFolder:nextElement path:localFilename url:[self url]] && folderSuccess;
	}

	/*Call downloadFolder:path:url: for file children */
	for (NSXMLElement *nextElement in [root elementsForName:@"file"]) {
		fileSuccess = [self downloadFolder:nextElement path:localFilename url:[self url]] && fileSuccess;
	}

	if (folderSuccess && fileSuccess) {

		/*Now go through itemsToDownload and download the files*/
		NSURL *downloadURL;
		for (NSString *path in [itemsToDownload keyEnumerator]) {
			/* code that uses the returned key */
			downloadURL = [itemsToDownload valueForKey:path];
			if (downloadURL) {
				[self downloadURL:downloadURL toPath:path];
				downloadURL = nil;
			} else {
				[[[[self manager] client] client]
					reportError:[NSString stringWithFormat:@"Error downloading file from %@ to %@", downloadURL, path]
						ofLevel:AWEzvError];
				[self failTransfer];
			}
		}

	} else {
		[self failTransfer];
	}
}
- (bool)downloadFolder:(NSXMLElement *)root path:(NSString *)rootPath url:(NSString *)rootURL
{
	/* Child URLs are built by appending path components to the base URL, so a query or fragment on the
	 * peer-supplied base would be concatenated into every child's path and silently mis-address the
	 * files (issue #270). Reject such a base before walking; the #264 guard only catches URLs that are
	 * unparseable, not mangled-but-parseable ones. rootComponents nil (unparseable) falls through to
	 * the #264 guard rather than erroring twice. The check lives in this walk entry — once per
	 * top-level element, not in the recursive walk — so a bad base fails the transfer loudly without
	 * reporting once per nested child. */
	NSURLComponents *rootComponents = [NSURLComponents componentsWithString:rootURL];
	if (rootComponents != nil && ([rootComponents query] != nil || [rootComponents fragment] != nil)) {
		[[[[self manager] client] client]
			reportError:@"Could not download transfer because its base URL contains a query or fragment."
				ofLevel:AWEzvError];
		return NO;
	}
	bool success = [self downloadFolder:root path:rootPath url:rootURL depth:1];
	if (!success) {
		/* The walk failed partway: remove every directory it created so no partial folder tree
		 * is left on disk (issue #191). */
		[self removeCreatedDirectories];
	}
	return success;
}
- (bool)downloadFolder:(NSXMLElement *)root path:(NSString *)rootPath url:(NSString *)rootURL depth:(NSUInteger)depth
{
	/*Helper method to recursively download a folder using the xml*/
	/*root will be the current folder or file to download */
	/*rootPath will be the path -without- root's name appended */
	/*A peer-supplied tree must not nest deeper than EKEZVFOLDER_MAX_DEPTH; past the cap the <dir>
	 * recursion would be unbounded, so fail the whole transfer rather than descending (issue #187).*/
	if (depth > EKEZVFOLDER_MAX_DEPTH) {
		[[[[self manager] client] client] reportError:@"Could not download transfer because it is nested too deeply."
											  ofLevel:AWEzvError];
		return NO;
	}
	if ([[root name] isEqualToString:@"file"]) {
		/*We have a file so get it's info and then download it*/
		//	NSString *mimeType = [[root attributeForName:@"mimetype"] objectValue];
		NSString *posixFlags = [[root attributeForName:@"posixflags"] objectValue];
		//	NSString *hfsFlags = [[root attributeForName:@"hfsflags"] objectValue];
		//	NSString *size = [[root attributeForName:@"size"] objectValue];

		NSArray *nameChildren = [root elementsForName:@"name"];
		if ([nameChildren count] == 0) {
			[[[[self manager] client] client] reportError:@"Could not download file because there is no name"
												  ofLevel:AWEzvError];
			return NO;
		}
		NSString *name = [[nameChildren objectAtIndex:0] stringValue];
		// A peer-supplied name must not escape the transfer directory: reduce it to a single leaf
		// and reject degenerate names (empty, ".", "..", whitespace) by failing the transfer
		// (issue #181). The @"" fallback doubles as a rejection sentinel: keep it empty so unsafe
		// names fail the length check below instead of receiving a default name.
		NSString *safeName = AIHTTPDownloadSafeSaveName(name, @"");
		if ([safeName length] == 0) {
			[[[[self manager] client] client] reportError:@"Could not download file because its name is invalid."
												  ofLevel:AWEzvError];
			return NO;
		}
		NSString *newPath = [rootPath stringByAppendingPathComponent:safeName];
		NSString *newURL =
			[rootURL stringByAppendingPathComponent:[safeName stringByAddingPercentEncodingWithAllowedCharacters:
																  [NSCharacterSet URLPathAllowedCharacterSet]]];

		/*Download file to newPath from newURL*/
		NSURL *downloadURL = [NSURL URLWithString:newURL];
		if (downloadURL == nil) {
			/* A child whose combined URL does not parse must fail the transfer loudly, matching the
			 * invalid-name and depth-cap paths, rather than silently dropping the file — the nil URL
			 * stored by setValue:forKey: would remove the entry with no error (issue #264). */
			[[[[self manager] client] client]
				reportError:[NSString
								stringWithFormat:@"Could not download file %@ because its URL is invalid.", newURL]
					ofLevel:AWEzvError];
			return NO;
		}
		[itemsToDownload setValue:downloadURL forKey:newPath];
		[permissionsToApply setValue:[self posixAttributesFromString:posixFlags] forKey:newPath];

		return YES;

	} else if ([[root name] isEqualToString:@"dir"]) {
		/*We have a directory so crete the directory then recursively create the files/dirs */
		NSString *posixFlags = [[root attributeForName:@"posixflags"] objectValue];

		/*Find the name of the directory*/
		NSArray *nameChildren = [root elementsForName:@"name"];
		if ([nameChildren count] == 0) {
			[[[[self manager] client] client] reportError:@"Could not download directory because there was no name."
												  ofLevel:AWEzvError];
			return NO;
		}
		NSString *name = [[nameChildren objectAtIndex:0] stringValue];
		// A peer-supplied name must not escape the transfer directory: reduce it to a single leaf
		// and reject degenerate names (empty, ".", "..", whitespace) by failing the transfer
		// (issue #181). The @"" fallback doubles as a rejection sentinel: keep it empty so unsafe
		// names fail the length check below instead of receiving a default name.
		NSString *safeName = AIHTTPDownloadSafeSaveName(name, @"");
		if ([safeName length] == 0) {
			[[[[self manager] client] client] reportError:@"Could not download directory because its name is invalid."
												  ofLevel:AWEzvError];
			return NO;
		}

		/* Create the directory */
		NSFileManager *defaultManager = [NSFileManager defaultManager];
		NSString *newPath = [rootPath stringByAppendingPathComponent:safeName];

		if (![defaultManager createDirectoryAtPath:newPath
					   withIntermediateDirectories:YES
										attributes:[self posixAttributesFromString:posixFlags]
											 error:NULL]) {
			[[[[self manager] client] client] reportError:@"Could not create directory for transfer."
												  ofLevel:AWEzvError];

			return NO;
		}

		/* Track the created directory so a later failure in this walk can remove it (#191). */
		if (createdDirectories == nil) {
			createdDirectories = [[NSMutableArray alloc] initWithCapacity:4];
		}
		[createdDirectories addObject:newPath];

		/* Now call downloadFolder for dir and file children */
		NSString *newURL =
			[rootURL stringByAppendingPathComponent:[safeName stringByAddingPercentEncodingWithAllowedCharacters:
																  [NSCharacterSet URLPathAllowedCharacterSet]]];

		return [self downloadChildElements:root path:newPath url:newURL depth:depth];
	} else {
		[[[[self manager] client] client]
			reportError:@"Error, attempting to download something which is not a directory or a file."
				ofLevel:AWEzvError];

		return NO;
	}
}
- (bool)downloadChildElements:(NSXMLElement *)dir path:(NSString *)path url:(NSString *)url depth:(NSUInteger)depth
{
	bool folderSuccess = YES;
	bool fileSuccess = YES;

	for (NSXMLElement *nextElement in [dir elementsForName:@"dir"]) {
		folderSuccess = [self downloadFolder:nextElement path:path url:url depth:depth + 1] && folderSuccess;
	}
	for (NSXMLElement *nextElement in [dir elementsForName:@"file"]) {
		fileSuccess = [self downloadFolder:nextElement path:path url:url depth:depth + 1] && fileSuccess;
	}
	return fileSuccess && folderSuccess;
}
- (void)removeCreatedDirectories
{
	/* Remove the directories this walk created, deepest first, so no partial folder tree
	 * survives a failed transfer (issue #191). A path already gone is expected; any other removal
	 * failure is logged so a leftover tree is not silently ignored. */
	for (NSString *path in [createdDirectories reverseObjectEnumerator]) {
		NSError *error = nil;
		if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error] && error != nil &&
			[error code] != NSFileNoSuchFileError) {
			AWEzvLog(@"Could not remove created directory %@: %@", path, [error localizedDescription]);
		}
	}
	createdDirectories = nil;
}
- (void)removePartialTransferArtifacts
{
	/* A failed or cancelled transfer must not leave partial files, the created folder tree, or the
	 * destination (single file or root folder) on disk (issue #248). Remove every in-progress
	 * download path, then the created directory tree, then the transfer's own destination. The
	 * destination covers the just-failed task's own partial file, whose path is removed from
	 * downloadPaths before the error branch runs. Paths already gone are expected; any other
	 * removal failure is logged so a leftover artifact is not silently ignored. */
	for (NSString *path in [downloadPaths allValues]) {
		NSError *error = nil;
		if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error] && error != nil &&
			[error code] != NSFileNoSuchFileError) {
			AWEzvLog(@"Could not remove partial download %@: %@", path, [error localizedDescription]);
		}
	}
	[self removeCreatedDirectories];
	if (localFilename != nil) {
		NSError *error = nil;
		if (![[NSFileManager defaultManager] removeItemAtPath:localFilename error:&error] && error != nil &&
			[error code] != NSFileNoSuchFileError) {
			AWEzvLog(@"Could not remove transfer destination %@: %@", localFilename, [error localizedDescription]);
		}
	}
}
- (void)failTransfer
{
	/* A transfer that has already succeeded owns its received artifacts; no failure path may remove
	 * them, so a stale failure arriving after the transport reported completion is a no-op
	 * (issue #260). */
	if (transferSucceeded) {
		return;
	}
	/* Every failure path funnels here: mark the transfer failed so -dealloc's safety net still
	 * removes artifacts if cleanup has not run, remove the partial files and created folder tree
	 * now, and report the failure to the client (issue #248). */
	transferFailed = YES;
	[self removePartialTransferArtifacts];
	[[[manager client] client] transferFailed:self];
}

- (void)downloadFile
{
	NSURL *downloadURL = [NSURL URLWithString:url];
	if (downloadURL == nil) {
		/* Mirror the directory-transfer guard: an unparseable peer-supplied URL must fail the
		 * transfer, not reach requestWithURL:/dataTaskWithRequest: with nil (variant of issue #264
		 * found in pre-PR review). */
		[[[[self manager] client] client]
			reportError:[NSString stringWithFormat:@"Could not download file because its URL is invalid: %@", url]
				ofLevel:AWEzvError];
		[self failTransfer];
		return;
	}
	[self downloadURL:downloadURL toPath:localFilename];
}

#pragma mark Download Helper Methods

/*Download helpers*/
- (NSDictionary *)posixAttributesFromString:(NSString *)posixFlags
{
	if (posixFlags == nil) {
		return nil;
	}
	NSScanner *scanner = [NSScanner scannerWithString:posixFlags];
	unsigned tempInt;
	if (![scanner scanHexInt:&tempInt]) {
		/* A peer-supplied flag that is not hex yields no usable permissions: leave the file's
		 * default permissions rather than applying an uninitialized value (issue #186).
		 */
		return nil;
	}
	return @{@"NSFilePosixPermissions" : [NSNumber numberWithUnsignedInt:tempInt]};
}
- (BOOL)applyPermissions
{
	/*Now go through and apply the permissions*/
	if (!permissionsToApply) {
		return YES;
	}
	if ([permissionsToApply count] <= 0) {
		permissionsToApply = nil;
		return YES;
	}
	NSEnumerator *enumerator = [permissionsToApply keyEnumerator];
	NSString *path;
	NSDictionary *attributes;
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	while ((path = [enumerator nextObject])) {
		/* code that uses the returned key */
		attributes = [permissionsToApply valueForKey:path];
		if (![defaultManager setAttributes:attributes ofItemAtPath:path error:NULL]) {
			[[[manager client] client]
				reportError:[NSString
								stringWithFormat:@"Error applying permissions of %@ to file at %@", attributes, path]
					ofLevel:AWEzvError];
			[self failTransfer];
			permissionsToApply = nil;
			return NO;
		}
	}
	permissionsToApply = nil;
	return YES;
}
- (void)downloadURL:(NSURL *)downloadURL toPath:(NSString *)path
{
	/* This should be easy.  We have a url and a location so let's download things to a location! */

	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:downloadURL
															  cachePolicy:NSURLRequestUseProtocolCachePolicy
														  timeoutInterval:60.0];
	NSString *value = @"AppleSingle";
	[theRequest addValue:value forHTTPHeaderField:@"Accept-Encoding"];
	[theRequest setHTTPShouldHandleCookies:NO];

	/* Create the session lazily, and start the download. The destination file is created in
	 * URLSession:dataTask:didReceiveResponse:completionHandler:, replacing NSURLDownload's
	 * setDestination:allowOverwrite:.
	 */
	if (downloadSession == nil) {
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
		downloadSession = [NSURLSession sessionWithConfiguration:configuration
														delegate:self
												   delegateQueue:[NSOperationQueue mainQueue]];
	}
	NSURLSessionDataTask *theDownload = [downloadSession dataTaskWithRequest:theRequest];
	if (theDownload) {
		[currentDownloads addObject:theDownload];
		[downloadPaths setObject:path forKey:theDownload];
		[theDownload resume];
	} else {
		// inform the user that the download could not be made
		[[[manager client] client] reportError:@"Error starting download of file transfer." ofLevel:AWEzvError];
		[self failTransfer];
	}
}

#pragma mark NSURLSession Delegate Methods
- (void)URLSession:(NSURLSession *)session
			  dataTask:(NSURLSessionDataTask *)dataTask
	didReceiveResponse:(NSURLResponse *)response
	 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
	// Reject non-HTTP responses and non-2xx HTTP statuses before creating the destination file,
	// so AppleSingle-decode and applyPermissions only ever run on an accepted body (issue #177).
	NSError *validationError = AIHTTPDownloadValidationErrorForResponse(response);
	if (validationError != nil) {
		completionHandler(NSURLSessionResponseCancel);
		/* Rejecting the response fails the transfer; remove any earlier tasks' partial files and
		 * the created folder tree (issue #248). */
		[self failTransfer];
		[[[manager client] client] reportError:[validationError localizedDescription] ofLevel:AWEzvError];
		return;
	}

	NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
	if ([(NSString *)[headers objectForKey:@"Content-Encoding"] isEqualToString:@"AppleSingle"]) {
		[encodedDownloads addObject:[[dataTask originalRequest] URL]];
	}

	/* A concurrent failure or cancellation (issue #248) may have torn down this transfer while the
	 * response was in flight. Reject the late response instead of creating a destination file for a
	 * dead transfer. */
	if (transferFailed) {
		completionHandler(NSURLSessionResponseCancel);
		return;
	}

	/* Create the destination file now, replacing NSURLDownload's setDestination:allowOverwrite:. */
	NSString *path = [downloadPaths objectForKey:dataTask];
	if (path == nil) {
		/* The task's path was removed by a concurrent failure's cleanup: nothing to write to. */
		completionHandler(NSURLSessionResponseCancel);
		return;
	}
	[[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
	NSFileHandle *downloadFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
	if (downloadFileHandle == nil) {
		completionHandler(NSURLSessionResponseCancel);
		[self failTransfer];
		return;
	}
	[downloadFileHandle seekToEndOfFile];
	[downloadFileHandles setObject:downloadFileHandle forKey:dataTask];

	completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	NSFileHandle *downloadFileHandle = [downloadFileHandles objectForKey:dataTask];
	[downloadFileHandle writeData:data];
	bytesReceived = bytesReceived + [data length];
	percentComplete = ((float)bytesReceived / (float)size);
	if (percentComplete >= 1.0) {
		/*This will prevent Adium from believing that the download is complete before possible decoding */
		return;
	}
	[[[manager client] client] updateProgressForFileTransfer:self
													 percent:[NSNumber numberWithFloat:percentComplete]
												   bytesSent:[NSNumber numberWithLongLong:bytesReceived]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	NSURLSessionDataTask *dataTask = (NSURLSessionDataTask *)task;
	NSFileHandle *downloadFileHandle = [downloadFileHandles objectForKey:dataTask];
	[downloadFileHandle closeFile];
	[downloadFileHandles removeObjectForKey:dataTask];
	[downloadPaths removeObjectForKey:dataTask];
	[currentDownloads removeObject:dataTask];
	if ([currentDownloads count] == 0) {
		[downloadSession invalidateAndCancel];
		downloadSession = nil;
	}

	if (error != nil) {
		if ([error code] == NSURLErrorCancelled) {
			/* A cancelled download is intentional; nothing to report. */
			return;
		}
		/* The failed task's partial file, and for a directory transfer the created folder tree and
		 * any other in-flight paths, must not be left on disk (issue #248). */
		[self failTransfer];
		// inform the user
		[[[manager client] client]
			reportError:[NSString stringWithFormat:@"Download failed! Error - %@ %@", [error localizedDescription],
												   [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]
				ofLevel:AWEzvError];
		return;
	}

	/*Let's look up the local file and then decode *if* it is an AppleSingle file*/
	NSURL *itemURL = [[dataTask originalRequest] URL];
	if ([encodedDownloads containsObject:itemURL]) {
		NSString *itemPath = [self urlToPath:itemURL];
		BOOL decoded = [self decodeAppleSingleAtPath:itemPath];
		if (!decoded) {
			/* A body that fails to decode is a failed transfer; remove its artifacts rather than
			 * applying permissions to a corrupt file (issue #248). */
			[self failTransfer];
			return;
		}
	}
	percentComplete = ((float)bytesReceived / (float)size);
	BOOL success = TRUE;
	/* Completion is the transport's signal, not the peer-declared size's: when the last data task
	 * completes without error, everything the peer sent has been received. Keying on
	 * bytesReceived/size would leave an over-declared (or zero) size never marked succeeded, so a
	 * late -cancelDownload could still delete the received file (issue #260). */
	if ([currentDownloads count] == 0) {
		/* Post-completion integrity check (issue #263): a transfer whose received byte count falls
		 * short of the peer-declared non-zero size was truncated — the transport finished without
		 * error, but not all declared content arrived. Fail it rather than accept a corrupt file.
		 * -transferWasTruncated subtracts the accumulated AppleSingle envelope overhead, so a
		 * truncated raw body cannot hide behind envelope bytes (issue #269). */
		if ([self transferWasTruncated]) {
			[self failTransfer];
			/* Report the envelope-adjusted raw content length, so the message measures the same thing
			 * the integrity check does rather than the raw wire byte count (issue #269). */
			unsigned long long receivedRaw = 0;
			if (appleSingleEnvelopeBytes <= (unsigned long long)bytesReceived) {
				receivedRaw = (unsigned long long)bytesReceived - appleSingleEnvelopeBytes;
			}
			[[[manager client] client]
				reportError:[NSString stringWithFormat:@"Download incomplete: received %qu of %qu declared bytes.",
													   receivedRaw, size]
					ofLevel:AWEzvError];
			return;
		}
		success = [self applyPermissions];
		if (success) {
			/* Fully received and accepted: a late -cancelDownload or -dealloc must never remove
			 * the received artifacts (issue #260). */
			transferSucceeded = YES;
		}
	}
	if (!success) {
		/* applyPermissions already reported the failure; remove artifacts so a partially-
		 * received transfer leaves nothing behind (issue #248). */
		transferFailed = YES;
		[self removePartialTransferArtifacts];
	} else {
		[[[manager client] client] updateProgressForFileTransfer:self
														 percent:[NSNumber numberWithFloat:percentComplete]
													   bytesSent:[NSNumber numberWithLongLong:bytesReceived]];
	}
}

#pragma mark Encoding Helper Methods

- (NSString *)urlToPath:(NSURL *)itemURL
{
	NSString *urlString = [itemURL absoluteString];
	if ([urlString hasPrefix:url]) {
		/*Remove the base url from the string*/
		NSRange range = [urlString rangeOfString:url];
		NSString *path = [urlString substringFromIndex:(range.location + range.length)];
		path = [path stringByRemovingPercentEncoding];
		if (localFilename) {
			path = [localFilename stringByAppendingPathComponent:path];
			return path;
		} else {
			return NULL;
		}
	}
	return NULL;
}

- (BOOL)decodeAppleSingleAtPath:(NSString *)path
{
	/*Get NSData from path*/
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		[[[manager client] client]
			reportError:@"AppleSingle: Could not apply permissions to file because it does not exist."
				ofLevel:AWEzvError];
		return NO;
	}
	NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

	/*Declarations*/
	unsigned long length = [data length];
	size_t offset;
	struct AppleSingleFinderInfo info;
	memset(&info, 0, sizeof(info));
	BOOL hasFinderInfo = NO;
	struct AppleSingleHeader header;
	struct AppleSingleEntry entry;
	NSRange resourceRange = NSMakeRange(0, 0);
	NSRange dataForkRange = NSMakeRange(0, 0);
	BOOL resourceExist = NO;
	BOOL dataForkExist = NO;
	unsigned long long dataForkLength = 0;
	offset = 0;

	if (length < APPLE_SINGLE_HEADER_LENGTH) {
		[[[manager client] client] reportError:@"AppleSingle: Invalid AppleSingle File." ofLevel:AWEzvError];
		return NO;
	}
	[data getBytes:&header length:APPLE_SINGLE_HEADER_LENGTH];
	offset += APPLE_SINGLE_HEADER_LENGTH;

	/* switch items to host from network byteorder*/
	header.magicNumber = ntohl(header.magicNumber);
	header.versionNumber = ntohl(header.versionNumber);
	header.numberEntries = ntohs(header.numberEntries);

	if (!(header.magicNumber == APPLE_SINGLE_MAGIC_NUMBER && header.versionNumber == APPLE_SINGLE_VERSION_NUMBER)) {
		[[[manager client] client] reportError:@"AppleSingle: Supposed AppleSingle file is not AppleSingle."
									   ofLevel:AWEzvError];
		return NO;
	}
	/* The magicNumber and versionNumber are correct so we have an AppleSingle file */
	/*Now let's read the entries */
	for (unsigned i = 0; i < header.numberEntries; ++i) {
		if (length < (offset + sizeof(entry))) {
			[[[manager client] client] reportError:@"AppleSingle: Not enough reoom for declared number of entries."
										   ofLevel:AWEzvError];

			return NO;
		}
		[data getBytes:&entry range:NSMakeRange(offset, sizeof(entry))];
		offset += sizeof(entry);

		/* switch items to host from network byteorder*/
		entry.entryID = ntohl(entry.entryID);
		entry.offset = ntohl(entry.offset);
		entry.length = ntohl(entry.length);
		/*Validate the entry*/
		if (entry.entryID == 0) {
			[[[manager client] client] reportError:@"AppleSingle: Invalid Entry ID of value 0." ofLevel:AWEzvError];
			return NO;
		}

		if (entry.offset > length) {
			[[[manager client] client] reportError:@"AppleSingle: Invalid AppleSingle Encoding." ofLevel:AWEzvError];

			return NO;
		}

		/* Compare in 64-bit: entry.offset and entry.length are UInt32, so summing them as UInt32 can
		 * wrap (e.g. offset 40 + length 0xFFFFFFFF) and slip an out-of-bounds range past the check
		 * into subdataWithRange: (issue #273). */
		if (((unsigned long long)entry.offset + entry.length) > length) {
			[[[manager client] client] reportError:@"AppleSingle: Invalid AppleSingle Encoding." ofLevel:AWEzvError];
			return NO;
		}
		switch (entry.entryID) {
		case AS_ENTRY_DATA_FORK:
			// NSLog(@"AS_ENTRY_DATA_FORK");
			dataForkLength = entry.length;
			dataForkRange = NSMakeRange(entry.offset, entry.length);
			dataForkExist = YES;
			resourceRange = NSMakeRange(entry.offset, entry.length);
			resourceExist = YES;
			break;
		case AS_ENTRY_RESOURCE_FORK:
			// NSLog(@"AS_ENTRY_RESOURCE_FORK");
			resourceRange = NSMakeRange(entry.offset, entry.length);
			resourceExist = YES;
			break;
		case AS_ENTRY_FINDER_INFO:
			// NSLog(@"AS_ENTRY_FINDER_INFO");
			/* The Finder info is read straight into a fixed 32-byte stack struct; a longer entry would
			 * overflow it (issue #273). */
			if (entry.length != sizeof(info)) {
				[[[manager client] client] reportError:@"AppleSingle: Invalid Finder info length." ofLevel:AWEzvError];
				return NO;
			}
			[data getBytes:&info range:NSMakeRange(entry.offset, entry.length)];
			info.finderInfo.finderFlags = ntohs(info.finderInfo.finderFlags);
			hasFinderInfo = YES;
			break;
		case AS_ENTRY_REAL_NAME:
			// NSLog(@"AS_ENTRY_REAL_NAME");
			break;
		case AS_ENTRY_COMMENT:
			// NSLog(@"AS_ENTRY_COMMENT");
			break;
		case AS_ENTRY_ICON_BW:
			// NSLog(@"AS_ENTRY_ICON_BW");
			break;
		case AS_ENTRY_ICON_COLOR:
			// NSLog(@"AS_ENTRY_ICON_COLOR");
			break;
		case AS_ENTRY_DATE_INFO:
			// NSLog(@"AS_ENTRY_DATE_INFO");
			break;
		case AS_ENTRY_MACINTOSH_FILE_INFO:
			// NSLog(@"AS_ENTRY_MACINTOSH_FILE_INFO");
			break;
		case AS_ENTRY_PRODOS_FILE_INFO:
			// NSLog(@"AS_ENTRY_PRODOS_FILE_INFO");
			break;
		case AS_ENTRY_MSDOS_FILE_INFO:
			// NSLog(@"AS_ENTRY_MSDOS_FILE_INFO");
			break;
		case AS_ENTRY_AFP_SHORT_NAME:
			// NSLog(@"AS_ENTRY_AFP_SHORT_NAME");
			break;
		case AS_ENTRY_AFP_FILE_INFO:
			// NSLog(@"AS_ENTRY_AFP_FILE_INFO");
			break;
		case AS_ENTRY_AFP_DIRECTORY_ID:
			// NSLog(@"AS_ENTRY_AFP_DIRECTORY_ID");
			break;
		default:
			// NSLog(@"default");
			break;
		}
	}

	/*Now we can write the date and apply the attributes */
	if (resourceExist) {
		/* Prefer the data fork when a body carries both forks: the data fork is the file content the
		 * transfer delivers and the truncation accounting measures it, so installing a later resource
		 * fork would leave a file whose length the integrity check never validated (issue #269). A
		 * resource-fork-only body (no data fork) falls back to the existing last-content-entry write. */
		NSRange contentRange = dataForkExist ? dataForkRange : resourceRange;
		NSData *decodedData = [data subdataWithRange:contentRange];
		if (![decodedData writeToFile:path atomically:YES]) {
			[[[manager client] client] reportError:@"AppleSingle: Could not write decoded data." ofLevel:AWEzvError];
			/* A failed write must fail the transfer: the caller (URLSession:task:didCompleteWithError:)
			 * treats NO as "remove artifacts and fail", and returning YES would install a partial file
			 * as success (issue #273). */
			return NO;
		}
		/* Accumulate the envelope overhead (header + entries + Finder info) so -transferWasTruncated can
		 * measure the raw data fork against the declared size (issue #269). */
		appleSingleEnvelopeBytes += [data length] - dataForkLength;
		/*Now apply attributes — store the Finder info in the com.apple.FinderInfo extended attribute
		 * (replaces the deprecated FSRef/FSSetCatalogInfo API, which also zeroed the data it copied).
		 */
		if (hasFinderInfo) {
			if (setxattr([path fileSystemRepresentation], "com.apple.FinderInfo", &info, sizeof(info), 0, 0) != 0) {
				[[[manager client] client] reportError:@"AppleSingle: Error setting finder info." ofLevel:AWEzvError];

				return NO;
			}
		}
	}
	return YES;
}

- (BOOL)transferWasTruncated
{
	if (size == 0) {
		/* A zero declared size is not cross-checkable; never fail on it (issue #263). */
		return NO;
	}
	unsigned long long received = (unsigned long long)bytesReceived;
	if (appleSingleEnvelopeBytes > received) {
		/* Accounting drift (more envelope claimed than bytes received) is unreachable on the current
		 * decode path, but must fail closed — the unsigned subtraction would otherwise wrap to a huge
		 * value and silently accept a truncated body (issue #269). */
		return YES;
	}
	/* Envelope overhead (accumulated during decode) is subtracted so the raw data length — not the
	 * wire byte count — is compared against the peer-declared size (issue #269). */
	return (received - appleSingleEnvelopeBytes) < size;
}

@end
