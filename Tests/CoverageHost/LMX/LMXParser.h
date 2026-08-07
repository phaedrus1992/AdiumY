/*
 * LMX is not vendored in this repository, but DCMessageContextDisplayPlugin.m imports
 * <LMX/LMXParser.h> and sends a small set of parser messages. This stub reproduces the surface the
 * plugin actually uses so the plugin TU compiles in the standalone test target; it is a header only
 * (no implementation), so the link symbol is supplied by a test shim.
 */

#ifndef ADIUM_TEST_LMXPARSER_H
#define ADIUM_TEST_LMXPARSER_H

#import <Foundation/Foundation.h>

enum LMXParseResult { LMXParsedIncomplete, LMXParsedCompletely };

@class LMXParser;

@protocol LMXParserDelegate
@optional
- (void)parser:(LMXParser *)parser elementEnded:(NSString *)elementName;
- (void)parser:(LMXParser *)parser foundCharacters:(NSString *)string;
- (void)parser:(LMXParser *)parser elementStarted:(NSString *)elementName attributes:(NSDictionary *)attributes;
@end

@interface LMXParser : NSObject
+ (LMXParser *)parser;
- (void)setDelegate:(id<LMXParserDelegate>)delegate;
- (void)setContextInfo:(void *)contextInfo;
- (void *)contextInfo;
- (enum LMXParseResult)parseChunk:(NSData *)chunk;
- (void)abortParsing;
@end

#endif /* ADIUM_TEST_LMXPARSER_H */
