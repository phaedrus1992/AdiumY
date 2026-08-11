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

#import "AISystemNetworkDefaults.h"
#import "AIApplicationAdditions.h"
#import "AIKeychain.h"
#import "AIStringUtilities.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <SystemConfiguration/SystemConfiguration.h>

/* Fetch a proxy auto-configuration (PAC) script synchronously and return it as a UTF-8 string, or
 * nil when the response is truncated or otherwise unusable. An NSURLSession data task is used so
 * the response's declared Content-Length is available; stringWithContentsOfURL: exposes no
 * response and cannot detect a truncated body (issue #279). AIUtilities cannot import the Adium
 * framework's AIHTTPDownloadValidationErrorForTruncatedDownload, so the received-vs-declared rule
 * is inlined: a non-positive declared length (including NSURLResponseUnknownLength, -1) carries no
 * size contract, and the body is truncated exactly when receivedBytes < declaredLength. */
static NSString *AIProxyAutoConfigScriptForURL(NSURL *pacURL)
{
	if (pacURL == nil) {
		return nil;
	}
	__block NSData *scriptData = nil;
	__block NSURLResponse *response = nil;
	__block NSError *error = nil;
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	NSURLSessionDataTask *task =
		[[NSURLSession sharedSession] dataTaskWithURL:pacURL
									completionHandler:^(NSData *data, NSURLResponse *urlResponse, NSError *fetchError) {
										scriptData = data;
										response = urlResponse;
										error = fetchError;
										dispatch_semaphore_signal(semaphore);
									}];
	[task resume];
	dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

	if (error != nil || scriptData == nil) {
		return nil;
	}

	/* Reject a body whose received byte count falls short of the response's declared non-zero size
	 * rather than evaluating it as a PAC script (issue #279). */
	long long declaredLength = [response expectedContentLength];
	if (declaredLength > 0 && (long long)[scriptData length] < declaredLength) {
		NSLog(@"PAC script download was truncated: received %lld of %lld declared bytes.",
			  (long long)[scriptData length], declaredLength);
		return nil;
	}

	return [[NSString alloc] initWithData:scriptData encoding:NSUTF8StringEncoding];
}

@implementation AISystemNetworkDefaults

+ (NSDictionary *)systemProxySettingsDictionaryForType:(ProxyType)proxyType forServer:(NSString *)hostName
{
	NSMutableDictionary *systemProxySettingsDictionary = nil;
	NSDictionary *proxyDict = nil;

	CFStringRef enableKey;
	int enable;

	CFStringRef portKey;
	NSNumber *portNum = nil;

	CFStringRef proxyKey;
	NSString *hostString;

	SecProtocolType protocolType;

	switch (proxyType) {
	case Proxy_HTTP: {
		enableKey = kSCPropNetProxiesHTTPEnable;
		portKey = kSCPropNetProxiesHTTPPort;
		proxyKey = kSCPropNetProxiesHTTPProxy;
		protocolType = kSecProtocolTypeHTTPProxy;
		break;
	}
	case Proxy_SOCKS4:
	case Proxy_SOCKS5: {
		enableKey = kSCPropNetProxiesSOCKSEnable;
		portKey = kSCPropNetProxiesSOCKSPort;
		proxyKey = kSCPropNetProxiesSOCKSProxy;
		protocolType = kSecProtocolTypeSOCKS;
		break;
	}
	case Proxy_HTTPS: {
		enableKey = kSCPropNetProxiesHTTPSEnable;
		portKey = kSCPropNetProxiesHTTPSPort;
		proxyKey = kSCPropNetProxiesHTTPSProxy;
		protocolType = kSecProtocolTypeHTTPSProxy;
		break;
	}
	case Proxy_FTP: {
		enableKey = kSCPropNetProxiesFTPEnable;
		portKey = kSCPropNetProxiesFTPPort;
		proxyKey = kSCPropNetProxiesFTPProxy;
		protocolType = kSecProtocolTypeFTPProxy;
		break;
	}
	case Proxy_RTSP: {
		enableKey = kSCPropNetProxiesRTSPEnable;
		portKey = kSCPropNetProxiesRTSPPort;
		proxyKey = kSCPropNetProxiesRTSPProxy;
		protocolType = kSecProtocolTypeRTSPProxy;
		break;
	}
	default: {
		return nil;
		break;
	}
	}

	if ((proxyDict = CFBridgingRelease(SCDynamicStoreCopyProxies(NULL)))) {

		// Enabled?
		enable = [[proxyDict objectForKey:(__bridge NSString *)enableKey] intValue];
		if (enable) {

			// Host
			hostString = [proxyDict objectForKey:(__bridge NSString *)proxyKey];
			if (hostString) {

				// Port
				portNum = [proxyDict objectForKey:(__bridge NSString *)portKey];
				if (portNum) {
					NSDictionary *authDict;

					systemProxySettingsDictionary =
						[NSMutableDictionary dictionaryWithObjectsAndKeys:hostString, @"Host", portNum, @"Port", nil];

					// User name & password if applicable
					NSError *error = nil;
					authDict = [[AIKeychain defaultKeychain_error:&error] dictionaryFromKeychainForServer:hostString
																								 protocol:protocolType
																									error:&error];
					if (authDict) {
						[systemProxySettingsDictionary addEntriesFromDictionary:authDict];
					}

					if (error) {
						NSDictionary *userInfo = [error userInfo];
						NSLog(@"Could not get username and password for proxy: %@ returned %ld (%@)",
							  [userInfo objectForKey:AIKEYCHAIN_ERROR_USERINFO_SECURITYFUNCTIONNAME],
							  (long)[error code], [userInfo objectForKey:AIKEYCHAIN_ERROR_USERINFO_ERRORDESCRIPTION]);
					}
				}
			}

		} else {
			// Check for a PAC configuration
			enable = [[proxyDict objectForKey:(__bridge NSString *)kSCPropNetProxiesProxyAutoConfigEnable] boolValue];
			if (enable) {
				NSString *pacFile =
					[proxyDict objectForKey:(__bridge NSString *)kSCPropNetProxiesProxyAutoConfigURLString];

				if (pacFile) {
					CFURLRef url = (__bridge CFURLRef)
						[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", hostName ?: @"google.com"]];
					NSString *scriptStr = AIProxyAutoConfigScriptForURL([NSURL URLWithString:pacFile]);

					if (url && scriptStr) {
						NSArray *proxies;
						// The following note is from Apple's CFProxySupportTool:
						// Work around <rdar://problem/5530166>.  This dummy call to
						// CFNetworkCopyProxiesForURL initialise some state within CFNetwork
						// that is required by CFNetworkCopyProxiesForAutoConfigurationScript.
						CFRelease(CFNetworkCopyProxiesForURL(url, (__bridge CFDictionaryRef) @{}));

						CFErrorRef error = NULL;
						proxies = CFBridgingRelease(CFNetworkCopyProxiesForAutoConfigurationScript(
							(__bridge CFStringRef)scriptStr, url, &error));

						if (error) {
							CFStringRef description = CFErrorCopyDescription(error);

							NSLog(@"Tried to get PAC, but got error: %@ %ld %@", CFErrorGetDomain(error),
								  CFErrorGetCode(error), description);

							CFRelease(description);
							CFRelease(error);
						} else if (proxies && proxies.count) {
							proxyDict = [proxies objectAtIndex:0];

							systemProxySettingsDictionary = [NSMutableDictionary
								dictionaryWithObjectsAndKeys:[proxyDict
																 objectForKey:(__bridge NSString *)kCFProxyHostNameKey],
															 @"Host",
															 [proxyDict objectForKey:(__bridge NSString *)
																						 kCFProxyPortNumberKey],
															 @"Port",
															 [proxyDict
																 objectForKey:(__bridge NSString *)kCFProxyUsernameKey],
															 @"Username",
															 [proxyDict
																 objectForKey:(__bridge NSString *)kCFProxyPasswordKey],
															 @"Password", nil];
						}
					}
				}
			}
		}
		// Could check and process kSCPropNetProxiesExceptionsList here, which returns: CFArray[CFString]
	}

	return systemProxySettingsDictionary;
}

@end
