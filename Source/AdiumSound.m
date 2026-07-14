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

#import "AdiumSound.h"
#import "AISoundController.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AISleepNotification.h>
#import <CoreAudio/AudioHardware.h>
#import <CoreServices/CoreServices.h>
#import <sys/sysctl.h>

#define SOUND_DEFAULT_PREFS @"SoundPrefs"
#define MAX_CACHED_SOUNDS 4 // Max cached sounds

@interface AdiumSound ()
- (void)_stopAndReleaseAllSounds;
- (void)_setVolumeOfAllSoundsTo:(float)inVolume;
- (void)cachedPlaySound:(NSString *)inPath;
- (void)_uncacheLeastRecentlyUsedSound;
- (NSString *)systemAudioDeviceID;
- (void)configureAudioContextForSound:(NSSound *)sound;
- (NSArray *)allSounds;
- (void)workspaceSessionDidBecomeActive:(NSNotification *)notification;
- (void)workspaceSessionDidResignActive:(NSNotification *)notification;
- (void)systemWillSleep:(NSNotification *)notification;
@end

static dispatch_queue_t soundPlayingQueue;

static OSStatus systemOutputDeviceDidChange(AudioObjectID inObjectID, UInt32 inNumberAddresses,
											const AudioObjectPropertyAddress inAddresses
	return noErr;
}
