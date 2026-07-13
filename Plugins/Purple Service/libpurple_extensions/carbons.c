/*
 * XEP-0280 Message Carbons for libpurple
 *
 * Implements message carbons to synchronize messages across
 * multiple devices for the same account.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 */

#include <string.h>

#include <libpurple/account.h>
#include <libpurple/connection.h>
#include <libpurple/conversation.h>
#include <libpurple/debug.h>
#include <libpurple/jabber.h>
#include <libpurple/plugin.h>
#include <libpurple/prpl.h>
#include <libpurple/signals.h>
#include <libpurple/xmlnode.h>

#define NS_CARBONS "urn:xmpp:carbons:2"
#define NS_FORWARD "urn:xmpp:forward:0"

static gboolean carbons_connected = FALSE;

/* jabber-receiving-xmlnode: unwrap carbon wrappers */
static void xmlnode_received_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	if (!packet || !*packet)
		return;

	PurpleAccount *account = purple_connection_get_account(gc);
	const char *pref = purple_account_get_string(account, "Jabber:Enable Carbons", "yes");
	if (strcmp(pref, "yes") != 0)
		return;

	/* Step 1: Check if this is a carbon-wrapped message */
	xmlnode *received = xmlnode_get_child_with_namespace(*packet, "received", NS_CARBONS);
	xmlnode *sent = received ? NULL : xmlnode_get_child_with_namespace(*packet, "sent", NS_CARBONS);

	if (!received && !sent)
		return; /* Not a carbon — let normal processing handle it */

	/* Step 2: Spoofing guard — only accept carbons from our own bare JID */
	const char *own_jid = purple_account_get_username(account);
	const char *outer_from = xmlnode_get_attrib(*packet, "from");

	if (!outer_from || g_ascii_strcasecmp(outer_from, own_jid) != 0) {
		purple_debug_warning("carbons",
							 "Dropped spoofed carbon: from '%s' != own JID "
							 "'%s'\n",
							 outer_from, own_jid);
		xmlnode_free(*packet);
		*packet = NULL;
		return;
	}

	/* Step 3: Unwrap forwarded message */
	xmlnode *forwarded = xmlnode_get_child_with_namespace(received ? received : sent, "forwarded", NS_FORWARD);
	if (!forwarded) {
		purple_debug_warning("carbons", "Carbon without forwarded element\n");
		return;
	}

	xmlnode *inner = xmlnode_get_child(forwarded, "message");
	if (!inner) {
		purple_debug_warning("carbons", "Forwarded element without message\n");
		return;
	}

	if (received) {
		/* Replace packet with inner message for normal prpl processing */
		xmlnode *copy = xmlnode_copy(inner);
		xmlnode_free(*packet);
		*packet = copy;
		purple_debug_info("carbons", "Unwrapped received carbon\n");
	} else {
		/* sent carbon: display as outgoing message in conversation */
		xmlnode *body_node = xmlnode_get_child(inner, "body");
		if (body_node) {
			char *body = xmlnode_get_data_unescaped(body_node);
			if (body) {
				const char *to = xmlnode_get_attrib(inner, "to");
				if (to) {
					PurpleConversation *conv = purple_find_conversation_with_account(PURPLE_CONV_TYPE_IM, to, account);
					if (conv) {
						purple_conversation_write(conv, purple_account_get_username(account), body, PURPLE_MESSAGE_SEND,
												  0);
					}
				}
				g_free(body);
			}
		}
		xmlnode_free(*packet);
		*packet = NULL;
		purple_debug_info("carbons", "Unwrapped sent carbon\n");
	}
}

/* signed-on: enable carbons for Jabber accounts */
static void signed_on_cb(PurpleConnection *gc, gpointer data)
{
	PurpleAccount *account = purple_connection_get_account(gc);
	const char *proto = purple_account_get_protocol_id(account);

	if (strcmp(proto, "prpl-jabber") != 0)
		return;

	/* Connect jabber-receiving-xmlnode handler now that the Jabber PRPL is
	 * guaranteed loaded (loaded on first account sign-on). */
	if (!carbons_connected) {
		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber) {
			/* The 'data' parameter is the plugin handle from plugin_load
			 * — ensures all signals disconnect atomically on unload. */
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", data, PURPLE_CALLBACK(xmlnode_received_cb), NULL);
			carbons_connected = TRUE;
		} else {
			purple_debug_warning("carbons", "prpl-jabber not found at sign-on\n");
		}
	}

	const char *pref = purple_account_get_string(account, "Jabber:Enable Carbons", "yes");
	if (strcmp(pref, "yes") != 0) {
		purple_debug_info("carbons", "Carbons disabled by account preference\n");
		return;
	}

	/* Send enable IQ directly - skip disco; server returns harmless error
	 * if unsupported. Add capability check only if any server proves to
	 * misbehave on unknown features. */
	const char *iq = "<iq type='set' id='carbons-enable-1'>"
					 "<enable xmlns='" NS_CARBONS "'/></iq>";
	purple_debug_info("carbons", "Sending carbons enable IQ\n");
	jabber_prpl_send_raw(gc, iq, -1);
}

static gboolean plugin_load(PurplePlugin *plugin)
{
	/* Connect to the signed-on signal. The 'plugin' handle is passed as
	 * user_data so the jabber-receiving-xmlnode connection made inside
	 * signed_on_cb shares the same handle — this guarantees all signals
	 * disconnect on unload. */
	purple_signal_connect(purple_connections_get_handle(), "signed-on", plugin, PURPLE_CALLBACK(signed_on_cb), plugin);

	return TRUE;
}

static gboolean plugin_unload(PurplePlugin *plugin)
{
	purple_signals_disconnect_by_handle(plugin);
	carbons_connected = FALSE;

	return TRUE;
}

static PurplePluginInfo info = {PURPLE_PLUGIN_MAGIC, PURPLE_MAJOR_VERSION, PURPLE_MINOR_VERSION,
								PURPLE_PLUGIN_STANDARD,       /* type */
								NULL,                         /* ui_req */
								PURPLE_PLUGIN_FLAG_INVISIBLE, /* flags */
								NULL,                         /* deps */
								PURPLE_PRIORITY_DEFAULT,      /* priority */
								"carbons",                    /* id */
								"Carbons",                    /* name */
								"0.1",                        /* version */
								"XEP-0280 Message Carbons",   /* summary */
								"Implements XEP-0280 message carbons for "
								"multi-device message sync",
								"AdiumY Contributors",                    /* author */
								"https://github.com/phaedrus1992/adiumy", /* homepage */
								plugin_load,                              /* load */
								plugin_unload,                            /* unload */
								NULL,                                     /* destroy */
								NULL,                                     /* ui_info */
								NULL,                                     /* extra_info */
								NULL,                                     /* prefs_info */
								NULL,                                     /* actions */
								/* _purple_reserved 1-4 */
								NULL, NULL, NULL, NULL};

static void init_plugin(PurplePlugin *plugin) {}

PURPLE_INIT_PLUGIN(carbons, init_plugin, info)
