/*
 * Stub for the standalone CoverageHost test target. libpurple is not built for the test bundle;
 * this provides just enough of the libpurple type surface for headers that reference it
 * (SLPurpleCocoaAdapter.h) to compile. Opaque struct typedefs cover the pointer usage; the
 * message-flag enums are collapsed to NSInteger.
 */
#import <Cocoa/Cocoa.h>

typedef NSInteger PurpleMessageFlags;
typedef NSInteger PurpleNotifyMsgType;

typedef struct _PurpleXfer PurpleXfer;
typedef struct _PurpleConversation PurpleConversation;
typedef struct _PurpleBuddy PurpleBuddy;
typedef struct _PurpleAccount PurpleAccount;
typedef struct _PurpleSslConnection PurpleSslConnection;
