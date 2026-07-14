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

#import "AIDockController.h"
#import <AIUtilities/AIApplicationAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIIconState.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIStatusControllerProtocol.h>

#define DOCK_DEFAULT_PREFS @"DockPrefs"
#define ICON_DISPLAY_DELAY 0.1

#define LAST_ICON_UPDATE_VERSION @"Adium:Last Icon Update Version"

#define CONTINUOUS_BOUNCE_INTERVAL 0
#define SINGLE_BOUNCE_INTERVAL 999
#define NO_BOUNCE_INTERVAL 1000

#define DOCK_ICON_INTERNAL_PATH @"../Shared Images/"
#define DOCK_ICON_SHARED_IMAGES @"Shared Dock Icon Images"

@interface AIDockController ()
- (void)_setNeedsDisplay;
- (void)_buildIcon;
- (void)animateIcon:(NSTimer *)timer;
- (void)_singleBounce;
- (BOOL)_continuousBounce;
- (void)_stopBouncing;
- (BOOL)_bounceWithInterval:(double)delay;
- (AIIconState *)iconStateFromStateDict:(NSDictionary *)stateDict folderPath:(NSString *)folderPath;
- (void)updateAppBundleIcon;
- (void)updateDockView;
- (void)updateDockBadge;
- (void)animateDockIcon;

- (void)appWillChangeActive:(NSNotification *)notification;
- (void)bounceWithTimer:(NSTimer *)timer;
@end

@implementation AIDockController

// init and close
- (id)init
{
	if ((self = 
		bounceTimer = nil;
}

// Stop any continuous bouncing
if (currentAttentionRequest != -1) {

	if (overlay) {
		[image lockFocus];
		[overlay drawInRect:[view frame] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];
		[image unlockFocus];
	}

	[view setImage:image];
	[dockTile setContentView:view];
	[dockTile display];
}

- (void)updateDockBadge
{
	NSInteger contentCount = (showConversationCount ? [adium.chatController unviewedConversationCount]
													: [adium.chatController unviewedContentCount]);
	if (contentCount > 0 && shouldBadge)
		[dockTile setBadgeLabel:[NSString stringWithFormat:@"%ld", (long)contentCount]];
	else
		[dockTile setBadgeLabel:nil];
}

- (void)animateDockIcon
{
	[self updateDockBadge];

	if (adium.chatController.unviewedContentCount && animateDockIcon) {
		// If this is the first contact with unviewed content, animate the dock
		if (!unviewedState) {
			NSString *iconState;
			if (([adium.statusController.activeStatusState statusType] == AIInvisibleStatusType) &&
				[self currentIconSupportsIconStateNamed:@"InvisibleAlert"]) {
				iconState = @"InvisibleAlert";
			} else {
				iconState = @"Alert";
			}

			[self setIconStateNamed:iconState];
			unviewedState = YES;
		}
	} else if (unviewedState) {
		// If there are no more contacts with unviewed content, stop animating the dock
		[self removeIconStateNamed:@"Alert"];
		[self removeIconStateNamed:@"InvisibleAlert"];
		unviewedState = NO;
	}
}

/*!
 * @brief When a chat has unviewed content update the badge and maybe start/stop the animation
 */
- (NSSet *)updateChat:(AIChat *)inChat keys:(NSSet *)inModifiedKeys silent:(BOOL)silent
{
	if (inModifiedKeys == nil || [inModifiedKeys containsObject:KEY_UNVIEWED_CONTENT]) {
		[self animateDockIcon];
	}

	return nil;
}

@end
