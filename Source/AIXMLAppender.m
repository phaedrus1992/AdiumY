/*
 * AIXMLAppender.m
 *
 * Created by Colin Barrett on 12/23/05.
 *
 * This class is explicitly released under the BSD license with the following modification:
 * It may be used without reproduction of its copyright notice within The Adium Project.
 *
 * This class was created for use in the Adium project, which is released under the GPL.
 * The release of this specific class (AIXMLAppender) under BSD in no way changes the licensing of any other portion
 * of the Adium project.
 *
 ****
 Copyright (c) 2005, 2006 Colin Barrett
 Copyright (c) 2008 The Adium Team
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
 following conditions are met:

 Redistributions of source code must retain the above copyright notice, this list of conditions and the following
 disclaimer. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
 following disclaimer in the documentation and/or other materials provided with the distribution. Neither the name of
 Adium nor the names of its contributors may be used to endorse or promote products derived from this software without
 specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* TODO:
- Better error handling
- Possible support for "healing" a damaged XML file?
- Possibly refactor the initializeDocument... and appendElement... methods to return a BOOL and/or RBR an error code of
some kind to indicate success or failure.
- Instead of just testing for ' ' in -rootElementNameForFileAtPath:, use NSCharacterSet and be more general.
*/

#import "AIXMLAppender.h"
#import <AIUtilities/AISharedWriterQueue.h>
#import <Adium/AIXMLElement.h>
#define BSD_LICENSE_ONLY 1
#import <AIUtilities/AIStringAdditions.h>
#import <sys/stat.h>
#import <unistd.h>

#define XML_APPENDER_BLOCK_SIZE 4096

#define XML_MARKER @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
enum { xmlMarkerLength = 21, failedUtf8BomLength = 6 };

@interface AIXMLAppender ()
- (void)writeData:(NSData *)data seekBackLength:(NSInteger)seekBackLength;
- (NSString *)rootElementNameForFileAtPath:(NSString *)path;
@property(readwrite, strong, nonatomic) NSFileHandle *fileHandle;
@property(readwrite) BOOL initialized;
@property(readwrite, copy, nonatomic) AIXMLElement *rootElement;
@property(readwrite, copy, nonatomic) NSString *path;
- (void)prepareFileHandle;
@end

/*!
 * @class AIXMLAppender
 * @brief Provides multiple-write access to an XML document while maintaining wellformedness.
 *
 * Just a couple of general comments here;
 * - Despite the hackish nature of seeking backwards and overwriting, sometimes you need to cheat a little or things
 *   get a bit insane. That's what was happening, so a Grand Compromise was reached, and this is what we're doing.
 */

@implementation AIXMLAppender

@synthesize initialized;

@synthesize fileHandle = file;

/*!
 * @brief Create a new, autoreleased document.
 *
 * @param path Path to the file where XML document will be stored
 */
+ (id)documentWithPath:(NSString *)path rootElement:(AIXMLElement *)root
{
	return
		// Again, if we've reached the end of the file, we aren't initialized, so return nil
		if ([block length] == 0)
	{
		[handle closeFile];
		return nil;
	}

	scanner = [NSScanner scannerWithString:block];
}
while (!found)
	;

[handle closeFile];

// We've obviously found the root element name, so return a nonmutable copy.
return [NSString stringWithString:accumulator];
}

@end
