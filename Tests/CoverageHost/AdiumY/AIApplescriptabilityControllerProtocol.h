/*
 * Stub for the standalone CoverageHost test target. Provides just enough of the real
 * AIApplescriptabilityController protocol (via the real ESApplescriptabilityController.h) for
 * ESApplescriptContactAlertPlugin.m to compile without an AdiumY.framework binary. Only
 * runApplescriptAtPath:function:arguments:notifyingTarget:selector:userInfo: is used.
 */
#import <Foundation/Foundation.h>

#import <AdiumY/AIControllerProtocol.h>

@protocol AIApplescriptabilityController <AIController>
- (void)runApplescriptAtPath:(NSString *)inPath
					function:(NSString *)function
				   arguments:(NSArray *)arguments
			 notifyingTarget:(id)target
					selector:(SEL)selector
					userInfo:(id)userInfo;
@end
