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

#import "AIContactInfoWindowController.h"
#import "AIContactInfoImageViewWithImagePicker.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageViewWithImagePicker.h>
#import <AIUtilities/AIOutlineViewAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITabViewAdditions.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIListOutlineView.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIModularPaneCategoryView.h>
#import <Adium/AIService.h>
#import <QuartzCore/QuartzCore.h>

#define CONTACT_INFO_NIB @"ContactInfoInspector"              // Filename of the contact info nib
#define KEY_INFO_WINDOW_FRAME @"Contact Info Inspector Frame" //
#define KEY_INFO_SELECTED_CATEGORY @"Selected Info Category"  //

#define CONTACT_INFO_THEME @"Contact Info List Theme"
#define CONTACT_INFO_LAYOUT @"Contact Info List Layout"

// Defines for the image files used by the toolbar segments
#define INFO_SEGMENT_IMAGE (@"Personal.tiff")
#define ADDRESS_BOOK_SEGMENT_IMAGE (@"get-info-address-book.tiff")
#define EVENTS_SEGMENT_IMAGE (@"get-info-events.tiff")
#define ADVANCED_SEGMENT_IMAGE (@"get-info-advanced.tiff")

enum segments {
	CONTACT_INFO_SEGMENT = 0,
	CONTACT_ADDRESSBOOK_SEGMENT = 1,
	CONTACT_EVENTS_SEGMENT = 2,
	CONTACT_ADVANCED_SEGMENT = 3,
	CONTACT_PLUGINS_SEGMENT = 4
};

@interface AIContactInfoWindowController (PRIVATE)
- (void)configureForDisplayedObject;

- (void)segmentSelected:(id)sender animate:(BOOL)shouldAnimate;
- (void)selectionChanged:(NSNotification *)notification;
- (void)setupToolbarSegments;
- (void)configureToolbarForListObject:(AIListObject *)inObject;
- (void)contactInfoListControllerSelectionDidChangeToListObject:(AIListObject *)listObject;

// View Animation
- (void)addInspectorPanel:(NSInteger)newSegment animate:(BOOL)doAnimate;
- (void)animateViewIn:(NSView *)aView;
- (void)animateViewOut:(NSView *)aView;
@end

@interface NSWindow (FakeLeopardAdditions)
- (void)setAutorecalculatesContentBorderThickness:(BOOL)autorecalculateContentBorderThickness forEdge:(NSRectEdge)edge;
- (float)contentBorderThicknessForEdge:(NSRectEdge)edge;
- (void)setContentBorderThickness:(float)borderThickness forEdge:(NSRectEdge)edge;
@end

@implementation AIContactInfoWindowController

static AIContactInfoWindowController *sharedContactInfoInstance = nil;

- (IBAction)segmentSelected:(id)sender
{}

@end
