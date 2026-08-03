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

#import "AIPurpleCertificateTrustWarningAlert.h"
#import "ESPurpleJabberAccount.h"
#import <AdiumY/AIAccountControllerProtocol.h>
#import <Security/SecPolicy.h>
#import <SecurityInterface/SFCertificateTrustPanel.h>

// #define ALWAYS_SHOW_TRUST_WARNING

@interface AIPurpleCertificateTrustWarningAlert () {
	id _selfRetain; /* keep ourselves alive while the trust panel is open */
}
- (id)initWithAccount:(AIAccount *)account
			 hostname:(NSString *)hostname
		 certificates:(CFArrayRef)certs
	   resultCallback:(void (*)(gboolean trusted, void *userdata))_query_cert_cb
			 userData:(void *)ud;
- (IBAction)showWindow:(id)sender;
- (void)runTrustPanelOnWindow:(NSWindow *)window;
- (void)certificateTrustSheetDidEnd:(SFCertificateTrustPanel *)trustpanel
						 returnCode:(NSInteger)returnCode
						contextInfo:(void *)contextInfo;
@end

@interface SFCertificateTrustPanel (SecretsIKnow)
- (void)setInformativeText:(NSString *)inString;
@end

@implementation AIPurpleCertificateTrustWarningAlert

+ (void)displayTrustWarningAlertWithAccount:(AIAccount *)account
								   hostname:(NSString *)hostname
							   certificates:(CFArrayRef)certs
							 resultCallback:(void (*)(gboolean trusted, void *userdata))_query_cert_cb
								   userData:(void *)ud
{
	if ([hostname caseInsensitiveCompare:@"talk.google.com"] == NSOrderedSame &&
		![[account preferenceForKey:KEY_JABBER_FORCE_OLD_SSL group:GROUP_ACCOUNT_STATUS] boolValue]) {
		NSString *UID = account.UID;
		NSRange startOfDomain = [UID rangeOfString:@"@"];

		if (startOfDomain.location == NSNotFound || ([[UID substringFromIndex:NSMaxRange(startOfDomain)]
														 caseInsensitiveCompare:@"gmail.com"] == NSOrderedSame)) {
			/* Google Talk accounts end up with a cert signed using gmail.com as the server.
			 * However, Google For Domains accounts are signed using talk.google.com
			 */
			hostname = @"gmail.com";
		} else if ([[UID substringFromIndex:NSMaxRange(startOfDomain)] caseInsensitiveCompare:@"googlemail.com"] ==
				   NSOrderedSame) {
			/* There are three certificates, as far as I (am) know. Maybe we should ask Sean for confirmation. */
			hostname = @"googlemail.com";
		}
	}

	AIPurpleCertificateTrustWarningAlert *alert = [[self alloc] initWithAccount:account
																	   hostname:hostname
																   certificates:certs
																 resultCallback:_query_cert_cb
																	   userData:ud];
	alert->_selfRetain = alert;
	[alert showWindow:nil];
}

- (id)initWithAccount:(AIAccount *)_account
			 hostname:(NSString *)_hostname
		 certificates:(CFArrayRef)certs
	   resultCallback:(void (*)(gboolean trusted, void *userdata))_query_cert_cb
			 userData:(void *)ud
{
	if ((self = [super init])) {
		query_cert_cb = _query_cert_cb;

		certificates = certs;
		CFRetain(certificates);
		trustRef = NULL;

		account = _account;
		hostname = [_hostname copy];

		userdata = ud;
	}
	return self;
}

- (void)dealloc
{
	if (certificates != NULL) {
		CFRelease(certificates);
	}
	if (trustRef != NULL) {
		CFRelease(trustRef);
	}
}

- (IBAction)showWindow:(id)sender
{
	NSAssert(UINT_MAX > [hostname length], @"More string data than libpurple can handle.  Abort.");

	// Build an SSL policy bound to the hostname we expect, so the trust evaluation verifies the
	// server's identity as well as the certificate chain. (Replaces the deprecated
	// SecPolicySearchCreate/SecPolicySearchCopyNext/SecPolicySetValue dance with SecPolicyCreateSSL.)
	SecPolicyRef policyRef = SecPolicyCreateSSL(true, (__bridge CFStringRef)hostname);

	OSStatus err = SecTrustCreateWithCertificates(certificates, policyRef, &trustRef);
	CFRelease(policyRef);

	if (err != noErr) {
		NSBeep();
		_selfRetain = nil;
		return;
	}

	// Test whether we aren't already trusting this certificate.
	BOOL trusted = SecTrustEvaluateWithError(trustRef, NULL);

	// A RecoverableTrustFailure (or an unrelated OtherError) can be argued with the user;
	// a FatalTrustFailure or Invalid result means the user can't fix it. (Replaces a
	// comparison against errSecInvalid, which no longer exists in the Security SDK.)
	SecTrustResultType result = kSecTrustResultInvalid;
	BOOL recoverable = NO;
	if (SecTrustGetTrustResult(trustRef, &result) == noErr) {
		recoverable = (result == kSecTrustResultRecoverableTrustFailure) || (result == kSecTrustResultOtherError);
	}

	if (trusted) {
#ifndef ALWAYS_SHOW_TRUST_WARNING
		// Trust ok, go right ahead.
		query_cert_cb(true, userdata);
		_selfRetain = nil;
		return;
#endif
		// ALWAYS_SHOW_TRUST_WARNING: fall through and show the panel even for trusted certificates.
	}

	if (trusted || recoverable) {
		// Trust broken, perhaps argue with the user. Show on an independent window.
#define TRUST_PANEL_WIDTH 535
		NSWindow *fakeWindow =
			[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, TRUST_PANEL_WIDTH, 1)
										styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskMiniaturizable)
										  backing:NSBackingStoreBuffered
											defer:NO];
		[fakeWindow center];
		[fakeWindow setTitle:AILocalizedString(@"Verify Certificate", nil)];

		[self runTrustPanelOnWindow:fakeWindow];
		[fakeWindow makeKeyAndOrderFront:nil];
	} else {
		// Trust broken and not recoverable (e.g. an invalid certificate); the user can't fix it.
		query_cert_cb(false, userdata);
		_selfRetain = nil;
	}
}

- (void)runTrustPanelOnWindow:(NSWindow *)window
{
	SFCertificateTrustPanel *trustPanel = [[SFCertificateTrustPanel alloc] init];

	// this could probably be used for a more detailed message:
	//	CFArrayRef certChain;
	//	CSSM_TP_APPLE_EVIDENCE_INFO *statusChain;
	//	err = SecTrustGetResult(trustRef, &result, &certChain, &statusChain);

	NSString *title;
	NSString *informativeText = [NSString
		stringWithFormat:AILocalizedString(@"The certificate of the server %@ is not trusted, which means that the "
										   @"server's identity cannot be automatically verified. Do you want to "
										   @"continue connecting?\n\nFor more information, click \"Show Certificate\".",
										   nil),
						 hostname];
	if ([trustPanel respondsToSelector:@selector(setInformativeText:)]) {
		[trustPanel setInformativeText:informativeText];
		title = [NSString
			stringWithFormat:AILocalizedString(@"AdiumY can't verify the identity of \"%@\".", nil), hostname];
	} else {
		/* We haven't seen a version of SFCertificateTrustPanel which doesn't respond to setInformativeText:, but we're
		 * using a private call found via class-dump, so have a sane backup strategy in case it changes.
		 */
		title = informativeText;
	}

	[trustPanel setAlternateButtonTitle:AILocalizedString(@"Cancel", nil)];
	[trustPanel setShowsHelp:YES];

	SecPolicyRef sslPolicy = SecPolicyCreateSSL(TRUE, (CFStringRef)hostname);
	if (sslPolicy) {
		[trustPanel setPolicies:(__bridge id)sslPolicy];
		CFRelease(sslPolicy);
	}

	[trustPanel beginSheetForWindow:window
					  modalDelegate:self
					 didEndSelector:@selector(certificateTrustSheetDidEnd:returnCode:contextInfo:)
						contextInfo:(__bridge void *)window
							  trust:trustRef
							message:title];
}

- (void)editAccountWindow:(NSWindow *)window didOpenForAccount:(AIAccount *)inAccount
{
	[self runTrustPanelOnWindow:window];
}

- (void)certificateTrustSheetDidEnd:(SFCertificateTrustPanel *)trustpanel
						 returnCode:(NSInteger)returnCode
						contextInfo:(void *)contextInfo
{
	BOOL didTrustCerficate = (returnCode == NSModalResponseOK);
	NSWindow *parentWindow = (__bridge NSWindow *)contextInfo;

	query_cert_cb(didTrustCerficate, userdata);

	[parentWindow performClose:nil];

	_selfRetain = nil;
}

@end
