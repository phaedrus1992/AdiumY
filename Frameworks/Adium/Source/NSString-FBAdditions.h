//
//  NSString-FBAdditions.h
//  Adium
//
//  Category providing base writing direction detection via FriBidi.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (FBAdditions)

/// Returns the base writing direction of the receiver by scanning
/// the first strong directional character with the FriBidi library.
- (NSWritingDirection)baseWritingDirection;

@end

NS_ASSUME_NONNULL_END
