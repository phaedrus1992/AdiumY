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

#import "AILogViewerWindowController.h"

#import "AIAccountController.h"
#import "AIChatController.h"
#import "AIChatLog.h"
#import "AIContactController.h"
#import "AIGradientView.h"
#import "AILogDateFormatter.h"
#import "AILogFromGroup.h"
#import "AILogToGroup.h"
#import "AILoggerPlugin.h"
#import "AIXMLChatlogConverter.h"
#import "ESRankingCell.h"

#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>

#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIListContact.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIUserIcons.h>

#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDateAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIOutlineViewAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITableViewAdditions.h>

#import <AIUtilities/AIDividedAlternatingRowOutlineView.h>
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AITextAttributes.h>
#import <AIUtilities/AIToolbarUtilities.h>

#define KEY_LOG_VIEWER_WINDOW_FRAME @"Log Viewer Frame"
#define TOOLBAR_LOG_VIEWER @"Log Viewer Toolbar"

#define MAX_LOGS_TO_SORT_WHILE_SEARCHING 10000 // Max number of logs we will live sort while searching
#define LOG_SEARCH_STATUS_INTERVAL 20          // 1/60ths of a second to wait before refreshing search status
#define REFRESH_RESULTS_INTERVAL 1.0           // Interval between results refreshes while searching

#define DATE_ITEM_IDENTIFIER @"date"

#define SEARCH_MENU AILocalizedString(@"Search Menu", nil)
#define FROM AILocalizedString(@"From", nil)
#define TO AILocalizedString(@"To", nil)
#define DATE AILocalizedString(@"Date", nil)
#define CONTENT AILocalizedString(@"Content", nil)
#define DELETE AILocalizedString(@"Delete", nil)
#define SEARCH AILocalizedString(@"Search", nil)
#define SEARCH_LOGS AILocalizedString(@"Search Logs", nil)

#define HIDE_EMOTICONS AILocalizedString(@"Hide Emoticons", nil)
#define SHOW_EMOTICONS AILocalizedString(@"Show Emoticons", nil)
#define HIDE_TIMESTAMPS AILocalizedString(@"Hide Timestamps", nil)
#define SHOW_TIMESTAMPS AILocalizedString(@"Show Timestamps", nil)

#define IMAGE_EMOTICONS_OFF @"emoticon32"
#define IMAGE_EMOTICONS_ON @"emoticon32_transparent"
#define IMAGE_TIMESTAMPS_OFF @"timestamp32"
#define IMAGE_TIMESTAMPS_ON @"timestamp32_transparent"

#define KEY_LOG_VIEWER_EMOTICONS @"Log Viewer Emoticons"
#define KEY_LOG_VIEWER_TIMESTAMPS @"Log Viewer Timestamps"
#define KEY_LOG_VIEWER_SELECTED_COLUMN @"Log Viewer Selected Column Identifier"

@interface AILogViewerWindowController ()
+ (NSOperationQueue *)sharedLogViewerQueue;
+ (AILogViewerWindowController *)sharedLogViewerForPlugin:(id)inPlugin;

- (id)initWithWindowNibName:(NSString *)windowNibName plugin:(id)inPlugin;
- (void)initLogFiltering;
- (void)displayLog:(AIChatLog *)log;
- (void)hilightOccurrencesOfString:(NSString *)littleString
						  inString:(NSMutableAttributedString *)bigString
				   firstOccurrence:(NSRange *)outRange;
- (void)hilightNextPrevious;
- (void)sortCurrentSearchResultsForTableColumn:(NSTableColumn *)tableColumn direction:(BOOL)direction;
- (void)startSearchingClearingCurrentResults:(BOOL)clearCurrentResults;
- (void)buildSearchMenu;
- (NSMenuItem *)_menuItemWithTitle:(NSString *)title forSearchMode:(LogSearchMode)mode;
- (void)_logFilter:(NSString *)searchString searchID:(NSInteger)searchID mode:(LogSearchMode)mode;
- (void)installToolbar;
- (void)updateRankColumnVisibility;
- (void)openLogAtPath:(NSString *)inPath;
- (void)rebuildContactsList;
- (void)filterForContact:(AIListContact *)inContact;
- (void)filterForChatName:(NSString *)chatName withAccount:(AIAccount *)account;
- (void)selectCachedIndex;
- (void)tableViewSelectionDidChangeDelayed;

- (NSAlert *)alertForDeletionOfLogCount:(NSUInteger)logCount;

- (void)_willOpenForContact;
- (void)_didOpenForContact;

- (void)deleteSelection:(id)sender;

- (void)_displayLogs:(NSArray *)logArray;
- (void)_displayLogText:(NSAttributedString *)logText;

- (void)outlineViewSelectionDidChangeDelayed;
- (void)openChatOnDoubleAction:(id)sender;
- (void)deleteLogsAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
NSInteger compareRectLocation(id obj1, id obj2, void *context);

- (void)setNavBarHidden:(NSNumber *)hide;
@end

@implementation AILogViewerWindowController

static NSInteger toArraySort(id itemA, id itemB, void *context);

+ (NSOperationQueue *)sharedLogViewerQueue
{
	static NSOperationQueue *logViewerQueue = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		logViewerQueue = filterDate = nil;

		switch (dateType) {
		case AIDateTypeAnyDate:
			filterDateType = AIDateTypeAnyDate;
			break;

		case AIDateTypeToday:
			filterDateType = AIDateTypeExactly;
			filterDate = today;
			break;

		case AIDateTypeSinceYesterday:
			filterDateType = AIDateTypeAfter;
			comps.day--;
			comps.hour -= comps.hour;
			comps.minute -= comps.minute;
			comps.second -= comps.second + 1;
			filterDate = [calendar dateFromComponents:comps];
			break;

		case AIDateTypeThisWeek:
			filterDateType = AIDateTypeAfter;
			comps.day -= [self daysSinceStartOfWeekGivenToday:today];
			comps.hour -= comps.hour;
			comps.minute -= comps.minute;
			comps.second -= comps.second + 1;
			filterDate = [calendar dateFromComponents:comps];
			break;

		case AIDateTypeWithinLastTwoWeeks:
			filterDateType = AIDateTypeAfter;
			comps.day -= 14;
			comps.hour -= comps.hour;
			comps.minute -= comps.minute;
			comps.second -= comps.second + 1;
			filterDate = [calendar dateFromComponents:comps];
			break;

		case AIDateTypeThisMonth:
			filterDateType = AIDateTypeAfter;
			comps.day -= comps.day;
			comps.hour -= comps.hour;
			comps.minute -= comps.minute;
			comps.second -= comps.second + 1;
			filterDate = [calendar dateFromComponents:comps];
			break;

		case AIDateTypeWithinLastTwoMonths:
			filterDateType = AIDateTypeAfter;
			comps.month--;
			comps.day -= comps.day;
			comps.hour = 0;
			comps.minute = 0;
			comps.second--;
			filterDate = [calendar dateFromComponents:comps];
			break;

		default:
			break;
		}

		switch (dateType) {
		case AIDateTypeExactly:
			filterDateType = AIDateTypeExactly;
			filterDate = [[datePicker dateValue] dateWithCalendarFormat:nil timeZone:nil];
			showDatePicker = YES;
			break;

		case AIDateTypeBefore:
			filterDateType = AIDateTypeBefore;
			filterDate = [[datePicker dateValue] dateWithCalendarFormat:nil timeZone:nil];
			showDatePicker = YES;
			break;

		case AIDateTypeAfter:
			filterDateType = AIDateTypeAfter;
			filterDate = [[datePicker dateValue] dateWithCalendarFormat:nil timeZone:nil];
			showDatePicker = YES;
			break;

		default:
			showDatePicker = NO;
			break;
		}

		BOOL updateSize = NO;
		if (showDatePicker && [datePicker isHidden]) {
			[datePicker setHidden:NO];
			updateSize = YES;

		} else if (!showDatePicker && ![datePicker isHidden]) {
			[datePicker setHidden:YES];
			updateSize = YES;
		}

		if (updateSize) {
			NSEnumerator *enumerator = [[[[self window] toolbar] items] objectEnumerator];
			NSToolbarItem *toolbarItem;
			while ((toolbarItem = [enumerator nextObject])) {
				if ([[toolbarItem itemIdentifier] isEqualToString:DATE_ITEM_IDENTIFIER]) {
					NSSize newSize = NSMakeSize(([datePicker isHidden] ? 180 : 290), NSHeight([view_DatePicker frame]));
					[toolbarItem setMinSize:newSize];
					[toolbarItem setMaxSize:newSize];
					break;
				}
			}
		}
}

- (NSString *)dateItemNibName
{
		return @"LogViewerDateFilter";
}

@end
