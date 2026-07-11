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
#include <libpurple/eventloop.h>
#include <libpurple/jabber.h>
#include <libpurple/plugin.h>
#include <libpurple/prpl.h>
#include <libpurple/signals.h>
#include <libpurple/xmlnode.h>

#define NS_CARBONS "urn:xmpp:carbons:2"
#define NS_FORWARD "urn:xmpp:forward:0"

/* Deferred callback to send carbons enable IQ */
static gboolean enable_carbons_cb(gpointer data)
{
	PurpleConnection *gc = (PurpleConnection *)data;
	/* ponytail: skip server disco — send enable IQ directly. Server returns
	 * harmless error if unsupported. Full disco would check capabilities
	 * first; add if any server proves to misbehave on unknown features. */
	const char *iq = "<iq type='set' id='carbons-enable-1'>"
					 "<enable xmlns='" NS_CARBONS "'/></iq>";

	jabber_prpl_send_raw(gc, iq, -1);
	purple_debug_info("carbons", "Sent carbons enable IQ\n");

	return FALSE;
}

/* account-signed-on: enable carbons for Jabber accounts */
static void account_signed_on_cb(PurpleConnection *gc, gpointer data)
{
	PurpleAccount *account = purple_connection_get_account(gc);
	const char *proto = purple_account_get_protocol_id(account);

	if (strcmp(proto, "prpl-jabber") != 0)
		return;

	const char *pref = purple_account_get_string(account, "Jabber:Enable Carbons", "yes");
	if (strcmp(pref, "yes") != 0) {
		purple_debug_info("carbons", "Carbons disabled by account preference\n");
		return;
	}

	purple_timeout_add(0, enable_carbons_cb, gc);
}

/* jabber-receiving-xmlnode: unwrap carbon wrappers */
static void xmlnode_received_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	if (!packet || !*packet)
		return;

	PurpleAccount *account = purple_connection_get_account(gc);
	const char *pref = purple_account_get_string(account, "Jabber:Enable Carbons", "yes");
	if (strcmp(pref, "yes") != 0)
		return;

	const char *own_jid = purple_account_get_username(account);
	const char *outer_from = xmlnode_get_attrib(*packet, "from");

	/* Spoofing guard: only accept carbons from our own bare JID */
	if (!outer_from || strcmp(outer_from, own_jid) != 0) {
		purple_debug_warning("carbons", "Dropped carbon: from '%s' != own JID '%s'\n",
							 outer_from ? outer_from : "(null)", own_jid);
		xmlnode_free(*packet);
		*packet = NULL;
		return;
	}

	xmlnode *received = xmlnode_get_child_with_namespace(*packet, "received", NS_CARBONS);
	xmlnode *sent = received ? NULL : xmlnode_get_child_with_namespace(*packet, "sent", NS_CARBONS);

	if (!received && !sent)
		return;

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
		/* Replace packet with inner message for normal processing */
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
						purple_conversation_write(conv, to, body, PURPLE_MESSAGE_SEND | PURPLE_MESSAGE_RECV, 0);
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

static gboolean plugin_load(PurplePlugin *plugin)
{
	purple_signal_connect(purple_connections_get_handle(), "account-signed-on", plugin,
						  PURPLE_CALLBACK(account_signed_on_cb), NULL);

	PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
	if (jabber) {
		purple_signal_connect(jabber, "jabber-receiving-xmlnode", plugin, PURPLE_CALLBACK(xmlnode_received_cb), NULL);
	} else {
		purple_debug_warning("carbons", "prpl-jabber not found\n");
	}

	return TRUE;
}

static gboolean plugin_unload(PurplePlugin *plugin)
{
	purple_signals_disconnect_by_handle(plugin);
	return TRUE;
}

static PurplePluginInfo info = {PURPLE_PLUGIN_MAGIC, PURPLE_MAJOR_VERSION, PURPLE_MINOR_VERSION,
								PURPLE_PLUGIN_STANDARD,       /* type */
								NULL,                         /* ui_requirement */
								PURPLE_PLUGIN_FLAG_INVISIBLE, /* flags */
								NULL,                         /* dependencies */
								PURPLE_PRIORITY_DEFAULT,      /* priority */
								"carbons",                    /* id */
								"Carbons",                    /* name */
								"0.1",                        /* version */
								"XEP-0280 Message Carbons",   /* summary */
								"Implements XEP-0280 message carbons for "
								"multi-device message synchronization", /* description */
								"AdiumY Contributors",                  /* author */
								"https://adium.im",                     /* homepage */
								plugin_load,                            /* load */
								plugin_unload,                          /* unload */
								NULL,                                   /* destroy */
								NULL,                                   /* ui_info */
								NULL,                                   /* extra_info */
								NULL,                                   /* prefs_info */
								NULL,                                   /* actions */
								/* _purple_reserved 1-4 */
								NULL, NULL, NULL, NULL};

static void init_plugin(PurplePlugin *plugin) {}

PURPLE_INIT_PLUGIN(carbons, init_plugin, info)
