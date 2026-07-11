#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIContactObserverManager.h>

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
