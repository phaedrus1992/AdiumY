/*
 * NSStream-based SSL-plugin for purple
 *
 * Copyright (c) 2024 Adium contributors
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * Replaces the original CDSA/SecureTransport-based implementation
 * with NSStream (CFStream) for TLS, which uses the system's modern
 * TLS stack (Network.framework on macOS 10.14+).
 */

#import <libpurple/internal.h>
#import <libpurple/debug.h>
#import <libpurple/plugin.h>
#import <libpurple/sslconn.h>
#import <libpurple/version.h>
#import <libpurple/signals.h>

#define SSL_CDSA_PLUGIN_ID "ssl-cdsa"

/* Backward-compatible constants for XMPP account code */
#define PURPLE_SSL_CDSA_BUGGY_TLS_WORKAROUND "ssl_cdsa_buggy_tls_workaround"
#define PURPLE_SSL_CDSA_BEAST_TLS_WORKAROUND "ssl_cdsa_beast_tls_workaround"

#import <Security/Security.h>
#import <unistd.h>
#import <CoreFoundation/CFStream.h>

typedef struct
{
	CFReadStreamRef	readStream;
	CFWriteStreamRef writeStream;
} PurpleSslCDSAData;

static GList *connections = NULL;

#define PURPLE_SSL_CDSA_DATA(gsc) ((PurpleSslCDSAData *)gsc->private_data)
#define PURPLE_SSL_CONNECTION_IS_VALID(gsc) (g_list_find(connections, (gsc)) != NULL)

/*
 * query_cert_chain - callback for letting the user review the certificate before accepting it
 *
 * gsc: The secure connection used
 * err: one of the following:
 *  errSSLUnknownRootCert—The peer has a valid certificate chain, but the root of the chain is not a known anchor certificate.
 *  errSSLNoRootCert—The peer's certificate chain was not verifiable to a root certificate.
 *  errSSLCertExpired—The peer's certificate chain has one or more expired certificates.
 *  errSSLXCertChainInvalid—The peer has an invalid certificate chain; for example, signature verification within the chain failed, or no certificates were found.
 * hostname: The name of the host to be verified (for display purposes)
 * certs: an array of values of type SecCertificateRef representing the peer certificate and the certificate chain used to validate it. The certificate at index 0 of the returned array is the peer certificate; the root certificate (or the closest certificate to it) is at the end of the returned array.
 * accept_cert: the callback to be called when the user chooses to trust this certificate chain
 * reject_cert: the callback to be called when the user does not trust this certificate chain
 * userdata: opaque pointer which has to be passed to the callbacks
 */
typedef
void (*query_cert_chain)(PurpleSslConnection *gsc, const char *hostname, CFArrayRef certs, void (*query_cert_cb)(gboolean trusted, void *userdata), void *userdata);

static query_cert_chain certificate_ui_cb = NULL;
static void ssl_cdsa_create_context(gpointer data);

/*
 * ssl_cdsa_init
 */
static gboolean
ssl_cdsa_init(void)
{
	return (TRUE);
}

/*
 * ssl_cdsa_uninit
 */
static void
ssl_cdsa_uninit(void)
{
}

struct query_cert_userdata {
	CFArrayRef certs;
	char *hostname;
	PurpleSslConnection *gsc;
	PurpleInputCondition cond;
};

static void ssl_cdsa_close(PurpleSslConnection *gsc);

static void query_cert_result(gboolean trusted, void *userdata) {
	struct query_cert_userdata *ud = (struct query_cert_userdata*)userdata;
	PurpleSslConnection *gsc = (PurpleSslConnection *)ud->gsc;

	CFRelease(ud->certs);
	free(ud->hostname);

	if (PURPLE_SSL_CONNECTION_IS_VALID(gsc)) {
		if (!trusted) {
			if (gsc->error_cb != NULL)
				gsc->error_cb(gsc, PURPLE_SSL_CERTIFICATE_INVALID,
							  gsc->connect_cb_data);

			purple_ssl_close(ud->gsc);
		} else {
			purple_debug_info("cdsa", "SSL_connect complete\n");

			/* SSL connected now */
			ud->gsc->connect_cb(ud->gsc->connect_cb_data, ud->gsc, ud->cond);
		}
	}

	free(ud);
}

/*
 * ssl_cdsa_handshake_cb
 *
 * Called when the stream reports that the TLS handshake is complete.
 * Checks certificate trust and invokes the callback.
 */
static void
ssl_cdsa_handshake_cb(gpointer data, gint source, PurpleInputCondition cond)
{
	PurpleSslConnection *gsc = (PurpleSslConnection *)data;
	PurpleSslCDSAData *cdsa_data = PURPLE_SSL_CDSA_DATA(gsc);

	purple_debug_info("cdsa", "Connecting (handshake complete)\n");

	purple_debug_info("cdsa", "SSL_connect: verifying certificate\n");

	if(certificate_ui_cb) {
		/* Get the trust result from the stream */
		SecTrustRef trust = (SecTrustRef)CFReadStreamCopyProperty(cdsa_data->readStream, kCFStreamPropertySSLPeerTrust);
		CFArrayRef certs = NULL;

		if (trust) {
			certs = SecTrustCopyCertificateChain(trust);
			CFRelease(trust);
		}

		if (!certs) {
			purple_debug_error("cdsa", "No certificate trust info available — refusing connection\n");
			if (gsc->error_cb != NULL)
				gsc->error_cb(gsc, PURPLE_SSL_CERTIFICATE_INVALID, gsc->connect_cb_data);
			purple_ssl_close(gsc);
			return;
		}

		struct query_cert_userdata *userdata = (struct query_cert_userdata*)malloc(sizeof(struct query_cert_userdata));
		size_t hostnamelen = gsc->host ? strlen(gsc->host) : 0;

		userdata->hostname = (char*)malloc(hostnamelen + 1);
		if (gsc->host) {
			memcpy(userdata->hostname, gsc->host, hostnamelen);
		}
		userdata->hostname[hostnamelen] = '\0';
		userdata->cond = cond;
		userdata->gsc = gsc;
		userdata->certs = certs;

		certificate_ui_cb(gsc, userdata->hostname, userdata->certs, query_cert_result, userdata);
	} else {
		purple_debug_info("cdsa", "SSL_connect complete (did not verify certificate)\n");

		/* SSL connected now */
		gsc->connect_cb(gsc->connect_cb_data, gsc, cond);
	}
}

/*
 * Stream event callback — called from the runloop when the stream opens
 * (handshake complete) or errors.
 */
static void
ssl_cdsa_stream_event(CFReadStreamRef stream, CFStreamEventType event, void *info)
{
	PurpleSslConnection *gsc = (PurpleSslConnection *)info;
	PurpleSslCDSAData *cdsa_data = PURPLE_SSL_CDSA_DATA(gsc);

	if (!PURPLE_SSL_CONNECTION_IS_VALID(gsc)) {
		return;
	}

	switch (event) {
		case kCFStreamEventOpenCompleted:
			purple_debug_info("cdsa", "Stream opened (TLS handshake complete)\n");
			/* Handshake is done — trigger the handshake callback */
			ssl_cdsa_handshake_cb(gsc, gsc->fd, PURPLE_INPUT_READ);
			break;

		case kCFStreamEventErrorOccurred:
		{
			CFErrorRef error = CFReadStreamCopyError(stream);
			if (error) {
				CFStringRef desc = CFErrorCopyDescription(error);
				if (desc) {
					char descBuf[256];
					if (CFStringGetCString(desc, descBuf, sizeof(descBuf), kCFStringEncodingUTF8)) {
						purple_debug_error("cdsa", "Stream error: %s\n", descBuf);
					}
						CFRelease(desc);
				}
				CFRelease(error);
			} else {
				purple_debug_error("cdsa", "Stream error (unknown)\n");
			}

			if (gsc->error_cb != NULL)
				gsc->error_cb(gsc, PURPLE_SSL_HANDSHAKE_FAILED,
							  gsc->connect_cb_data);

			purple_ssl_close(gsc);
			break;
		}

		case kCFStreamEventEndEncountered:
			purple_debug_info("cdsa", "Stream ended\n");
			if (gsc->error_cb != NULL)
				gsc->error_cb(gsc, PURPLE_SSL_HANDSHAKE_FAILED,
							  gsc->connect_cb_data);
			purple_ssl_close(gsc);
			break;

		default:
			break;
	}
}

static void
ssl_cdsa_create_context(gpointer data) {
	PurpleSslConnection *gsc = (PurpleSslConnection *)data;
	PurpleSslCDSAData *cdsa_data;
	CFReadStreamRef readStream = NULL;
	CFWriteStreamRef writeStream = NULL;
	CFStreamClientContext streamContext = {0, gsc, NULL, NULL, NULL};

	/*
	 * Allocate some memory to store variables for the connection.
	 */
	cdsa_data = g_new0(PurpleSslCDSAData, 1);
	gsc->private_data = cdsa_data;
	connections = g_list_append(connections, gsc);

	/*
	 * Create paired read/write streams from the existing socket fd.
	 */
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, gsc->fd, &readStream, &writeStream);
	cdsa_data->readStream = readStream;
	cdsa_data->writeStream = writeStream;
	if (!readStream || !writeStream) {
		purple_debug_error("cdsa", "CFStreamCreatePairWithSocket failed\n");
		if (gsc->error_cb != NULL)
			gsc->error_cb(gsc, PURPLE_SSL_HANDSHAKE_FAILED,
						  gsc->connect_cb_data);
		purple_ssl_close(gsc);
		return;
	}

	/*
	 * Set TLS settings.
	 * We set the peer name for SNI and certificate CN verification,
	 * and disable automatic validation so we can present the trust
	 * dialog to the user if needed.
	 */
	CFStringRef peerName = gsc->host ? CFStringCreateWithCString(kCFAllocatorDefault, gsc->host, kCFStringEncodingUTF8) : CFSTR("");
	const void *keys[] = {
		kCFStreamSSLLevel,
		kCFStreamSSLPeerName,
		kCFStreamSSLIsServer,
		kCFStreamSSLValidatesCertificateChain
	};
	const void *values[] = {
		kCFStreamSocketSecurityLevelNegotiatedSSL,
		peerName,
		kCFBooleanFalse,
		kCFBooleanFalse
	};
	CFDictionaryRef tlsSettings = CFDictionaryCreate(kCFAllocatorDefault,
		keys, values, 4,
		&kCFTypeDictionaryKeyCallBacks,
		&kCFTypeDictionaryValueCallBacks);

	Boolean setRead = CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, tlsSettings);
	Boolean setWrite = CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, tlsSettings);

	CFRelease(tlsSettings);
	if (gsc->host) CFRelease(peerName);

	if (!setRead || !setWrite) {
		purple_debug_error("cdsa", "Failed to set TLS properties on stream\n");
		if (gsc->error_cb != NULL)
			gsc->error_cb(gsc, PURPLE_SSL_HANDSHAKE_FAILED,
						  gsc->connect_cb_data);
		purple_ssl_close(gsc);
		return;
	}

	/*
	 * Set up the stream event callback for open completion / errors.
	 */
	CFOptionFlags events = kCFStreamEventOpenCompleted | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
	if (!CFReadStreamSetClient(readStream, events, ssl_cdsa_stream_event, &streamContext)) {
		purple_debug_error("cdsa", "CFReadStreamSetClient failed\n");
		if (gsc->error_cb != NULL)
			gsc->error_cb(gsc, PURPLE_SSL_HANDSHAKE_FAILED,
						  gsc->connect_cb_data);
		purple_ssl_close(gsc);
		return;
	}

	/*
	 * Schedule the stream on the current runloop.
	 */
	CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

	/*
	 * Open the streams — this triggers the TLS handshake.
	 */
	if (!CFReadStreamOpen(readStream)) {
		purple_debug_error("cdsa", "CFReadStreamOpen failed\n");
		if (gsc->error_cb != NULL)
			gsc->error_cb(gsc, PURPLE_SSL_HANDSHAKE_FAILED,
						  gsc->connect_cb_data);
		purple_ssl_close(gsc);
		return;
	}

	if (!CFWriteStreamOpen(writeStream)) {
		purple_debug_error("cdsa", "CFWriteStreamOpen failed\n");
		if (gsc->error_cb != NULL)
			gsc->error_cb(gsc, PURPLE_SSL_HANDSHAKE_FAILED,
						  gsc->connect_cb_data);
		purple_ssl_close(gsc);
		return;
	}

	/*
	 * The CFStream event callback (kCFStreamEventOpenCompleted) handles
	 * handshake completion. No fallback handler needed — CFStream is
	 * reliable on all supported macOS versions (10.11+).
	 */
}


/*
 * ssl_cdsa_connect
 *
 * given a socket, put an SSL connection around it.
 */
static void
ssl_cdsa_connect(PurpleSslConnection *gsc) {

	ssl_cdsa_create_context(gsc);
}

static void
ssl_cdsa_close(PurpleSslConnection *gsc)
{
	PurpleSslCDSAData *cdsa_data = PURPLE_SSL_CDSA_DATA(gsc);

	if (cdsa_data == NULL)
		return;

	if (cdsa_data->readStream) {
		CFReadStreamSetClient(cdsa_data->readStream, 0, NULL, NULL);
		CFReadStreamUnscheduleFromRunLoop(cdsa_data->readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		CFReadStreamClose(cdsa_data->readStream);
		CFRelease(cdsa_data->readStream);
		cdsa_data->readStream = NULL;
	}

	if (cdsa_data->writeStream) {
		CFWriteStreamUnscheduleFromRunLoop(cdsa_data->writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		CFWriteStreamClose(cdsa_data->writeStream);
		CFRelease(cdsa_data->writeStream);
		cdsa_data->writeStream = NULL;
	}

	connections = g_list_remove(connections, gsc);

	g_free(cdsa_data);
	gsc->private_data = NULL;
}

static size_t
ssl_cdsa_read(PurpleSslConnection *gsc, void *data, size_t len)
{
	PurpleSslCDSAData *cdsa_data = PURPLE_SSL_CDSA_DATA(gsc);

	if (!cdsa_data || !cdsa_data->readStream) {
		errno = EIO;
		return -1;
	}

	CFIndex bytesRead = CFReadStreamRead(cdsa_data->readStream, data, len);
	if (bytesRead > 0) {
		return (size_t)bytesRead;
	} else if (bytesRead == 0) {
		/* End of stream */
		return 0;
	} else {
		/* Error */
		CFStreamError error = CFReadStreamGetError(cdsa_data->readStream);
		if (error.error == noErr && error.domain == kCFStreamErrorDomainCustom) {
			/* Stream not ready */
			errno = EAGAIN;
			return -1;
		}
		if (error.domain == kCFStreamErrorDomainPOSIX && error.error == EAGAIN) {
			errno = EAGAIN;
			return -1;
		}
		purple_debug_error("cdsa", "read failed (domain=%ld, error=%d)\n",
			(long)error.domain, (int)error.error);
		errno = EIO;
		return -1;
	}
}

static size_t
ssl_cdsa_write(PurpleSslConnection *gsc, const void *data, size_t len)
{
	PurpleSslCDSAData *cdsa_data = PURPLE_SSL_CDSA_DATA(gsc);

	if (!cdsa_data || !cdsa_data->writeStream) {
		errno = EIO;
		return -1;
	}

	CFIndex bytesWritten = CFWriteStreamWrite(cdsa_data->writeStream, data, len);
	if (bytesWritten >= 0) {
		return (size_t)bytesWritten;
	} else {
		CFStreamError error = CFWriteStreamGetError(cdsa_data->writeStream);
		if (error.domain == kCFStreamErrorDomainPOSIX && error.error == EAGAIN) {
			errno = EAGAIN;
			return -1;
		}
		purple_debug_error("cdsa", "write failed (domain=%ld, error=%d)\n",
			(long)error.domain, (int)error.error);
		errno = EIO;
		return -1;
	}
}

static gboolean register_certificate_ui_cb(query_cert_chain cb) {
	certificate_ui_cb = cb;

	return true;
}

static gboolean copy_certificate_chain(PurpleSslConnection *gsc /* IN */, CFArrayRef *result /* OUT */) {
	PurpleSslCDSAData *cdsa_data = PURPLE_SSL_CDSA_DATA(gsc);

	if (!cdsa_data || !cdsa_data->readStream) {
		return FALSE;
	}

	SecTrustRef trust = (SecTrustRef)CFReadStreamCopyProperty(cdsa_data->readStream, kCFStreamPropertySSLPeerTrust);
	if (!trust) {
		return FALSE;
	}

	*result = SecTrustCopyCertificateChain(trust);
	CFRelease(trust);

	return (*result != NULL);
}

static PurpleSslOps ssl_ops = {
	ssl_cdsa_init,
	ssl_cdsa_uninit,
	ssl_cdsa_connect,
	ssl_cdsa_close,
	ssl_cdsa_read,
	ssl_cdsa_write,
	NULL, /* get_peer_certificates */
	NULL, /* reserved2 */
	NULL, /* reserved3 */
	NULL  /* reserved4 */
};

static gboolean
plugin_load(PurplePlugin *plugin)
{
	if (!purple_ssl_get_ops())
		purple_ssl_set_ops(&ssl_ops);

	purple_plugin_ipc_register(plugin,
							   "register_certificate_ui_cb",
							   PURPLE_CALLBACK(register_certificate_ui_cb),
							   purple_marshal_BOOLEAN__POINTER,
							   purple_value_new(PURPLE_TYPE_BOOLEAN),
							   1, purple_value_new(PURPLE_TYPE_POINTER));

	purple_plugin_ipc_register(plugin,
							   "copy_certificate_chain",
							   PURPLE_CALLBACK(copy_certificate_chain),
							   purple_marshal_BOOLEAN__POINTER_POINTER,
							   purple_value_new(PURPLE_TYPE_BOOLEAN),
							   2, purple_value_new(PURPLE_TYPE_POINTER), purple_value_new(PURPLE_TYPE_POINTER));

	return (TRUE);
}

static gboolean
plugin_unload(PurplePlugin *plugin)
{
	if (purple_ssl_get_ops() == &ssl_ops)
		purple_ssl_set_ops(NULL);

	purple_plugin_ipc_unregister_all(plugin);

	return (TRUE);
}

static PurplePluginInfo info = {
	PURPLE_PLUGIN_MAGIC,
	PURPLE_MAJOR_VERSION,
	PURPLE_MINOR_VERSION,
	PURPLE_PLUGIN_STANDARD,				/* type */
	NULL,						/* ui_requirement */
	PURPLE_PLUGIN_FLAG_INVISIBLE,			/* flags */
	NULL,						/* dependencies */
	PURPLE_PRIORITY_DEFAULT,				/* priority */

	SSL_CDSA_PLUGIN_ID,				/* id */
	N_("CDSA"),					/* name */
	"0.2",					/* version */

	N_("Provides SSL support through NSStream (TLS)."),	/* summary */
	N_("Provides SSL support through NSStream (TLS)."),	/* description */
	"Adium contributors",										/* author */
	"https://adium.im",						/* homepage */

	plugin_load,					/* load */
	plugin_unload,					/* unload */
	NULL,						/* destroy */

	NULL,						/* ui_info */
	NULL,						/* extra_info */
	NULL,						/* prefs_info */
	NULL,						/* actions */
	/* _purple_reserved 1-4 */
	NULL, NULL, NULL, NULL
};

static void
init_plugin(PurplePlugin *plugin)
{
}

PURPLE_INIT_PLUGIN(ssl_cdsa, init_plugin, info)