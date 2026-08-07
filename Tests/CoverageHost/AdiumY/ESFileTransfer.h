/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * ESFileTransfer class for NEHUserNotificationPlugin.m to compile without an AdiumY.framework
 * binary. The TU only reads displayFilename/uniqueID and reveals a transfer looked up by ID.
 */
#import <Foundation/Foundation.h>

#import <AdiumY/AIContentMessage.h>

@interface ESFileTransfer : AIContentMessage
+ (ESFileTransfer *)existingFileTransferWithID:(NSString *)fileTransferID;
@property(readonly, nonatomic) NSString *displayFilename;
@property(readonly, nonatomic) NSString *uniqueID;
- (void)reveal;
@end
