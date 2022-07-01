/*
 * Seahorse
 *
 * Copyright (C) 2003 Jacob Perkins
 * Copyright (C) 2005 Jim Pharis
 * Copyright (C) 2005-2006 Stefan Walter
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2019 Niels De Graef
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
 */

#include "config.h"

#include "seahorse-pgp-key-properties.h"
#include "seahorse-gpgme-add-uid.h"
#include "seahorse-gpgme-dialogs.h"
#include "seahorse-gpgme-expires-dialog.h"
#include "seahorse-gpgme-key.h"
#include "seahorse-gpgme-key-export-operation.h"
#include "seahorse-gpgme-key-op.h"
#include "seahorse-gpgme-revoke-dialog.h"
#include "seahorse-gpgme-sign-dialog.h"
#include "seahorse-pgp-backend.h"
#include "seahorse-gpg-op.h"
#include "seahorse-pgp-dialogs.h"
#include "seahorse-pgp-key.h"
#include "seahorse-pgp-uid.h"
#include "seahorse-pgp-uid-list-box.h"
#include "seahorse-pgp-signature.h"
#include "seahorse-pgp-subkey.h"
#include "seahorse-pgp-subkey-list-box.h"

#include "seahorse-common.h"

#include "libseahorse/seahorse-util.h"

#include <glib.h>
#include <glib/gi18n.h>

#include <string.h>

enum {
    PROP_0,
    PROP_KEY,
    N_PROPS
};
static GParamSpec *properties[N_PROPS] = { NULL, };

struct _SeahorsePgpKeyProperties {
    GtkWindow parent_instance;

    SeahorsePgpKey *key;

    /* Common widgets */
    GtkWidget *window_title;

    GtkWidget *revoked_banner;
    GtkWidget *expired_banner;

    GtkWidget *name_label;
    GtkWidget *email_label;
    GtkWidget *comment_label;
    GtkWidget *keyid_label;
    GtkWidget *fingerprint_label;
    GtkWidget *expires_label;
    GtkWidget *owner_trust_row;
    GtkCustomFilter *owner_trust_filter;
    GtkWidget *uids_container;
    GtkWidget *subkeys_container;

    /* Private key widgets */
    GtkWidget *menu_button;

    /* Public key widgets */
    GtkWidget *trust_page;
    GtkWidget *trust_sign_row;
    GtkWidget *trust_marginal_switch;
};

G_DEFINE_TYPE (SeahorsePgpKeyProperties, seahorse_pgp_key_properties, GTK_TYPE_WINDOW)

static void
on_gpgme_key_change_pass_done (GObject      *source,
                               GAsyncResult *res,
                               void         *user_data)
{
    g_autoptr(SeahorsePgpKeyProperties) self = SEAHORSE_PGP_KEY_PROPERTIES (user_data);
    SeahorseGpgmeKey *pkey = SEAHORSE_GPGME_KEY (source);
    g_autoptr(GError) error = NULL;

    if (!seahorse_gpgme_key_op_change_pass_finish (pkey, res, &error)) {
        GtkWindow *window;
        window = gtk_window_get_transient_for (GTK_WINDOW (self));
        seahorse_util_show_error (GTK_WIDGET (window),
                                  _("Error changing password"),
                                  error->message);
    }
}

static void
on_change_password (GtkWidget* widget, const char *action_name, GVariant *param)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (widget);
    SeahorseUsage usage;

    usage = seahorse_object_get_usage (SEAHORSE_OBJECT (self->key));
    g_return_if_fail (usage == SEAHORSE_USAGE_PRIVATE_KEY);
    g_return_if_fail (SEAHORSE_GPGME_IS_KEY (self->key));

    seahorse_gpgme_key_op_change_pass_async (SEAHORSE_GPGME_KEY (self->key),
                                             NULL,
                                             on_gpgme_key_change_pass_done,
                                             g_object_ref (self));
}

static void
do_owner (SeahorsePgpKeyProperties *self)
{
    unsigned int flags;
    const char *label;
    GListModel *uids;
    g_autoptr(SeahorsePgpUid) primary_uid = NULL;
    GDateTime *expires;
    g_autofree char *expires_str = NULL;

    flags = seahorse_object_get_flags (SEAHORSE_OBJECT (self->key));

    /* Display appropriate warnings */
    adw_banner_set_revealed (ADW_BANNER (self->expired_banner),
                             flags & SEAHORSE_FLAG_EXPIRED);
    adw_banner_set_revealed (ADW_BANNER (self->revoked_banner),
                             flags & SEAHORSE_FLAG_REVOKED);

    /* Update the expired message */
    if (flags & SEAHORSE_FLAG_EXPIRED) {
        GDateTime *expires_date;
        g_autofree char *date_str = NULL;
        g_autofree char *message = NULL;

        expires_date = seahorse_pgp_key_get_expires (self->key);
        if (!expires_date) {
            /* TRANSLATORS: (unknown) expiry date */
            date_str = g_strdup (_("(unknown)"));
        } else {
            date_str = g_date_time_format (expires_date, "%x");
        }

        message = g_strdup_printf (_("This key expired on %s"), date_str);
        adw_banner_set_title (ADW_BANNER (self->expired_banner), message);
    }

    /* Hide trust page when above */
    if (self->trust_page != NULL) {
        gtk_widget_set_visible (self->trust_page, !((flags & SEAHORSE_FLAG_EXPIRED) ||
                                                    (flags & SEAHORSE_FLAG_REVOKED) ||
                                                    (flags & SEAHORSE_FLAG_DISABLED)));
    }

    uids = seahorse_pgp_key_get_uids (self->key);
    primary_uid = g_list_model_get_item (uids, 0);
    if (primary_uid != NULL) {
        g_autofree char *title = NULL;
        g_autofree char *email_escaped = NULL;
        g_autofree char *email_label = NULL;

        label = seahorse_pgp_uid_get_name (primary_uid);
        gtk_label_set_text (GTK_LABEL (self->name_label), label);

        label = seahorse_pgp_uid_get_email (primary_uid);
        if (label && *label) {
            email_escaped = g_markup_escape_text (label, -1);
            email_label = g_strdup_printf ("<a href=\"mailto:%s\">%s</a>", label, email_escaped);
            gtk_label_set_markup (GTK_LABEL (self->email_label), email_label);
            gtk_widget_set_visible (self->email_label, TRUE);
        } else {
            gtk_widget_set_visible (self->email_label, FALSE);
        }

        label = seahorse_pgp_uid_get_comment (primary_uid);
        if (label && *label) {
            gtk_label_set_markup (GTK_LABEL (self->comment_label), label);
            gtk_widget_set_visible (self->comment_label, TRUE);
        } else {
            gtk_widget_set_visible (self->comment_label, FALSE);
        }

        label = seahorse_object_get_identifier (SEAHORSE_OBJECT (self->key));
        gtk_label_set_text (GTK_LABEL (self->keyid_label), label);
    }

    gtk_label_set_text (GTK_LABEL (self->fingerprint_label),
                        seahorse_pgp_key_get_fingerprint (self->key));

    expires = seahorse_pgp_key_get_expires (self->key);
    if (expires)
        expires_str = g_date_time_format (expires, "%x");
    else
        expires_str = g_strdup (C_("Expires", "Never"));
    gtk_label_set_text (GTK_LABEL (self->expires_label), expires_str);
}

static void
on_owner_trust_selected_changed (GObject    *object,
                                 GParamSpec *pspec,
                                 void       *user_data)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (user_data);
    GObject *selected;
    int trust;

    g_return_if_fail (SEAHORSE_GPGME_IS_KEY (self->key));

    selected = adw_combo_row_get_selected_item (ADW_COMBO_ROW (self->owner_trust_row));
    if (selected == NULL)
        return;

    trust = adw_enum_list_item_get_value ((AdwEnumListItem *) selected);
    if (seahorse_pgp_key_get_trust (self->key) != trust) {
        gpgme_error_t err;

        err = seahorse_gpgme_key_op_set_trust (SEAHORSE_GPGME_KEY (self->key),
                                               trust);
        if (err)
            seahorse_gpgme_handle_error (err, _("Unable to change trust"));
    }
}

static void
on_export_op_execute_done (GObject *src_object,
                           GAsyncResult *result,
                           void *user_data)
{
    SeahorseExportOperation *export_op = SEAHORSE_EXPORT_OPERATION (src_object);
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (user_data);
    g_autoptr(GError) error = NULL;
    gboolean success;

    success = seahorse_export_operation_execute_finish (export_op, result, &error);
    if (!success) {
        if (g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
            g_debug ("User cancelled export of key");
            return;
        }

        seahorse_util_show_error (GTK_WIDGET (self), _("Couldn't export key"), error->message);
        return;
    }
}

static void
on_export_op_prompt_for_file_done (GObject *src_object,
                                   GAsyncResult *result,
                                   void *user_data)
{
    SeahorseExportOperation *export_op = SEAHORSE_EXPORT_OPERATION (src_object);
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (user_data);
    g_autoptr(GError) error = NULL;
    gboolean prompted;

    prompted = seahorse_export_operation_prompt_for_file_finish (export_op,
                                                                 result,
                                                                 &error);
    if (!prompted) {
        if (g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
            g_debug ("User cancelled export of key");
            return;
        }

        seahorse_util_show_error (GTK_WIDGET (self), _("Couldn't export key"), error->message);
        return;
    }

    seahorse_export_operation_execute (export_op, NULL, on_export_op_execute_done, self);
}

static void
export_key_to_file (SeahorsePgpKeyProperties *self, gboolean secret)
{
    g_autoptr(SeahorseExportOperation) export_op = NULL;

    g_return_if_fail (SEAHORSE_GPGME_IS_KEY (self->key));

    export_op = seahorse_gpgme_key_export_operation_new (SEAHORSE_GPGME_KEY (self->key), TRUE, secret);
    seahorse_export_operation_prompt_for_file (export_op,
                                               GTK_WINDOW (self),
                                               NULL,
                                               on_export_op_prompt_for_file_done,
                                               self);
}

static void
on_export_secret (GtkWidget* widget, const char *action_name, GVariant *param)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (widget);

    export_key_to_file (self, TRUE);
}

static void
on_export_public (GtkWidget* widget, const char *action_name, GVariant *param)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (widget);

    export_key_to_file (self, FALSE);
}

static void
on_change_expires (GtkWidget* widget, const char *action_name, GVariant *param)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (widget);
    GListModel *subkeys;
    g_autoptr(SeahorseGpgmeSubkey) subkey = NULL;
    GtkWindow *dialog;

    subkeys = seahorse_pgp_key_get_subkeys (self->key);
    g_return_if_fail (g_list_model_get_n_items (subkeys) > 0);

    subkey = SEAHORSE_GPGME_SUBKEY (g_list_model_get_item (subkeys, 0));
    g_return_if_fail (subkey);

    dialog = seahorse_gpgme_expires_dialog_new (subkey, GTK_WINDOW (self));
    gtk_window_present (dialog);
}

static gboolean
key_trust_filter_func (void *object, void *user_data)
{
    AdwEnumListItem *item = ADW_ENUM_LIST_ITEM (object);
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (user_data);
    int trust;
    SeahorseUsage usage;

    trust = adw_enum_list_item_get_value (item);
    usage = seahorse_object_get_usage (SEAHORSE_OBJECT (self->key));

    switch (trust) {
    /* Never shown as an option */
    case SEAHORSE_VALIDITY_REVOKED:
    case SEAHORSE_VALIDITY_DISABLED:
        return FALSE;
    /* Only for public keys */
    case SEAHORSE_VALIDITY_NEVER:
        return (usage != SEAHORSE_USAGE_PRIVATE_KEY);
    /* Shown for both public/private */
    case SEAHORSE_VALIDITY_UNKNOWN:
    case SEAHORSE_VALIDITY_MARGINAL:
    case SEAHORSE_VALIDITY_FULL:
        return TRUE;
    /* Only for private keys */
    case SEAHORSE_VALIDITY_ULTIMATE:
        return (usage == SEAHORSE_USAGE_PRIVATE_KEY);
    }

    g_return_val_if_reached (FALSE);
}

static char *
pgp_trust_to_string (void *user_data,
                     SeahorseValidity validity)
{
  return g_strdup (seahorse_validity_get_string (validity));
}

static void
setup_trust_dropdown (SeahorsePgpKeyProperties *self)
{
    gtk_custom_filter_set_filter_func (self->owner_trust_filter,
                                       key_trust_filter_func,
                                       self,
                                       NULL);
}

static void
do_details (SeahorsePgpKeyProperties *self)
{
    AdwComboRow *owner_trust_row = ADW_COMBO_ROW (self->owner_trust_row);
    SeahorseFlags flags;
    GListModel *model;
    int trust;

    if (!seahorse_pgp_key_is_private_key (self->key)) {
        gtk_widget_set_visible (self->owner_trust_row,
                                SEAHORSE_GPGME_IS_KEY (self->key));
    }

    flags = seahorse_object_get_flags (SEAHORSE_OBJECT (self->key));
    gtk_widget_set_sensitive (self->owner_trust_row,
                              !(flags & SEAHORSE_FLAG_DISABLED));

    trust = seahorse_pgp_key_get_trust (self->key);
    model = adw_combo_row_get_model (owner_trust_row);
    for (unsigned int i = 0; i < g_list_model_get_n_items (model); i++) {
        g_autoptr(AdwEnumListItem) item = g_list_model_get_item (model, i);

        if (trust == adw_enum_list_item_get_value (item)) {
            adw_combo_row_set_selected (owner_trust_row, i);
            break;
        }
    }
}

static void
on_trust_marginal_switch_notify_active (GObject    *object,
                                        GParamSpec *new_state,
                                        void       *user_data)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (user_data);
    SeahorseValidity trust;
    gpgme_error_t err;

    g_return_if_fail (SEAHORSE_GPGME_IS_KEY (self->key));

    trust = gtk_switch_get_active (GTK_SWITCH (object)) ?
            SEAHORSE_VALIDITY_MARGINAL : SEAHORSE_VALIDITY_UNKNOWN;

    if (seahorse_pgp_key_get_trust (self->key) != trust) {
        err = seahorse_gpgme_key_op_set_trust (SEAHORSE_GPGME_KEY (self->key), trust);
        if (err)
            seahorse_gpgme_handle_error (err, _("Unable to change trust"));
    }
}

/* Add a signature */
static void
on_sign_key (GtkWidget* widget, const char *action_name, GVariant *param)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (widget);
    SeahorseGpgmeSignDialog *dialog;

    g_return_if_fail (SEAHORSE_GPGME_IS_KEY (self->key));

    dialog = seahorse_gpgme_sign_dialog_new (SEAHORSE_OBJECT (self->key));
    gtk_window_present (GTK_WINDOW (dialog));
}

static gboolean
key_have_signatures (SeahorsePgpKey *pkey, unsigned int types)
{
    GListModel *uids;

    uids = seahorse_pgp_key_get_uids (pkey);
    for (unsigned int i = 0; i < g_list_model_get_n_items (uids); i++) {
        g_autoptr(SeahorsePgpUid) uid = g_list_model_get_item (uids, i);
        GListModel *sigs;

        sigs = seahorse_pgp_uid_get_signatures (uid);
        for (unsigned int j = 0; j < g_list_model_get_n_items (sigs); j++) {
            g_autoptr(SeahorsePgpSignature) sig = g_list_model_get_item (sigs, j);
            if (seahorse_pgp_signature_get_sigtype (sig) & types)
                return TRUE;
        }
    }

    return FALSE;
}

static void
do_trust (SeahorsePgpKeyProperties *self)
{
    gboolean sigpersonal;

    if (seahorse_object_get_usage (SEAHORSE_OBJECT (self->key)) != SEAHORSE_USAGE_PUBLIC_KEY)
        return;

    /* Remote keys */
    if (!SEAHORSE_GPGME_IS_KEY (self->key)) {
        gtk_widget_set_visible (self->trust_marginal_switch, TRUE);
        gtk_widget_set_sensitive (self->trust_marginal_switch, FALSE);
        gtk_widget_set_visible (self->trust_sign_row, FALSE);

    /* Local keys */
    } else {
        unsigned int trust;
        gboolean managed = FALSE;

        trust = seahorse_pgp_key_get_trust (self->key);

        switch (trust) {
        /* We shouldn't be seeing this page with these trusts */
        case SEAHORSE_VALIDITY_REVOKED:
        case SEAHORSE_VALIDITY_DISABLED:
            return;
        /* Trust is specified manually */
        case SEAHORSE_VALIDITY_ULTIMATE:
        case SEAHORSE_VALIDITY_NEVER:
            managed = FALSE;
            break;
        /* We manage the trust through this page */
        case SEAHORSE_VALIDITY_FULL:
        case SEAHORSE_VALIDITY_MARGINAL:
        case SEAHORSE_VALIDITY_UNKNOWN:
            managed = TRUE;
            break;
        default:
            g_warning ("unknown trust value: %d", trust);
            g_assert_not_reached ();
            return;
        }

        /* Managed and unmanaged areas */
        gtk_widget_set_visible (self->trust_marginal_switch, managed);

        /* Managed check boxes */
        if (managed) {
            gtk_switch_set_active (GTK_SWITCH (self->trust_marginal_switch),
                                   (trust != SEAHORSE_VALIDITY_UNKNOWN));
        }

        /* Signing and revoking */
        sigpersonal = key_have_signatures (self->key, SKEY_PGPSIG_PERSONAL);
        gtk_widget_set_visible (self->trust_sign_row, !sigpersonal);
    }
}

static void
key_notify (GObject *object, GParamSpec *pspec, void *user_data)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (user_data);

    do_owner (self);
    do_trust (self);
    do_details (self);
}

static void
create_public_key_dialog (SeahorsePgpKeyProperties *self)
{
    const char *user;
    g_autofree char *sign_text = NULL;
    g_autofree char *sign_text_esc = NULL;

    setup_trust_dropdown (self);
    do_owner (self);
    do_details (self);
    do_trust (self);

    /* Fill in trust labels with name. */
    user = seahorse_object_get_label (SEAHORSE_OBJECT (self->key));

    sign_text = g_strdup_printf(_("I believe “%s” is the owner of this key"),
                                user);
    sign_text_esc = g_markup_escape_text (sign_text, -1);
    adw_action_row_set_subtitle (ADW_ACTION_ROW (self->trust_sign_row), sign_text_esc);
    adw_action_row_set_subtitle_lines (ADW_ACTION_ROW (self->trust_sign_row), 0);
}

static void
create_private_key_dialog (SeahorsePgpKeyProperties *self)
{
    setup_trust_dropdown (self);
    do_owner (self);
    do_details (self);
}

static void
seahorse_pgp_key_properties_get_property (GObject      *object,
                                          unsigned int  prop_id,
                                          GValue       *value,
                                          GParamSpec   *pspec)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (object);

    switch (prop_id) {
    case PROP_KEY:
        g_value_set_object (value, self->key);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
seahorse_pgp_key_properties_set_property (GObject      *object,
                                          unsigned int  prop_id,
                                          const GValue *value,
                                          GParamSpec   *pspec)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (object);

    switch (prop_id) {
    case PROP_KEY:
        g_set_object (&self->key, g_value_get_object (value));
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
seahorse_pgp_key_properties_finalize (GObject *obj)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (obj);

    g_clear_object (&self->key);

    G_OBJECT_CLASS (seahorse_pgp_key_properties_parent_class)->finalize (obj);
}

static void
seahorse_pgp_key_properties_constructed (GObject *obj)
{
    SeahorsePgpKeyProperties *self = SEAHORSE_PGP_KEY_PROPERTIES (obj);
    SeahorseUsage usage;
    GtkWidget *uids_listbox, *subkeys_listbox;
    const char *name;
    g_autofree char *title = NULL;
    gboolean is_public_key;

    G_OBJECT_CLASS (seahorse_pgp_key_properties_parent_class)->constructed (obj);

    usage = seahorse_object_get_usage (SEAHORSE_OBJECT (self->key));
    is_public_key = (usage == SEAHORSE_USAGE_PUBLIC_KEY);
    if (is_public_key)
        create_public_key_dialog (self);
    else
        create_private_key_dialog (self);

    uids_listbox = seahorse_pgp_uid_list_box_new (self->key);
    gtk_box_append (GTK_BOX (self->uids_container), uids_listbox);

    subkeys_listbox = seahorse_pgp_subkey_list_box_new (self->key);
    gtk_box_append (GTK_BOX (self->subkeys_container), subkeys_listbox);

    /* Some trust rows are only make sense for public keys */
    gtk_widget_set_visible (self->trust_page, is_public_key);
    gtk_widget_set_visible (self->owner_trust_row, is_public_key);
    gtk_widget_set_visible (self->trust_sign_row, is_public_key);
    gtk_widget_set_visible (self->trust_marginal_switch, is_public_key);

    g_signal_connect_object (self->key, "notify",
                             G_CALLBACK (key_notify), self, 0);

    /* Titlebar */
    name = seahorse_pgp_key_get_primary_name (self->key);

    /* Translators: the 1st part of the title is the owner's name */
    title = (!is_public_key)? g_strdup_printf (_("%s — Public key"), name)
                            : g_strdup_printf (_("%s — Private key"), name);
    gtk_widget_set_visible (self->menu_button, !is_public_key);
    adw_window_title_set_title (ADW_WINDOW_TITLE (self->window_title), title);
}

static void
seahorse_pgp_key_properties_init (SeahorsePgpKeyProperties *self)
{
    gtk_widget_init_template (GTK_WIDGET (self));
}

static void
seahorse_pgp_key_properties_class_init (SeahorsePgpKeyPropertiesClass *klass)
{
    GObjectClass *gobject_class = G_OBJECT_CLASS (klass);
    GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);

    gobject_class->constructed = seahorse_pgp_key_properties_constructed;
    gobject_class->get_property = seahorse_pgp_key_properties_get_property;
    gobject_class->set_property = seahorse_pgp_key_properties_set_property;
    gobject_class->finalize = seahorse_pgp_key_properties_finalize;

    properties[PROP_KEY] =
        g_param_spec_object ("key", NULL, NULL,
                             SEAHORSE_PGP_TYPE_KEY,
                             G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
    g_object_class_install_properties (gobject_class, N_PROPS, properties);

    gtk_widget_class_set_template_from_resource (widget_class,
                                                 "/org/gnome/Seahorse/seahorse-pgp-key-properties.ui");
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          window_title);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          menu_button);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          name_label);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          email_label);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          comment_label);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          keyid_label);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          fingerprint_label);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          expires_label);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          revoked_banner);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          expired_banner);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          owner_trust_row);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          owner_trust_filter);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          uids_container);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          subkeys_container);

    /* public keys only */
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          trust_page);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          trust_sign_row);
    gtk_widget_class_bind_template_child (widget_class,
                                          SeahorsePgpKeyProperties,
                                          trust_marginal_switch);

    gtk_widget_class_bind_template_callback (widget_class,
                                             on_owner_trust_selected_changed);
    gtk_widget_class_bind_template_callback (widget_class,
                                             pgp_trust_to_string);
    gtk_widget_class_bind_template_callback (widget_class,
                                             on_trust_marginal_switch_notify_active);

    /* ACTIONS */
    /* Private keys only */
    gtk_widget_class_install_action (widget_class, "change-password", NULL, on_change_password);
    gtk_widget_class_install_action (widget_class, "change-expires", NULL, on_change_expires);
    gtk_widget_class_install_action (widget_class, "export-secret", NULL, on_export_secret);
    gtk_widget_class_install_action (widget_class, "export-public", NULL, on_export_public);
    /* Public keys only */
    gtk_widget_class_install_action (widget_class, "sign-key", NULL, on_sign_key);
}

GtkWindow *
seahorse_pgp_key_properties_new (SeahorsePgpKey *pkey, GtkWindow *parent)
{
    g_autoptr(SeahorsePgpKeyProperties) dialog = NULL;

    /* This causes the key source to get any specific info about the key */
    if (SEAHORSE_GPGME_IS_KEY (pkey)) {
        seahorse_gpgme_key_refresh (SEAHORSE_GPGME_KEY (pkey));
        seahorse_gpgme_key_ensure_signatures (SEAHORSE_GPGME_KEY (pkey));
    }

    dialog = g_object_new (SEAHORSE_PGP_TYPE_KEY_PROPERTIES,
                           "key", pkey,
                           "transient-for", parent,
                           NULL);

    return GTK_WINDOW (g_steal_pointer (&dialog));
}
