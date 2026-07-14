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

#import "ESFileTransferController.h"

#import "ESFileTransfer.h"
#import "ESFileTransferPreferences.h"
#import "ESFileTransferProgressWindowController.h"
#import "ESFileTransferRequestPromptController.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIObjectAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIToolbarControllerProtocol.h>
#import <Adium/AIWindowController.h>

#define SEND_FILE AILocalizedString(@"Send File", nil)
#define SEND_FILE_WITH_ELLIPSIS
safeFileExtensions = nil;
}

showProgressWindow = [[prefDict objectForKey:KEY_FT_SHOW_PROGRESS_WINDOW] boolValue];
}

#pragma mark AIEventHandler

- (NSString *)shortDescriptionForEventID:(NSString *)eventID
{
	NSString *description;

	if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
		description = AILocalizedString(@"File transfer fails", nil);
	} else {
		description = @"";
	}

	return description;
}

- (NSString *)globalShortDescriptionForEventID:(NSString *)eventID
{
	NSString *description;

	if ([eventID isEqualToString:FILE_TRANSFER_REQUEST]) {
		description = AILocalizedString(@"File transfer requested", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_CHECKSUMMING]) {
		description = AILocalizedString(@"File is checksummed before sending", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_WAITING_REMOTE]) {
		description = AILocalizedString(@"File transfer being offered to other side", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_BEGAN]) {
		description = AILocalizedString(@"File transfer begins", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_CANCELLED]) {
		description = AILocalizedString(@"File transfer cancelled by the other side", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
		description = AILocalizedString(@"File transfer completed successfully", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
		description = AILocalizedString(@"File transfer failed", nil);
	} else {
		description = @"";
	}

	return description;
}

// Evan: This exists because old X(tras) relied upon matching the description of event IDs, and I don't feel like making
// a converter for old packs.  If anyone wants to fix this situation, please feel free :)
// XXX-fix this for the above comment.
- (NSString *)englishGlobalShortDescriptionForEventID:(NSString *)eventID
{
	NSString *description;

	if ([eventID isEqualToString:FILE_TRANSFER_REQUEST]) {
		description = @"File Transfer Request";
	} else if ([eventID isEqualToString:FILE_TRANSFER_CHECKSUMMING]) {
		description = @"File Checksumming for Sending";
	} else if ([eventID isEqualToString:FILE_TRANSFER_WAITING_REMOTE]) {
		description = @"File Transfer Being Offered to Remote User";
	} else if ([eventID isEqualToString:FILE_TRANSFER_BEGAN]) {
		description = @"File Transfer Began";
	} else if ([eventID isEqualToString:FILE_TRANSFER_CANCELLED]) {
		// Canceled, not Cancelled as we use elsewhere in Adium, for historical reasons. Both are valid spellings.
		description = @"File Transfer Canceled Remotely";
	} else if ([eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
		description = @"File Transfer Complete";
	} else if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
		description = @"File transfer failed";
	} else {
		description = @"";
	}

	return description;
}

- (NSString *)longDescriptionForEventID:(NSString *)eventID forListObject:(AIListObject *)listObject
{
	NSString *description;

	if (listObject) {
		NSString *format;

		if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
			format = AILocalizedString(@"When a file transfer with %@ fails", nil);
		} else {
			format = nil;
		}

		if (format) {
			NSString *name;
			name = ([listObject isKindOfClass:[AIListGroup class]]
						? [NSString stringWithFormat:AILocalizedString(@"a member of %@", nil), listObject.displayName]
						: listObject.displayName);

			description = [NSString stringWithFormat:format, name];

		} else {
			description = @"";
		}

	} else {
		if ([eventID isEqualToString:FILE_TRANSFER_REQUEST]) {
			description = AILocalizedString(@"When a file transfer is requested", nil);
		} else if ([eventID isEqualToString:FILE_TRANSFER_CHECKSUMMING]) {
			description = AILocalizedString(@"When a file is checksummed prior to sending", nil);
		} else if ([eventID isEqualToString:FILE_TRANSFER_WAITING_REMOTE]) {
			description = AILocalizedString(@"When a file transfer is offered to a remote user", nil);
		} else if ([eventID isEqualToString:FILE_TRANSFER_BEGAN]) {
			description = AILocalizedString(@"When a file transfer begins", nil);
		} else if ([eventID isEqualToString:FILE_TRANSFER_CANCELLED]) {
			description = AILocalizedString(@"When a file transfer is cancelled remotely", nil);
		} else if ([eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
			description = AILocalizedString(@"When a file transfer is completed successfully", nil);
		} else if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
			description = AILocalizedString(@"When a file transfer fails", nil);
		} else {
			description = @"";
		}
	}

	return description;
}

- (NSString *)naturalLanguageDescriptionForEventID:(NSString *)eventID
										listObject:(AIListObject *)listObject
										  userInfo:(id)userInfo
									includeSubject:(BOOL)includeSubject
{
	NSString *description = nil;
	NSString *displayName, *displayFilename;
	ESFileTransfer *fileTransfer;

	NSParameterAssert([userInfo isKindOfClass:[ESFileTransfer class]]);
	fileTransfer = (ESFileTransfer *)userInfo;

	displayName = listObject.displayName;
	displayFilename = [fileTransfer displayFilename];

	if (includeSubject) {
		NSString *format = nil;

		if ([eventID isEqualToString:FILE_TRANSFER_REQUEST]) {
			// Should only happen for an incoming transfer
			format = AILocalizedString(@"%@ requests to send you %@",
									   "A person is wanting to send you a file. The first %@ is a name; the second %@ "
									   "is the filename of the file being sent.");

		} else if ([eventID isEqualToString:FILE_TRANSFER_WAITING_REMOTE]) {
			// Should only happen for outgoing file transfers
			format =
				AILocalizedString(@"Offering to send %@ to %@",
								  "You are offering to send a file to a remote user. The first %@ is the filename of "
								  "the file being sent; the second %@ is the recipient of the file being sent.");

		} else if ([eventID isEqualToString:FILE_TRANSFER_BEGAN]) {
			if ([fileTransfer fileTransferType] == Incoming_FileTransfer) {
				format = AILocalizedString(@"%@ began sending you %@",
										   "A person began sending you a file. The first %@ is a name; the second %@ "
										   "is the filename of the file being sent.");
			} else {
				format = AILocalizedString(@"%@ began receiving %@",
										   "A person began receiving a file from you. The first %@ is the recipient of "
										   "the file; the second %@ is the filename of the file being sent.");
			}
		} else if ([eventID isEqualToString:FILE_TRANSFER_CANCELLED]) {
			format = AILocalizedString(@"%@ cancelled the transfer of %@",
									   "The other contact cancelled a file transfer in progress. The first %@ is the "
									   "recipient of the file; the second %@ is the filename of the file being sent.");
		} else if ([eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
			if ([fileTransfer fileTransferType] == Incoming_FileTransfer) {
				format = AILocalizedString(@"%@ sent you %@", "First placeholder is a name; second is a filename");
			} else {
				format = AILocalizedString(@"%@ received %@", "First placeholder is a name; second is a filename");
			}
		} else if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
			if ([fileTransfer fileTransferType] == Incoming_FileTransfer) {
				format = AILocalizedString(@"%@'s transfer of %@ failed",
										   "First placeholder is a name; second is a filename");

			} else {
				format = AILocalizedString(@"Your transfer to %@ of %@ failed",
										   "First placeholder is a name; second is a filename");
			}
		}

		if (format) {
			description = [NSString stringWithFormat:format, displayName, displayFilename];
		}
	} else {
		NSString *format = nil;

		if ([eventID isEqualToString:FILE_TRANSFER_REQUEST]) {
			// Should only happen for an incoming transfer
			format = AILocalizedString(@"requests to send you %@", "%@ is a filename of a file being sent");

		} else if ([eventID isEqualToString:FILE_TRANSFER_WAITING_REMOTE]) {
			// Should only happen for an outgoing transfer
			format = AILocalizedString(@"offers to send %@", "%@ is a filename of a file being sent");

		} else if ([eventID isEqualToString:FILE_TRANSFER_BEGAN]) {
			if ([fileTransfer fileTransferType] == Incoming_FileTransfer) {
				format = AILocalizedString(@"began sending you %@", "%@ is a filename of a file being sent");
			} else {
				format = AILocalizedString(@"began receiving %@", "%@ is a filename of a file being sent");
			}
		} else if ([eventID isEqualToString:FILE_TRANSFER_CANCELLED]) {
			format = AILocalizedString(@"cancelled the transfer of %@", "%@ is a filename of a file being sent");
		} else if ([eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
			if ([fileTransfer fileTransferType] == Incoming_FileTransfer) {
				format = AILocalizedString(@"sent you %@", "%@ is a filename of a file being sent");
			} else {
				format = AILocalizedString(@"received %@", "%@ is a filename of a file being sent");
			}
		} else if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
			if ([fileTransfer fileTransferType] == Incoming_FileTransfer) {
				format = AILocalizedString(@"failed to send you %@", "%@ is a filename of a file being sent");
			} else {
				format = AILocalizedString(@"failed to receive %@", "%@ is a filename of a file being sent");
			}
		}

		if (format) {
			description = [NSString stringWithFormat:format, displayFilename];
		}
	}

	return description;
}

- (NSImage *)imageForEventID:(NSString *)eventID
{
	static NSImage *eventImage = nil;
	if (!eventImage)
		eventImage = [NSImage imageNamed:@"pref-file-transfer" forClass:[self class]];
	return eventImage;
}

- (NSString *)descriptionForCombinedEventID:(NSString *)eventID
							  forListObject:(AIListObject *)listObject
									forChat:(AIChat *)chat
								  withCount:(NSUInteger)count
{
	NSString *format = nil;

	if ([eventID isEqualToString:FILE_TRANSFER_REQUEST]) {
		format = AILocalizedString(@"%u incoming file transfers", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_CHECKSUMMING]) {
		format = AILocalizedString(@"%u files being checksummed prior to sending", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_WAITING_REMOTE]) {
		format = AILocalizedString(@"%u files offered to send", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_BEGAN]) {
		format = AILocalizedString(@"%u files began transferring", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_CANCELLED]) {
		format = AILocalizedString(@"%u files cancelled remotely", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
		format = AILocalizedString(@"%u files completed successfully", nil);
	} else if ([eventID isEqualToString:FILE_TRANSFER_FAILED]) {
		format = AILocalizedString(@"%u file transfers failed", nil);
	}

	return format ? [NSString stringWithFormat:format, count] : @"";
}

#pragma mark Strings for sizes

#define ZERO_BYTES AILocalizedString(@"Zero bytes", "no file size")

- (NSString *)stringForSize:(unsigned long long)inSize
{
	NSString *ret = nil;

	if (inSize == 0.)
		ret = ZERO_BYTES;
	else if (inSize > 0. && inSize < 1024.)
		ret = [NSString stringWithFormat:AILocalizedString(@"%llu bytes", "file size measured in bytes"), inSize];
	else if (inSize >= 1024. && inSize < pow(1024., 2.))
		ret = [NSString
			stringWithFormat:AILocalizedString(@"%.1f KB", "file size measured in kilobytes"), (inSize / 1024.)];
	else if (inSize >= pow(1024., 2.) && inSize < pow(1024., 3.))
		ret = [NSString stringWithFormat:AILocalizedString(@"%.2f MB", "file size measured in megabytes"),
										 (inSize / pow(1024., 2.))];
	else if (inSize >= pow(1024., 3.) && inSize < pow(1024., 4.))
		ret = [NSString stringWithFormat:AILocalizedString(@"%.3f GB", "file size measured in gigabytes"),
										 (inSize / pow(1024., 3.))];
	else if (inSize >= pow(1024., 4.))
		ret = [NSString stringWithFormat:AILocalizedString(@"%.4f TB", "file size measured in terabytes"),
										 (inSize / pow(1024., 4.))];

	if (!ret)
		ret = ZERO_BYTES;

	return ret;
}

- (NSString *)stringForSize:(unsigned long long)inSize
						 of:(unsigned long long)totalSize
				   ofString:(NSString *)totalSizeString
{
	NSString *ret = nil;

	if (inSize == 0.) {
		ret = ZERO_BYTES;
	} else if (inSize > 0. && inSize < 1024.) {
		if (totalSize > 0. && totalSize < 1024.) {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%llu of %llu bytes", "file sizes both measured in bytes"), inSize,
								 totalSize];

		} else {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%llu bytes of %@",
												   "file size measured in bytes out of some other measurement"),
								 inSize, totalSizeString];
		}
	} else if (inSize >= 1024. && inSize < pow(1024., 2.)) {
		if (totalSize >= 1024. && totalSize < pow(1024., 2.)) {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.1f of %.1f KB", "file sizes both measured in kilobytes"),
								 (inSize / 1024.), (totalSize / 1024.)];

		} else {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.1f KB of %@",
												   "file size measured in kilobytes out of some other measurement"),
								 (inSize / 1024.), totalSizeString];
		}
	} else if (inSize >= pow(1024., 2.) && inSize < pow(1024., 3.)) {
		if (totalSize >= pow(1024., 2.) && totalSize < pow(1024., 3.)) {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.2f of %.2f MB", "file sizes both measured in megabytes"),
								 (inSize / pow(1024., 2.)), (totalSize / pow(1024., 2.))];
		} else {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.2f MB of %@",
												   "file size measured in megabytes out of some other measurement"),
								 (inSize / pow(1024., 2.)), totalSizeString];
		}
	} else if (inSize >= pow(1024., 3.) && inSize < pow(1024., 4.)) {
		if (totalSize >= pow(1024., 3.) && totalSize < pow(1024., 4.)) {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.3f of %.3f GB", "file sizes both measured in gigabytes"),
								 (inSize / pow(1024., 3.)), (totalSize / pow(1024., 3.))];
		} else {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.3f GB of %@",
												   "file size measured in gigabytes out of some other measurement"),
								 (inSize / pow(1024., 3.)), totalSizeString];
		}
	} else if (inSize >= pow(1024., 4.)) {
		if (totalSize >= pow(1024., 4.)) {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.4f of %.4f TB", "file sizes both measured in terabytes"),
								 (inSize / pow(1024., 4.)), (totalSize / pow(1024., 4.))];
		} else {
			ret = [NSString
				stringWithFormat:AILocalizedString(@"%.4f TB of %@",
												   "file size measured in terabytes out of some other measurement"),
								 (inSize / pow(1024., 4.)), totalSizeString];
		}
	}

	if (!ret)
		ret = ZERO_BYTES;

	return ret;
}

@end
