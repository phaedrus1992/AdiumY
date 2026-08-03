#import <AdiumY/AIChatControllerProtocol.h>
#import <AdiumY/AIContactAlertsControllerProtocol.h>
#import <AdiumY/AIContactObserverManager.h>

#define DOCK_OVERLAY_ALERT_IDENTIFIER @"DockOverlay"

@interface AIDockNameOverlay : AIPlugin <AIActionHandler, AIListObjectObserver, AIChatObserver> {
  @private
	NSMutableArray *overlayObjectsArray;

	NSColor *signedOffColor;
	NSColor *signedOnColor;
	NSColor *unviewedContentColor;

	NSColor *backSignedOffColor;
	NSColor *backSignedOnColor;
	NSColor *backUnviewedContentColor;
}

@end
