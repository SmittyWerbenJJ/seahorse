/*
 * Seahorse
 *
 * Copyright (C) 2005 Stefan Walter
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2016 Niels De Graef
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

[GtkTemplate (ui = "/org/gnome/Seahorse/seahorse-ssh-key-properties.ui")]
public class Seahorse.Ssh.KeyProperties : Gtk.ApplicationWindow {

    public Key key { get; construct set; }

    // Used to make sure we don't start calling command unnecessarily
    private bool updating_ui = false;

    [GtkChild] private unowned Adw.EntryRow comment_row;

    [GtkChild] private unowned Adw.ActionRow algo_row;
    [GtkChild] private unowned Adw.ActionRow key_length_row;
    [GtkChild] private unowned Adw.ActionRow location_row;
    [GtkChild] private unowned Adw.ActionRow fingerprint_row;

    [GtkChild] private unowned Gtk.Label pubkey_label;

    [GtkChild] private unowned Gtk.Switch trust_check;

    static construct {
        install_action("copy-public-key", null, (Gtk.WidgetActionActivateFunc) on_copy_public_key);
        install_action("change-passphrase", null, (Gtk.WidgetActionActivateFunc) on_change_passphrase);
        install_action("export-secret-key", null, (Gtk.WidgetActionActivateFunc) action_export_secret_key);
        install_action("delete-key", null, (Gtk.WidgetActionActivateFunc) on_delete_key);
    }

    public KeyProperties(Key key, Gtk.Window? parent = null) {
        GLib.Object(key: key, transient_for: parent);

        update_ui();

        // A public key only
        if (key.usage != Seahorse.Usage.PRIVATE_KEY) {
            action_set_enabled("change-passphrase", false);
            action_set_enabled("export-secret-key", false);
        }

        this.key.notify.connect((obj, pspec) => update_ui());
    }

    private void update_ui() {
        this.updating_ui = true;

        // Name and title
        this.comment_row.text = this.key.label;

        // Setup the check
        this.trust_check.active = (this.key.trust >= Seahorse.Validity.FULL);

        this.fingerprint_row.subtitle = "<span font=\"monospace\">%s</span>".printf(this.key.fingerprint);
        this.algo_row.subtitle = this.key.get_algo().to_string() ?? _("Unknown type");
        this.location_row.subtitle = this.key.get_location();
        this.key_length_row.subtitle = "%u".printf(this.key.get_strength());
        this.pubkey_label.label = this.key.pubkey;

        this.updating_ui = false;
    }

    [GtkCallback]
    public void on_ssh_comment_apply(Adw.EntryRow entry) {
        // Make sure not the same
        if (key.key_data.comment != null && entry.text == key.key_data.comment)
            return;

        entry.sensitive = false;

        RenameOperation op = new RenameOperation();
        op.rename_async.begin(key, entry.text, this, (obj, res) => {
            try {
                op.rename_async.end(res);
            } catch (GLib.Error e) {
                Seahorse.Util.show_error(this, _("Couldn’t rename key."), e.message);
                entry.text = key.key_data.comment ?? "";
            }

            entry.sensitive = true;
        });
    }

    [GtkCallback]
    private void on_ssh_trust_changed(GLib.Object button, GLib.ParamSpec p) {
        if (updating_ui)
            return;

        this.trust_check.sensitive = false;

        Source source = (Source) key.place;
        source.authorize_async.begin(key, trust_check.active, (obj, res) => {
            try {
                source.authorize_async.end(res);
            } catch (GLib.Error e) {
                Seahorse.Util.show_error(this, _("Couldn’t change authorization for key."), e.message);
            }

            trust_check.sensitive = true;
        });
    }

    private void on_change_passphrase(string action_name, Variant? param) {
        ChangePassphraseOperation op = new ChangePassphraseOperation();
        op.change_passphrase_async.begin(this.key, null, (obj, res) => {
            try {
                op.change_passphrase_async.end(res);
            } catch (GLib.Error e) {
                Seahorse.Util.show_error(this, _("Couldn’t change passphrase for key."), e.message);
            }
        });
    }

    private void on_delete_key(string action_name, Variant? param) {
        var delete_op = this.key.create_delete_operation();
        delete_op.execute_interactively.begin(this, null, (obj, res) => {
            try {
                delete_op.execute_interactively.end(res);
            } catch (GLib.IOError.CANCELLED e) {
                debug("Deletion of key cancelled by user");
            } catch (GLib.Error e) {
                Util.show_error(this, _("Couldn’t delete key"), e.message);
            }
        });
    }

    private void action_export_secret_key(string action_name, Variant? param) {
        export.begin(true, (obj, res) => {
            export.end(res);
        });
    }

    private async void export(bool secret)
            requires (this.key is Exportable) {
        var export_op = new Ssh.KeyExportOperation(this.key, secret);

        try {
            var prompted = yield export_op.prompt_for_file(this, null);
            if (!prompted) {
                debug("no file picked by user");
                return;
            }

            yield export_op.execute(null);
        } catch (GLib.IOError.CANCELLED e) {
            debug("Exporting of key cancelled by user");
        } catch (GLib.Error e) {
            Util.show_error(this, _("Couldn’t export key"), e.message);
        }
    }

    private void on_copy_public_key(string action_name, Variant? param) {
        get_clipboard().set_text(this.key.pubkey);
    }
}
