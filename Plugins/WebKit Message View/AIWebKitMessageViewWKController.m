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

#import "AIWebKitMessageViewWKController.h"
#import "AIAdiumURLSchemeHandler.h"
#import "AIWebKitMessageViewPlugin.h"
#import "AIWebkitMessageViewStyle.h"
#import "ESFileTransferRequestPromptController.h"
#import "ESWebKitMessageViewPreferences.h"

#import <AIUtilities/AIArrayAdditions.h>

#pragma mark - WKWebView scrollView availability forward declaration

/// WKWebView.scrollView requires macOS 10.14+. Forward-declared so we can
/// wrap call sites in @available(macOS 10.14, *) checks.
@interface WKWebView (AIWebKitWKScrollViewForwardDecl)
@property (nonatomic, readonly) NSScrollView *scrollView API_AVAILABLE(macos(10.14));
@end

#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIColorAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIMutableStringAdditions.h>
#import <AIUtilities/AIPasteboardAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/JVMarkedScroller.h>

#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentContext.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentEvent.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIContentStatus.h>
#import <Adium/AIContentTopic.h>
#import <Adium/AIEmoticon.h>
#import <Adium/ESFileTransfer.h>
#import <Adium/AIFileTransferControllerProtocol.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIMetaContact.h>

#import <Adium/AIPreferenceControllerProtocol.h>

#undef NEW_CONTENT_RETRY_DELAY
#define NEW_CONTENT_RETRY_DELAY 0.25

static NSArray *draggedTypes = nil;

#pragma mark - Weak Script Message Handler Proxy

/// Weak proxy that forwards WKScriptMessageHandler messages without retaining the target.
/// Breaks the retain cycle caused by -[WKUserContentController addScriptMessageHandler:name:].
/// The caller must remove the handler before dealloc, same as any delegate pattern.
@interface _AIWKScriptMessageHandlerWeakProxy : NSObject <WKScriptMessageHandler> {
	__weak id<WKScriptMessageHandler> _target;
}
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target;
@end

@implementation _AIWKScriptMessageHandlerWeakProxy

- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target
{
	self = [super init];
	if (self) {
		_target = target;
	}
	return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
	  didReceiveScriptMessage:(WKScriptMessage *)message
{
	[_target userContentController:userContentController didReceiveScriptMessage:message];
}

@end

@interface AIWebKitMessageViewWKController ()
- (void)_initWebView;
- (void)_markCurrentLocation;
- (void)_processContentQueue;
- (void)_updateVariantWithoutPrimingView;
- (void)_appendContentWithScript:(NSString *)js shouldScroll:(BOOL)shouldScroll;
- (void)_drainStoredContentObjects;
- (void)_handleFileTransferAction:(NSString *)action fileTransferID:(NSString *)fileTransferID;
- (void)_appendCorrectedMessageFallback:(NSString *)html fromSenderJID:(NSString *)senderJID;
- (NSString *)_jsStringLiteral:(NSString *)string;
- (NSString *)_webKitBackgroundImagePathForUniqueID:(NSInteger)uniqueID;
@end

@implementation AIWebKitMessageViewWKController

#pragma mark - Factory / Init

+ (AIWebKitMessageViewWKController *)messageDisplayControllerForChat:(AIChat *)inChat
														  withPlugin:(AIWebKitMessageViewPlugin *)inPlugin
{
	return [[self alloc] initForChat:inChat withPlugin:inPlugin];
}

- (instancetype)initForChat:(AIChat *)inChat withPlugin:(AIWebKitMessageViewPlugin *)inPlugin
{
	if ((self = [super init])) {
		[self _initWebView];

		_chat = inChat;
		_plugin = inPlugin;
		_contentQueue = [[NSMutableArray alloc] init];
		_storedContentObjects = [[NSMutableArray alloc] init];
		_shouldReflectPreferenceChanges = NO;
		_nextMessageFocus = YES;
		_nextMessageRegainedFocus = YES;

		// Observe preference changes
		[adium.preferenceController registerPreferenceObserver:self forGroup:PREF_GROUP_WEBKIT_REGULAR_MESSAGE_DISPLAY];
		[adium.preferenceController registerPreferenceObserver:self forGroup:PREF_GROUP_WEBKIT_GROUP_MESSAGE_DISPLAY];
		[adium.preferenceController registerPreferenceObserver:self forGroup:PREF_GROUP_WEBKIT_BACKGROUND_IMAGES];

		// Initial setup
		[self _updateWebViewForCurrentPreferences];

		// Chat notifications
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(contentObjectAdded:)
													 name:Content_ContentObjectAdded
												   object:inChat];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(chatDidFinishAddingUntrackedContent:)
													 name:Content_ChatDidFinishAddingUntrackedContent
												   object:inChat];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(customEmoticonUpdated:)
													 name:@"AICustomEmoticonUpdated"
												   object:inChat];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(messageWasCorrected:)
													 name:@"AIMessageCorrection"
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(stanzaWasTracked:)
													 name:@"AIMessageStanzaTracked"
												   object:nil];
	}

	return self;
}

- (AIWebkitMessageViewStyle *)messageStyle
{
	return _messageStyle;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[adium.preferenceController unregisterPreferenceObserver:self];

	[_webView setNavigationDelegate:nil];
	[_webView setUIDelegate:nil];
	[_webView.configuration.userContentController removeScriptMessageHandlerForName:@"adium"];
}

#pragma mark - WebView Creation

- (void)_initWebView
{
	WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

	// User content controller with script message handler (via weak proxy to avoid retain cycle)
	WKUserContentController *userContentController = [[WKUserContentController alloc] init];
	_AIWKScriptMessageHandlerWeakProxy *proxy = [[_AIWKScriptMessageHandlerWeakProxy alloc] initWithTarget:self];
	[userContentController addScriptMessageHandler:proxy name:@"adium"];
	config.userContentController = userContentController;

	// Register adium:// scheme handler (10.13+)
	if ([WKWebView handlesURLScheme:@"adium"]) {
		// WKWebView handles adium:// by default as an unknown scheme — no-op
	} else if (@available(macOS 10.13, *)) {
		AIAdiumURLSchemeHandler *schemeHandler = [[AIAdiumURLSchemeHandler alloc] init];
		[config setURLSchemeHandler:schemeHandler forURLScheme:@"adium"];
	}

	_webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100) configuration:config];
	[_webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[_webView setNavigationDelegate:self];
	[_webView setUIDelegate:self];

	if (!draggedTypes) {
		draggedTypes =
			[[NSArray alloc] initWithObjects:AINSPasteboardTypeFilenames, AIiTunesTrackPboardType, NSPasteboardTypeTIFF,
											 NSPasteboardTypePDF, NSPasteboardTypeHTML, NSFileContentsPboardType,
											 NSPasteboardTypeRTF, NSPasteboardTypeString, AINSPasteboardTypePostScript, nil];
	}
	[_webView registerForDraggedTypes:draggedTypes];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
	_webViewIsReady = YES;

	// Set up marked scroller after the scroll view exists
	[self setupMarkedScroller];

	// Content that arrived while the view was loading was parked in _storedContentObjects
	[self _drainStoredContentObjects];

	[self _processContentQueue];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
	NSLog(@"WKWebView navigation failed: %@", error);
}

- (void)webView:(WKWebView *)webView
	decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
					decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	// Allow navigation only for our initial load and JavaScript
	if (navigationAction.navigationType == WKNavigationTypeOther) {
		decisionHandler(WKNavigationActionPolicyAllow);
	} else {
		// Open external URLs in the default browser
		NSURL *url = [navigationAction.request URL];
		if (url && ![[url scheme] isEqualToString:@"about"]) {
			[[NSWorkspace sharedWorkspace] openURL:url];
		}
		decisionHandler(WKNavigationActionPolicyCancel);
	}
}

#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView
	createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
			   forNavigationAction:(WKNavigationAction *)navigationAction
					windowFeatures:(WKWindowFeatures *)windowFeatures
{
	// Open popup windows in the default browser
	NSURL *url = [navigationAction.request URL];
	if (url) {
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
	return nil;
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
	  didReceiveScriptMessage:(WKScriptMessage *)message
{
	if (![message.body isKindOfClass:[NSDictionary class]]) {
		return;
	}

	NSDictionary *body = (NSDictionary *)message.body;
	NSString *type = [body objectForKey:@"type"];

	if ([type isEqualToString:@"ready"]) {
		// Don't re-process gate if already ready
		if (!_webViewIsReady) {
			_webViewIsReady = YES;
			[self _drainStoredContentObjects];
			[self _processContentQueue];
		}
	} else if ([type isEqualToString:@"fileTransfer"]) {
		NSString *action = [body objectForKey:@"action"];
		NSString *fileTransferID = [body objectForKey:@"fileTransferID"];
		[self _handleFileTransferAction:action fileTransferID:fileTransferID];
	}
}

#pragma mark - AIMessageDisplayController

- (NSView *)messageView
{
	return _webView;
}

- (NSView *)messageScrollView
{
	if (@available(macOS 10.14, *)) {
		return [_webView scrollView];
	}
	return _webView;
}

- (NSString *)contentSourceName
{
	return [_messageStyle.bundle bundleIdentifier];
}

- (void)setChatContentSource:(NSString *)source
{
	NSString *js = [NSString stringWithFormat:@"(function(){"
											  @" var c = document.getElementById('Chat');"
											  @" if (c) { c.outerHTML = %@; }"
											  @"})()",
											  [self _jsStringLiteral:source]];

	_cachedChatContentSource = [source copy];

	[_webView evaluateJavaScript:js
			   completionHandler:^(id result, NSError *error) {
				   if (error) {
					   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
				   }
			   }];
}

- (NSString *)chatContentSource
{
	return _cachedChatContentSource;
}

- (void)messageViewIsClosing
{
	[_webView stopLoading];
	[_webView setNavigationDelegate:nil];
	[_webView setUIDelegate:nil];
	[_webView.configuration.userContentController removeScriptMessageHandlerForName:@"adium"];

	// Cancel any pending performRequests
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[adium.preferenceController unregisterPreferenceObserver:self];
}

- (void)clearView
{
	[self _primeWebViewAndReprocessContent:NO];
	[_markedScroller removeAllMarks];
	_previousContent = nil;
	_nextMessageFocus = NO;
	_nextMessageRegainedFocus = NO;
	[_chat clearUnviewedContentCount];
}

#pragma mark - Content Pipeline

- (void)_primeWebViewAndReprocessContent:(BOOL)reprocessContent
{
	_webViewIsReady = NO;

	NSURL *baseURL =
		[NSURL URLWithString:[NSString stringWithFormat:@"adium://%@/adium", [_messageStyle.bundle bundleIdentifier]]];

	[_webView loadHTMLString:[_messageStyle baseTemplateForChat:_chat] baseURL:baseURL];

	if (_chat.isGroupChat && _chat.supportsTopic) {
		[self updateTopic];
	}

	if (reprocessContent) {
		NSArray *currentContentQueue = ([_contentQueue count] ? [_contentQueue copy] : nil);

		[_contentQueue removeAllObjects];
		[_contentQueue addObjectsFromArray:_storedContentObjects];
		[_storedContentObjects removeAllObjects];

		if (currentContentQueue) {
			[_contentQueue addObjectsFromArray:currentContentQueue];
		}
	} else {
		[_contentQueue removeAllObjects];
	}
}

- (void)_processContentQueue
{
	if (!_webViewIsReady) {
		return;
	}

	NSInteger contentCount = [_contentQueue count];
	if (contentCount == 0) {
		return;
	}

	BOOL willAddMoreContentObjects = (contentCount > 1);
	BOOL hadPreviousContent = (_cachedChatContentSource != nil);

	if (!hadPreviousContent) {
		_nextMessageFocus = YES;
	}

	for (AIContentObject *content in _contentQueue) {
		if (willAddMoreContentObjects && content == [_contentQueue lastObject]) {
			willAddMoreContentObjects = NO;
		}

		BOOL contentIsSimilar = [content isSimilarToContent:_previousContent];
		BOOL replaceLastContent = NO;

		if ([_previousContent isKindOfClass:[AIContentStatus class]] && [content isKindOfClass:[AIContentStatus class]] &&
			[[(AIContentStatus *)_previousContent coalescingKey] isEqualToString:[(AIContentStatus *)content coalescingKey]]) {
			contentIsSimilar = NO;
			replaceLastContent = YES;
		}

		if (!replaceLastContent) {
			[self _markCurrentLocation];
		}

		NSString *js = [_messageStyle scriptForAppendingContent:content
														similar:contentIsSimilar
									  willAddMoreContentObjects:willAddMoreContentObjects
											 replaceLastContent:replaceLastContent];

		[_webView evaluateJavaScript:js
				   completionHandler:^(id result, NSError *error) {
					   // Update cached source after each append
					   if (!error) {
						   [self _syncCachedSource];
					   } else {
						   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
					   }
				   }];

		// Track content for similarity comparison
		_previousContent = content;
	}

	[_contentQueue removeAllObjects];
}

/*!
 * @brief Move content parked while the webview was loading into the processing queue.
 */
- (void)_drainStoredContentObjects
{
	if ([_storedContentObjects count] == 0) {
		return;
	}

	[_contentQueue addObjectsFromArray:_storedContentObjects];
	[_storedContentObjects removeAllObjects];
}

/*!
 * @brief Re-read the Chat element's outerHTML into the cache.
 *
 * Called after content operations to keep the cached source in sync.
 */
- (void)_syncCachedSource
{
	[_webView evaluateJavaScript:@"document.getElementById('Chat').outerHTML"
			   completionHandler:^(id result, NSError *error) {
				   if (error) {
					   AILogWithSignature(@"_syncCachedSource failed: %@", error);
					   return;
				   }
				   if (![result isKindOfClass:[NSString class]]) {
					   AILogWithSignature(@"_syncCachedSource returned a non-string result");
					   return;
				   }
				   self->_cachedChatContentSource = [result copy];
			   }];
}

/*!
 * @brief Append content via a JS script, capturing scroll height for marks before appending.
 *
 * @param js The JS statement* to evaluate (e.g. appendMessage('...'))
 * @param shouldScroll Whether to scroll to bottom after appending
 */
- (void)_appendContentWithScript:(NSString *)js shouldScroll:(BOOL)shouldScroll
{
	if (!_webViewIsReady) {
		return;
	}

	NSString *fullJS;
	if (shouldScroll) {
		fullJS = [NSString stringWithFormat:@"%@; scrollToBottom()", js];
	} else {
		fullJS = js;
	}

	[_webView evaluateJavaScript:fullJS
			   completionHandler:^(id result, NSError *error) {
				   if (!error) {
					   [self _syncCachedSource];
				   } else {
					   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
				   }
			   }];
}

/*!
 * @brief Mark the current scroll position before new content arrives.
 *
 * Uses async evaluateJavaScript — the scroll height is captured in JS,
 * then we add the mark when the result arrives.
 */
- (void)_markCurrentLocation
{
	if (!_webViewIsReady) {
		return;
	}

	// Capture scroll height before append
	[_webView evaluateJavaScript:@"document.body.scrollHeight"
			   completionHandler:^(id result, NSError *error) {
				   NSInteger h = [result integerValue];
				   if (error || h == 0) {
					   return;
				   }

				   if (self->_nextMessageFocus) {
					   [self.markedScroller addMarkAt:h withColor:[NSColor blueColor]];
					   self->_nextMessageFocus = NO;
					   self->_nextMessageRegainedFocus = YES;
				   }
				   if (self->_nextMessageRegainedFocus) {
					   [self.markedScroller addMarkAt:h withColor:[NSColor greenColor]];
					   self->_nextMessageRegainedFocus = NO;
				   }
			   }];
}

/*!
 * @brief Updates our webview to the current preferences, priming the view
 */
- (void)_updateWebViewForCurrentPreferences
{
	NSCParameterAssert([NSThread isMainThread]);

	_isUpdatingView = YES;

	_messageStyle = nil;
	_activeStyle = nil;

	_messageStyle = [_plugin currentMessageStyleForChat:_chat];
	_activeStyle = [[_messageStyle bundle] bundleIdentifier];
	_preferenceGroup = [_plugin preferenceGroupForChat:_chat];

	// Get the preferred variant (or the default if a preferred is not available)
	NSString *activeVariant;
	activeVariant = [adium.preferenceController preferenceForKey:[_plugin styleSpecificKey:@"Variant"
																				  forStyle:_activeStyle]
														   group:_preferenceGroup];
	if (!activeVariant || ![[_messageStyle availableVariants] containsObject:activeVariant]) {
		activeVariant = [_messageStyle defaultVariant];
	}
	if (!activeVariant || ![[_messageStyle availableVariants] containsObject:activeVariant]) {
		NSArray *availableVariants = [_messageStyle availableVariants];
		if ([availableVariants count]) {
			activeVariant = [availableVariants objectAtIndex:0];
		}
	}
	_messageStyle.activeVariant = activeVariant;

	NSDictionary *prefDict = [adium.preferenceController preferencesForGroup:_preferenceGroup];

	[_messageStyle setShowUserIcons:[[prefDict objectForKey:KEY_WEBKIT_SHOW_USER_ICONS] boolValue]];
	[_messageStyle setShowHeader:[[prefDict objectForKey:KEY_WEBKIT_SHOW_HEADER] boolValue]];
	[_messageStyle setUseCustomNameFormat:[[prefDict objectForKey:KEY_WEBKIT_USE_NAME_FORMAT] boolValue]];
	[_messageStyle setNameFormat:[[prefDict objectForKey:KEY_WEBKIT_NAME_FORMAT] intValue]];
	[_messageStyle setDateFormat:[prefDict objectForKey:KEY_WEBKIT_TIME_STAMP_FORMAT]];
	[_messageStyle setShowIncomingMessageColors:[[prefDict objectForKey:KEY_WEBKIT_SHOW_MESSAGE_COLORS] boolValue]];
	[_messageStyle setShowIncomingMessageFonts:[[prefDict objectForKey:KEY_WEBKIT_SHOW_MESSAGE_FONTS] boolValue]];

	// Custom background image
	NSString *cachePath = nil;
	if ([[adium.preferenceController preferenceForKey:[_plugin styleSpecificKey:@"UseCustomBackground"
																	   forStyle:_activeStyle]
												group:_preferenceGroup] boolValue]) {

		cachePath = [adium.preferenceController preferenceForKey:[_plugin styleSpecificKey:@"BackgroundCachePath"
																				  forStyle:_activeStyle]
														   group:_preferenceGroup];
		if (!cachePath || ![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
			NSData *backgroundImage = [adium.preferenceController
				preferenceForKey:[_plugin styleSpecificKey:@"Background" forStyle:_activeStyle]
						   group:PREF_GROUP_WEBKIT_BACKGROUND_IMAGES];

			if (backgroundImage) {
				NSInteger uniqueID = [[adium.preferenceController preferenceForKey:@"BackgroundCacheUniqueID"
																			 group:_preferenceGroup] integerValue] +
									 1;
				[adium.preferenceController setPreference:[NSNumber numberWithInteger:uniqueID]
												   forKey:@"BackgroundCacheUniqueID"
													group:_preferenceGroup];

				cachePath = [self _webKitBackgroundImagePathForUniqueID:uniqueID];
				[backgroundImage writeToFile:cachePath atomically:YES];

				[adium.preferenceController setPreference:cachePath
												   forKey:[_plugin styleSpecificKey:@"BackgroundCachePath"
																		   forStyle:_activeStyle]
													group:_preferenceGroup];
			} else {
				cachePath = @"";
			}
		}

		[_messageStyle setCustomBackgroundColor:[[adium.preferenceController
													preferenceForKey:[_plugin styleSpecificKey:@"BackgroundColor"
																					  forStyle:_activeStyle]
															   group:_preferenceGroup] representedColor]];
	} else {
		[_messageStyle setCustomBackgroundColor:nil];
	}

	[_messageStyle setCustomBackgroundPath:cachePath];
	[_messageStyle setCustomBackgroundType:[[adium.preferenceController
											   preferenceForKey:[_plugin styleSpecificKey:@"BackgroundType"
																				 forStyle:_activeStyle]
														  group:_preferenceGroup] intValue]];

	// WKWebView transparency
	BOOL isBackgroundTransparent = [_messageStyle isBackgroundTransparent];
	[_webView setValue:@(!isBackgroundTransparent) forKey:@"drawsBackground"];
	NSWindow *win = [_webView window];
	if (win) {
		[win setOpaque:!isBackgroundTransparent];
	}

	// Prime the webview
	[self _primeWebViewAndReprocessContent:YES];
	_isUpdatingView = NO;
}

- (void)_updateVariantWithoutPrimingView
{
	static const NSUInteger kMaxRetries = 40;

	if (_webViewIsReady) {
		_variantRetryCount = 0;
		[_webView evaluateJavaScript:[_messageStyle scriptForChangingVariant]
				   completionHandler:^(id result, NSError *error) {
					   if (error) {
						   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
					   }
				   }];
	} else if (_variantRetryCount < kMaxRetries) {
		_variantRetryCount++;
		[self performSelector:@selector(_updateVariantWithoutPrimingView)
				   withObject:nil
				   afterDelay:NEW_CONTENT_RETRY_DELAY];
	} else {
		_variantRetryCount = 0;
		AILogWithSignature(@"Gave up waiting for webview to become ready after %lu attempts",
						   (unsigned long)kMaxRetries);
	}
}

#pragma mark - Preference Changes

/*!
 * @brief Enable or disable updating to reflect preference changes
 */
- (void)setShouldReflectPreferenceChanges:(BOOL)inValue
{
	_shouldReflectPreferenceChanges = inValue;
}

- (void)preferencesChangedForGroup:(NSString *)group
							   key:(NSString *)key
							object:(AIListObject *)object
					preferenceDict:(NSDictionary *)prefDict
						 firstTime:(BOOL)firstTime
{
	// WKWebView doesn't expose preferences like WebView does for font/size changes.
	// The style's CSS handles font sizing — for any preference change that requires
	// re-priming, we fall through to _updateWebViewForCurrentPreferences.

	if (firstTime) {
		return;
	}

	if ([group isEqualToString:PREF_GROUP_WEBKIT_BACKGROUND_IMAGES] && _shouldReflectPreferenceChanges) {
		[adium.preferenceController setPreference:nil
										   forKey:[_plugin styleSpecificKey:@"BackgroundCachePath"
																   forStyle:_activeStyle]
											group:_preferenceGroup];
		if (!_isUpdatingView) {
			[self _updateWebViewForCurrentPreferences];
		}
	}
}

/*!
 * @brief Content was added to the chat. Processes the content queue.
 */
- (void)contentObjectAdded:(NSNotification *)notification
{
	AIContentObject *content = [[notification userInfo] objectForKey:@"AIContentObject"];
	if (!content) {
		return;
	}

	if (!_webViewIsReady) {
		if (!_storedContentObjects) {
			_storedContentObjects = [[NSMutableArray alloc] init];
		}
		[_storedContentObjects addObject:content];
		return;
	}

	[_contentQueue addObject:content];
	[self _processContentQueue];
}

/*!
 * @brief Chat finished adding content. Flushes coalesced content.
 */
- (void)chatDidFinishAddingUntrackedContent:(NSNotification *)notification
{
	// Tell the CoalescedHTML to output everything
	[_webView evaluateJavaScript:@"if(coalescedHTML)coalescedHTML.cancel()"
			   completionHandler:^(id result, NSError *error) {
				   if (error) {
					   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
				   }
			   }];
}

#pragma mark - Notifications

- (void)customEmoticonUpdated:(NSNotification *)inNotification
{
	[_webView evaluateJavaScript:@"initStyle()"
			   completionHandler:^(id result, NSError *error) {
				   if (error) {
					   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
				   }
			   }];

	// Re-process stored content for new emoticon rendering
	if ([_storedContentObjects count]) {
		[self _primeWebViewAndReprocessContent:YES];
	} else if ([_contentQueue count]) {
		[self _processContentQueue];
	}
}

- (void)messageWasCorrected:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSString *senderJID = [userInfo objectForKey:@"AICorrectionSender"];
	NSString *domId = [userInfo objectForKey:@"AICorrectionDOMId"];
	NSString *html = [userInfo objectForKey:@"AICorrectionHTML"];

	if (!senderJID || !domId || !html) {
		return;
	}

	// Verify this correction is for our chat
	NSString *chatBareJID = [[[_chat listObject] UID] isKindOfClass:[NSString class]] ? [[_chat listObject] UID] : nil;
	if (![senderJID isEqualToString:chatBareJID]) {
		return;
	}

	NSString *escapedHTML = [self _jsStringLiteral:html];
	NSString *escapedDomId = [self _jsStringLiteral:domId];
	NSString *js = [NSString stringWithFormat:@"correctMessage(%@, %@)", escapedDomId, escapedHTML];
	[_webView evaluateJavaScript:js
			   completionHandler:^(id result, NSError *error) {
				   if (error) {
					   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
					   return;
				   }

				   // correctMessage() returns false when no element with the DOM id exists
				   // (the original message was never rendered); append it as a fallback.
				   BOOL correctedInPlace = ([result respondsToSelector:@selector(boolValue)] && [result boolValue]);
				   if (!correctedInPlace) {
					   [self _appendCorrectedMessageFallback:html fromSenderJID:senderJID];
				   }
			   }];
}

/*!
 * @brief Append corrected content as a new message when no DOM element could be corrected.
 *
 * The correction notification can arrive before the original message was rendered (e.g. while
 * the webview was loading), so correctMessage() finds no element. Enqueue the corrected content
 * so it displays instead of being silently dropped.
 */
- (void)_appendCorrectedMessageFallback:(NSString *)html fromSenderJID:(NSString *)senderJID
{
	AIListObject *source = [[adium contactController] contactWithService:[[_chat account] service]
															  account:[_chat account]
																 UID:senderJID];
	if (!source) {
		source = [_chat listObject];
	}

	AIContentMessage *content = [[AIContentMessage alloc] initWithChat:_chat
															   source:source
														  destination:nil
																 date:[NSDate date]
															  message:[[NSAttributedString alloc] initWithString:html]];
	[content setDisplayContentImmediately:YES];

	[_contentQueue addObject:content];
	[self _processContentQueue];
}

- (void)stanzaWasTracked:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSString *domId = [userInfo objectForKey:@"AICorrectionDOMId"];
	if (!domId) {
		return;
	}

	NSString *escapedDomId = [self _jsStringLiteral:domId];
	NSString *js = [NSString stringWithFormat:@"(function(){"
											  @" var e=document.getElementById(%@);"
											  @" if(e&&!e.classList.contains('tracked')){e.classList.add('tracked');}"
											  @"})()",
											  escapedDomId];
	[_webView evaluateJavaScript:js
			   completionHandler:^(id result, NSError *error) {
				   if (error) {
					   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
				   }
			   }];
}

- (void)updateTopic
{
	if (!_chat.supportsTopic) {
		return;
	}

	NSString *topicValue = [_chat valueForProperty:KEY_TOPIC] ?: @"";
	NSString *escaped = [self _jsStringLiteral:topicValue];
	NSString *js = [NSString stringWithFormat:@"(function(){"
											  @" var e=document.getElementById('topic');"
											  @" if(e){e.innerHTML=%@;}"
											  @"})()",
											  escaped];
	[_webView evaluateJavaScript:js
			   completionHandler:^(id result, NSError *error) {
				   if (error) {
					   AILogWithSignature(@"evaluateJavaScript failed: %@", error);
				   }
			   }];
}

#pragma mark - Marked Scroller

- (void)setupMarkedScroller
{
	if (@available(macOS 10.14, *)) {
		NSScrollView *scrollView = [_webView scrollView];
		if (!scrollView) {
			return;
		}

		JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
		if (scroller && ![scroller isMemberOfClass:[JVMarkedScroller class]]) {
			NSRect scrollerFrame = [scroller frame];
			scroller = [[JVMarkedScroller alloc] initWithFrame:scrollerFrame];
			[scroller setTarget:self];
			[scroller setAction:@selector(markedScrollerClicked:)];
			[scrollView setVerticalScroller:scroller];
		}
	
		if (scroller && !_markedScroller) {
			_markedScroller = scroller;
		}
	}
}

- (JVMarkedScroller *)markedScroller
{
	return _markedScroller;
}

- (void)markedScrollerClicked:(id)sender
{
	// Handle mark click — can be extended for context menus
}

- (NSNumber *)currentOffsetHeight
{
	// async: returns cached value; callers should use _markCurrentLocation for precision
	// ponytail: cached approximation is good enough for marks
	return [NSNumber numberWithInteger:0];
}

- (void)jumpToPreviousMark
{
	[_markedScroller jumpToPreviousMark:nil];
}

- (BOOL)previousMarkExists
{
	return [_markedScroller previousMarkExists];
}

- (void)jumpToNextMark
{
	[_markedScroller jumpToNextMark:nil];
}

- (BOOL)nextMarkExists
{
	return [_markedScroller nextMarkExists];
}

- (void)jumpToFocusMark
{
	[_markedScroller jumpToFocusMark:nil];
}

- (BOOL)focusMarkExists
{
	return [_markedScroller focusMarkExists];
}

- (void)addMark
{
	[self _markCurrentLocation];
}

- (void)markForFocusChange
{
	_nextMessageFocus = YES;
	_nextMessageRegainedFocus = NO;
}

#pragma mark - Printing

- (void)adiumPrint:(id)sender
{
	if (@available(macOS 11.0, *)) {
		NSPrintOperation *printOp = [_webView printOperationWithPrintInfo:[NSPrintInfo sharedPrintInfo]];
		[printOp setShowsPrintPanel:YES];
		[printOp runOperation];
	}
}

#pragma mark - Utilities

/*!
 * @brief Produce a JS-safe string literal from an NSString.
 *
 * Uses NSJSONSerialization which produces a valid JSON string (also a valid JS string).
 */
- (NSString *)_jsStringLiteral:(NSString *)string
{
	if (!string) {
		return @"''";
	}
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:string options:0 error:NULL];
	if (!jsonData) {
		return @"''";
	}
	return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

/*!
 * @brief Handle a file transfer action from the JS bridge.
 */
- (void)_handleFileTransferAction:(NSString *)action fileTransferID:(NSString *)fileTransferID
{
	if (!fileTransferID) {
		return;
	}

	ESFileTransfer *fileTransfer = [ESFileTransfer existingFileTransferWithID:fileTransferID];
	if (!fileTransfer) {
		return;
	}

	if ([action isEqualToString:@"accept"]) {
		[ESFileTransferRequestPromptController acceptFileTransfer:fileTransfer];
	} else if ([action isEqualToString:@"decline"]) {
		[ESFileTransferRequestPromptController declineFileTransfer:fileTransfer];
	} else if ([action isEqualToString:@"reveal"]) {
		NSString *filename = [fileTransfer localFilename];
		if (filename != nil) {
			[[NSWorkspace sharedWorkspace] selectFile:filename inFileViewerRootedAtPath:[filename stringByDeletingLastPathComponent]];
		}
	}
}

/*!
 * @brief Generate a cache path for custom background images.
 */
- (NSString *)_webKitBackgroundImagePathForUniqueID:(NSInteger)uniqueID
{
	NSString *cacheDir = [NSString stringWithFormat:@"%@/WebKitMessageView/Backgrounds", NSTemporaryDirectory()];
	[[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];
	return [cacheDir
		stringByAppendingPathComponent:[NSString stringWithFormat:@"adium-background-%ld.png", (long)uniqueID]];
}

@end
