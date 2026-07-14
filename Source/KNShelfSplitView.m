/*

BSD License

Copyright (c) 2006, Keith Anderson
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

*	Redistributions of source code must retain the above copyright notice,
	this list of conditions and the following disclaimer.
*	Redistributions in binary form must reproduce the above copyright notice,
	this list of conditions and the following disclaimer in the documentation
	and/or other materials provided with the distribution.
*	Neither the name of keeto.net or Keith Anderson nor the names of its
	contributors may be used to endorse or promote products derived
	from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


*/

/*
 * Modified to have a glass-style background; this requires the sourceListBackground image.
 */

#import "KNShelfSplitView.h"

#import "AIAdium.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIParagraphStyleAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>

#define DEFAULT_SHELF_WIDTH 200.0f
#define CONTROL_HEIGHT 22.0f
#define BUTTON_WIDTH 30.0f
#define THUMB_LINE_SPACING 2.0f
#define THUMB_LINE_COUNT 3
#define THUMB_WIDTH 13
#define RESIZE_BAR_EFFECTIVE_WIDTH 0.0f

#define CONTROL_PART_NONE 0
#define CONTROL_PART_ACTION_BUTTON 1
#define CONTROL_PART_CONTEXT_BUTTON 2
#define CONTROL_PART_RESIZE_THUMB 3
#define CONTROL_PART_RESIZE_BAR 4

#define TOOLBAR_TOGGLESHELF_IDENTIFIER @"Toggle Shelf"
#define TOGGLESHELF @"Toggle Shelf"
@implementation KNShelfSplitView

- (IBAction)toggleShelf:(id)sender
{
#pragma unused(sender)

	if (inString) {
		NSDictionary *attributes = [NSDictionary
			dictionaryWithObjectsAndKeys:[NSParagraphStyle styleWithAlignment:NSLeftTextAlignment
																lineBreakMode:NSLineBreakByTruncatingTail],
										 NSParagraphStyleAttributeName,
										 [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
										 nil];

		stringHeight = [NSAttributedString stringHeightForAttributes:attributes];
		attributedStringValue = [[NSAttributedString alloc] initWithString:inString attributes:attributes];
	} else {
		attributedStringValue = nil;
	}
	[self setNeedsDisplay:YES];
}
}

@end
