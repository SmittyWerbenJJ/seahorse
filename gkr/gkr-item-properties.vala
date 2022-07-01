/*
 * Seahorse
 *
 * Copyright (C) 2006 Stefan Walter
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2018 Niels De Graef
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
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */

[GtkTemplate (ui = "/org/gnome/Seahorse/seahorse-gkr-item-properties.ui")]
public class Seahorse.Gkr.ItemProperties : Gtk.Window {

    public Gkr.Item item { construct; get; }

    [GtkChild] private unowned Adw.WindowTitle window_title;
    [GtkChild] private unowned Adw.EntryRow description_field;
    [GtkChild] private unowned Gtk.Label use_field;
    [GtkChild] private unowned Gtk.Label type_field;

    [GtkChild] private unowned Adw.PreferencesGroup details_group;
    [GtkChild] private unowned Adw.ActionRow server_row;
    [GtkChild] private unowned Gtk.Label server_field;
    [GtkChild] private unowned Adw.ActionRow login_row;
    [GtkChild] private unowned Gtk.Label login_field;
    [GtkChild] private unowned Adw.PasswordEntryRow password_row;
    private string original_password = "";

    construct {
        // Setup the label properly
        this.item.bind_property("label", this.description_field, "text",
                                GLib.BindingFlags.SYNC_CREATE);

        // Window title
        this.item.bind_property("label", this.window_title, "subtitle",
                                GLib.BindingFlags.SYNC_CREATE);

        // Update as appropriate
        this.item.notify.connect((pspec) => {
            switch(pspec.name) {
            case "use":
                update_use();
                update_type();
                update_visibility();
                break;
            case "attributes":
                update_details();
                update_server();
                update_user();
                break;
            case "has-secret":
                fetch_password();
                break;
            }
        });

        // fill the password entry
        fetch_password();

        // Sensitivity of the password entry
        this.item.bind_property("has-secret", this.password_row, "sensitive");
    }

    public ItemProperties(Item item, Gtk.Window? parent) {
        GLib.Object (
            item: item,
            transient_for: parent
        );
        item.refresh();
    }

    private void update_use() {
        switch (this.item.use) {
        case Use.NETWORK:
            this.use_field.label = _("Access a network share or resource");
            break;
        case Use.WEB:
            this.use_field.label = _("Access a website");
            break;
        case Use.PGP:
            this.use_field.label = _("Unlocks a PGP key");
            break;
        case Use.SSH:
            this.use_field.label = _("Unlocks a Secure Shell key");
            break;
        case Use.OTHER:
            this.use_field.label = _("Saved password or login");
            break;
        default:
            this.use_field.label = "";
            break;
        };
    }

    private void update_type() {
        switch (this.item.use) {
        case Use.NETWORK:
        case Use.WEB:
            this.type_field.label = _("Network Credentials");
            break;
        case Use.PGP:
        case Use.SSH:
        case Use.OTHER:
            this.type_field.label = _("Password");
            break;
        default:
            this.type_field.label = "";
            break;
        };
    }

    private void update_visibility() {
        var use = this.item.use;
        this.server_row.visible =
            this.login_row.visible = (use == Use.NETWORK || use == Use.WEB);
    }

    private void update_server() {
        var value = this.item.get_attribute("server");
        if (value == null)
            value = "";
        this.server_field.label = value;
    }

    private void update_user() {
        var value = this.item.get_attribute("user");
        if (value == null)
            value = "";
        this.login_field.label = value;
    }

    private void update_details() {
        var attrs = this.item.attributes;
        var iter = GLib.HashTableIter<string, string>(attrs);

        bool any_details = false;
        string key, value;
        while (iter.next(out key, out value)) {
            if (key.has_prefix("gkr:") || key.has_prefix("xdg:"))
                continue;

            any_details = true;

            var row = new Adw.ActionRow();
            row.title = key;
            row.subtitle = value;
            row.subtitle_selectable = true;
            row.add_css_class("property");

            this.details_group.add(row);
        }

        this.details_group.visible = any_details;
    }

    private async void save_password() {
        var pw = new Secret.Value(this.password_row.text, -1, "text/plain");
        try {
            yield this.item.set_secret(pw, null);
        } catch (GLib.Error err) {
            DBusError.strip_remote_error(err);
            Util.show_error (this, _("Couldn’t change password."), err.message);
        }
        fetch_password();
    }

    private void fetch_password() {
        var secret = this.item.get_secret();
        if (secret != null) {
            this.original_password = secret.get_text() ?? "";
            this.password_row.text = this.original_password;
        }
    }

    private async void save_description() {
        try {
            yield this.item.set_label(this.description_field.text, null);
        } catch (GLib.Error err) {
            this.description_field.text = this.item.label;
            DBusError.strip_remote_error(err);
            Util.show_error (this, _("Couldn’t set description."), err.message);
        }
    }

    [GtkCallback]
    private void on_description_field_apply(Adw.EntryRow row) {
        save_description.begin();
    }

    [GtkCallback]
    private void on_password_row_apply(Adw.EntryRow row) {
        save_password.begin();
    }

    [GtkCallback]
    private void on_copy_button_clicked(Gtk.Button button) {
        this.item.copy_secret_to_clipboard.begin(get_clipboard());
    }

    [GtkCallback]
    private void on_delete_button_clicked() {
        var delete_op = this.item.create_delete_operation();
        delete_op.execute_interactively.begin(this, null, (obj, res) => {
            try {
                delete_op.execute_interactively.end(res);
            } catch (GLib.IOError.CANCELLED e) {
                debug("Deletion of secret cancelled by user");
            } catch (GLib.Error e) {
                Util.show_error(this, _("Couldn’t delete secret"), e.message);
            }
        });
    }
}
