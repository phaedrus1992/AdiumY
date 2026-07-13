#import <Cocoa/Cocoa.h>
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end
@implementation AppDelegate
@end
int main(int argc, const char *argv[])
{
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication];
		AppDelegate *delegate = [[AppDelegate alloc] init];
		[app setDelegate:delegate];
		[app run];
	}
	return 0;
}
