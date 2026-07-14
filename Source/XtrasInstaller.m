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

#import "XtrasInstaller.h"
#import <AIUtilities/AIBundleAdditions.h>
#import <AIUtilities/AIStringAdditions.h>

// Should only be YES for testing
#define ALLOW_UNTRUSTED_XTRAS NO

@interface XtrasInstaller ()
- (void)closeInstaller __attribute__((ns_consumes_self));
- (void)updateInfoText;
@end

/*!
 * @class XtrasInstaller
 * @brief Class which displays a progress window and downloads an AdiumYExtra, decompresses it, and installs it.
 */
@implementation XtrasInstaller

@synthesize dest, download, xtraName;

// XtrasInstaller does not autorelease because it will release itself when closed
+ (XtrasInstaller *)installer
{
	return
}
else
{
	decompressionSuccess = NO;
}

NSFileManager *fileManager =
}
else
{
	AILogWithSignature(@"Getting quarantine data failed for %@ (%@)", self, self.dest);
	[self closeInstaller];
	return;
}

CFRelease(cfOldQuarantineProperties);

if (!quarantineProperties) {
	[self closeInstaller];
	return;
}

AILogWithSignature(@"Old quarantine data: %@", quarantineProperties);
}
else if (err == kLSAttributeNotFoundErr)
{
	quarantineProperties = [NSMutableDictionary dictionaryWithCapacity:2];
}

[quarantineProperties setObject:(NSString *)kLSQuarantineTypeWebDownload forKey:(NSString *)kLSQuarantineTypeKey];

[quarantineProperties setObject:[[self.download request] URL] forKey:(NSString *)kLSQuarantineDataURLKey];

[self setQuarantineProperties:quarantineProperties forDirectory:&fsRef];

AILogWithSignature(@"Quarantined %@ with %@", self.dest, quarantineProperties);
}
else
{
	AILogWithSignature(@"Danger! Could not find file to quarantine: %@!", self.dest);
}

// the remaining files in the directory should be the contents of the xtra
fileEnumerator = [fileManager enumeratorAtPath:self.dest];

if (decompressionSuccess && fileEnumerator) {
	NSSet *supportedDocumentExtensions = [[NSBundle mainBundle] supportedDocumentExtensions];

	for (NSString *nextFile in fileEnumerator) {

		/* Ignore hidden files and the __MACOSX folder which some compression engines stick into the archive but
		 * /usr/bin/unzip doesn't handle properly.
		 */
		if ((![[nextFile lastPathComponent] hasPrefix:@"."]) &&
			(![[nextFile pathComponents] containsObject:@"__MACOSX"])) {
			NSString *fileExtension = [nextFile pathExtension];
			NSEnumerator *supportedDocumentExtensionsEnumerator;
			NSString *extension;
			BOOL isSupported = NO;

			// We want to do a case-insensitive path extension comparison
			supportedDocumentExtensionsEnumerator = [supportedDocumentExtensions objectEnumerator];
			while (!isSupported && (extension = [supportedDocumentExtensionsEnumerator nextObject])) {
				isSupported = ([fileExtension caseInsensitiveCompare:extension] == NSOrderedSame);
			}

			if (isSupported) {
				NSString *xtraPath = [self.dest stringByAppendingPathComponent:nextFile];

				// Open the file directly
				AILogWithSignature(@"Installing %@", xtraPath);
				success = [[NSApp delegate] application:NSApp openTempFile:xtraPath];

				if (!success) {
					NSLog(@"Installation Error: %@", xtraPath);
				}
			}
		}
	}

} else {
	NSLog(@"Installation Error: %@ (%@)", self.dest,
		  (decompressionSuccess ? @"Decompressed succesfully" : @"Failed to decompress"));
}

// delete our temporary directory, and any files remaining in it
#ifdef DEBUG_BUILD
if (success)
	[fileManager removeItemAtPath:self.dest error:NULL];
#else
[fileManager removeItemAtPath:self.dest error:NULL];
#endif

[self closeInstaller];
}

@end
