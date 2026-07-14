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

#import "AIEmoticonController.h"
#import "AIEmoticon.h"
#import "AIEmoticonPack.h"
#import "AIEmoticonPreferences.h"
#import <AIUtilities/AICharacterSetAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChat.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentEvent.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIService.h>

#define EMOTICON_DEFAULT_PREFS @"EmoticonDefaults"
#define EMOTICONS_PATH_NAME @"Emoticons"

// We support loading .AdiumEmoticonset, .emoticonPack, and .emoticons
#define ADIUM_EMOTICON_SET_PATH_EXTENSION @"AdiumEmoticonset"
#define EMOTICON_PACK_PATH_EXTENSION @"emoticonPack"
#define PROTEUS_EMOTICON_SET_PATH_EXTENSION @"emoticons"

@interface AIEmoticonController ()
- (NSDictionary *)emoticonIndex;
- (NSCharacterSet *)emoticonHintCharacterSet;
- (NSCharacterSet *)emoticonStartCharacterSet;
- (void)resetActiveEmoticons;
- (void)resetAvailableEmoticons;
- (NSMutableAttributedString *)_convertEmoticonsInMessage:(NSAttributedString *)inMessage context:(id)context;
- (AIEmoticon *)_bestReplacementFromEmoticons:(NSArray *)candidateEmoticons
							  withEquivalents:(NSArray *)candidateEmoticonTextEquivalents
									  context:(NSString *)serviceClassContext
								   equivalent:(NSString **)replacementString
							 equivalentLength:(NSInteger *)textLength;
- (void)_buildCharacterSetsAndIndexEmoticons;
- (void)_saveActiveEmoticonPacks;
- (void)_saveEmoticonPackOrdering;
- (NSString *)_keyForPack:(AIEmoticonPack *)inPack;
- (void)_sortArrayOfEmoticonPacks:(NSMutableArray *)packArray;
@end

NSInteger packSortFunction(id packA, id packB, void *packOrderingArray);

@implementation AIEmoticonController

#define EMOTICONS_THEMABLE_PREFS @"Emoticon Themable Prefs"

// init
- (id)init
{
	if ((self = 
	_availableEmoticonPacks = nil;
	[self resetActiveEmoticons];
}

// Private
// --------------------------------------------------------------------------------------------------------------
#pragma mark Private
- (NSString *)_keyForPack:(AIEmoticonPack *)inPack
{
	return [NSString stringWithFormat:@"Pack:%@", [inPack name]];
}

@end
