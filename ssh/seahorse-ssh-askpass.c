/*
 * Seahorse
 *
 * Copyright (C) 2005 Stefan Walter
 * Copyright (C) 2011 Collabora Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Author: Stef Walter <stefw@collabora.co.uk>
 */

#include "config.h"

#include "seahorse-common.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <glib.h>
#include <glib/gi18n.h>
#include <gtk/gtk.h>

static SeahorsePassphrasePrompt *dialog = NULL;
static int response = GTK_RESPONSE_CANCEL;

static void
on_response (GtkDialog *dialog,
             int resp,
             void *user_data)
{
    GApplication *app = G_APPLICATION (user_data);

    response = resp;

    gtk_window_destroy (GTK_WINDOW (dialog));
    g_application_quit (app);
}

static int
on_app_command_line (GApplication *app,
                     GApplicationCommandLine *cmd_line,
                     void *user_data)
{
    g_auto(GStrv) argv = NULL;
    int argc;
    const char *title;
    const char *argument;
    g_autofree char *message = NULL;
    const char *flags;

    title = g_getenv ("SEAHORSE_SSH_ASKPASS_TITLE");
    if (!title || !title[0])
        title = _("Enter your Secure Shell passphrase:");

    message = (char *) g_getenv ("SEAHORSE_SSH_ASKPASS_MESSAGE");
    argv = g_application_command_line_get_arguments (cmd_line, &argc);
    if (message && message[0])
        message = g_strdup (message);
    else if (argc > 1)
        message = g_strjoinv (" ", argv + 1);
    else
        message = g_strdup (_("Enter your Secure Shell passphrase:"));

    argument = g_getenv ("SEAHORSE_SSH_ASKPASS_ARGUMENT");
    if (!argument)
        argument = "";

    flags = g_getenv ("SEAHORSE_SSH_ASKPASS_FLAGS");
    if (!flags)
        flags = "";
    if (strstr (flags, "multiple")) {
        g_autofree char *lower = g_ascii_strdown (message, -1);

        /* Need the old passphrase */
        if (strstr (lower, "old pass")) {
            title = _("Old Key Passphrase");
            message = g_strdup_printf (_("Enter the old passphrase for: %s"), argument);

        /* Look for the new passphrase thingy */
        } else if (strstr (lower, "new pass")) {
            title = _("New Key Passphrase");
            message = g_strdup_printf (_("Enter the new passphrase for: %s"), argument);

        /* Confirm the new passphrase, just send it again */
        } else if (strstr (lower, "again")) {
            title = _("New Key Passphrase");
            message = g_strdup_printf (_("Enter the new passphrase again: %s"), argument);
        }
    }

    dialog = seahorse_passphrase_prompt_show_dialog (title, message, _("Password:"),
                                                     NULL, FALSE);
    g_signal_connect (dialog, "response", G_CALLBACK (on_response), app);
    gtk_window_present (GTK_WINDOW (dialog));

    return 0;
}

int
main (int argc, char* argv[])
{
    g_autoptr(GtkApplication) app = NULL;
    int result;
    const char *pass;
    gssize len;

    bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    textdomain (GETTEXT_PACKAGE);

    /* Non buffered stdout */
    setvbuf (stdout, 0, _IONBF, 0);

    app = gtk_application_new (NULL, G_APPLICATION_HANDLES_COMMAND_LINE);
    g_signal_connect (app, "command-line", G_CALLBACK (on_app_command_line), NULL);

    result = g_application_run (G_APPLICATION (app), argc, argv);
    if (result != 0)
        return result;

    if (response != GTK_RESPONSE_ACCEPT)
        return 2;

    pass = seahorse_passphrase_prompt_get_text (dialog);
    len = strlen (pass ? pass : "");
    if (write (1, pass, len) != len) {
        g_warning ("couldn't write out password properly");
        return 1;
    }

    return 0;
}
