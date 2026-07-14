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

#import "ESFileTransferRequestPromptController.h"
#import "ESFileTransfer.h"
#import "ESFileTransferController.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIListContact.h>

@interface ESFileTransferRequestPromptController ()
- (id)initForFileTransfer:(ESFileTransfer *)inFileTransfer notifyingTarget:(id)inTarget selector:(SEL)inSelector;
@end

@implementation ESFileTransferRequestPromptController

/*!
 * @brief Display a prompt for a file transfer to save, save as, or cancel
 *
 * @param inFileTransfer The file transfer
 * @param inTarget The target on which inSelector will be called
 * @param inSelector A selector, which must accept two arguments. The first will be inFileTransfer. The second will be
 * the filename to save to, or nil to cancel.
 */
+ (void)displayPromptForFileTransfer:(ESFileTransfer *)inFileTransfer
					 notifyingTarget:(id)inTarget
							selector:(SEL)inSelector
{}
}

- (ESFileTransfer *)fileTransfer
{
	return fileTransfer;
}

@end
