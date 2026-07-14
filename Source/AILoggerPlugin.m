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

#import "AILoggerPlugin.h"
#import "AIChatLog.h"
#import "AILogFromGroup.h"
#import "AILogToGroup.h"
#import "AILogViewerWindowController.h"
#import "AIXMLAppender.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <AIUtilities/ISO8601DateFormatter.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContentContext.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentEvent.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentNotification.h>
#import <Adium/AIContentStatus.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AILoginControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIService.h>
#import <Adium/AIToolbarControllerProtocol.h>
#import <Adium/AIXMLElement.h>

#import <libkern/OSAtomic.h>

#import "AILogFileUpgradeWindowController.h"

#import <AIUtilities/AdiumSpotlightImporter.h>

#pragma mark Defines
#pragma mark -

#define LOG_INDEX_NAME @"Logs.index"
#define KEY_LOG_INDEX_VERSION @"Log Index Version"
#define DIRTY_LOG_SET_NAME @"DirtyLogs.plist"
#define KEY_LOG_INDEX_VERSION @"Log Index Version"

// Version of the log index.  Increase this number to reset everyone's index.
#define CURRENT_LOG_VERSION 10
#define LOG_INDEX_STATUS_INTERVAL 20
#define LOG_CLEAN_SAVE_INTERVAL 2000
#define NEW_LOGFILE_TIMEOUT 600

#define LOG_VIEWER AILocalizedString(@"Chat Transcript Viewer", nil)
#define VIEW_LOGS_WITH_CONTACT AILocalizedString(@"View Chat Transcripts", nil)

#define LOG_VIEWER_IDENTIFIER @"LogViewer"

#define ENABLE_PROXIMITY_SEARCH TRUE

#pragma mark -
#pragma mark Private Interface
#pragma mark -

// GetMetadataForFile.m
NSData *CopyDataForURL(CFStringRef contentTypeUTI, NSURL *urlToFile);
CFStringRef CopyTextContentForFileData(CFStringRef contentTypeUTI, NSURL *urlToFile, NSData *fileData);

@interface AILoggerPlugin ()
// class methods
+ (NSString *)pathForLogsLikeChat:(AIChat *)chat;
+ (NSString *)fullPathForLogOfChat:(AIChat *)chat onDate:(NSDate *)date;
+ (NSString *)nameForLogWithObject:(NSString *)object onDate:(NSDate *)date;

// Installation methods
- (void)_configureMenuItems;
- (void)_initLogIndexing;
- (void)_upgradeLogExtensions;
- (void)_upgradeLogPermissions;
- (void)_reimportLogsToSpotlightIfNeeded;

//  Action methods
- (void)showLogViewer:(id)sender;
- (void)showLogViewerToSelectedContact:(id)sender;
- (void)showLogViewerToSelectedContextContact:(id)sender;
- (void)showLogViewerForActiveChat:(id)sender;
- (void)showLogViewerForGroupChat:(id)sender;
- (void)showLogViewerAndReindex:(id)sender;
- (void)showLogNotification:(NSNotification *)inNotification;
- (void)_showLogViewerForLogAtPath:(NSString *)inPath;

// Logging
- (void)contentObjectAdded:(NSNotification *)notification;
- (void)chatOpened:(NSNotification *)notification;
- (void)chatClosed:(NSNotification *)notification;
- (void)chatWillDelete:(NSNotification *)notification;

// Logging Internals
- (AIXMLAppender *)_appenderForChat:(AIChat *)chat;
- (AIXMLAppender *)_existingAppenderForChat:(AIChat *)chat;
- (NSString *)keyForChat:(AIChat *)chat;
- (void)closeAppenderForChat:(AIChat *)chat;
- (void)finishClosingAppender:(NSString *)chatKey;

// Log Indexing
- (NSString *)_logIndexPath;
- (NSString *)_dirtyLogSetPath;
- (void)_loadDirtyLogSet;
- (void)_resetLogIndex;
- (void)_cancelClosingLogIndex;
- (void)_cleanDirtyLogs;
- (void)_dirtyAllLogs;

// Log Indexing Internals
- (void)_didCleanDirtyLogs;
- (void)_saveDirtyLogSet;
- (void)_markLogDirtyAtPath:(NSString *)path forChat:(AIChat *)chat;

// cleanup
- (void)_closeLogIndex;
- (void)_flushIndex:(SKIndexRef)inIndex;

// properties
@property(strong, readwrite) NSMutableDictionary *activeAppenders;
@property(strong, readwrite) AIHTMLDecoder *xhtmlDecoder;
@property(strong, readwrite) NSDictionary *statusTranslation;
@property(strong, readwrite) NSMutableSet *dirtyLogSet;
@property(assign, readwrite) BOOL logHTML;
@property(assign, readwrite) BOOL indexingAllowed;
@property(assign, readwrite) BOOL loggingEnabled;
@property(assign, readwrite) BOOL canCloseIndex;
@property(assign, readwrite) BOOL canSaveDirtyLogSet;
@property(assign, readwrite) BOOL indexIsFlushing;
@property(assign, readwrite) BOOL isIndexing;
@property(assign, readwrite) SInt64 logsToIndex;
@property(assign, readwrite) SInt64 logsIndexed;
@end

#pragma mark Private Function Prototypes
void runWithAutoreleasePool(dispatch_block_t block);
static inline dispatch_block_t blockWithAutoreleasePool(dispatch_block_t block);
NSComparisonResult sortPaths(NSString *path1, NSString *path2, void *context);

#pragma mark -
#pragma mark Static Globals
#pragma mark -
// The base directory of all logs
static NSString *logBasePath = nil;
// If the usual Logs folder path refers to an alias file, this is that path, and logBasePath is the destination of the
// alias; otherwise, this is nil and logBasePath is the usual Logs folder path.
static NSString *logBaseAliasPath = nil;

#pragma mark Dispatch
static dispatch_queue_t defaultDispatchQueue;

static dispatch_queue_t dirtyLogSetMutationQueue;
static dispatch_queue_t searchIndexQueue;
static dispatch_queue_t activeAppendersMutationQueue;
static dispatch_queue_t addToSearchKitQueue;

static dispatch_queue_t ioQueue;

static dispatch_group_t logIndexingGroup;
static dispatch_group_t closingIndexGroup;
static dispatch_group_t logAppendingGroup;
static dispatch_group_t loggerPluginGroup;

static dispatch_semaphore_t jobSemaphore;
static dispatch_semaphore_t logLoadingPrefetchSemaphore; // limit prefetching log data to N-1 ahead

@implementation AILoggerPlugin
@synthesize dirtyLogSet, indexingAllowed, loggingEnabled, logsToIndex, logsIndexed, canCloseIndex, canSaveDirtyLogSet,
	activeAppenders, logHTML, xhtmlDecoder, statusTranslation, isIndexing, indexIsFlushing;

#pragma mark -
#pragma mark Public Methods
#pragma mark -
#pragma mark Overridden AIPlugin Methods
- (void)installPlugin
{
	userTriggeredReindex = NO;
	self.indexingAllowed = YES;
	self.canCloseIndex = YES;
	self.loggingEnabled = NO;
	self.canSaveDirtyLogSet = YES;
	self.isIndexing = NO;
	self.indexIsFlushing = NO;
	logIndex = nil;
	self.activeAppenders =
}

@end
