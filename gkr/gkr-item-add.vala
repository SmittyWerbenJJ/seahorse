/*
 * Seahorse
 *
 * Copyright (C) 2008 Stefan Walter
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

[GtkTemplate (ui = "/org/gnome/Seahorse/seahorse-gkr-add-item.ui")]
public class Seahorse.Gkr.ItemAdd : Gtk.Dialog {

    [GtkChild] private unowned Adw.ComboRow keyring_row;
    [GtkChild] private unowned Adw.PasswordEntryRow password_row;
    [GtkChild] private unowned Adw.EntryRow description_row;

    [GtkChild] private unowned Gtk.LevelBar password_strength_bar;
    [GtkChild] private unowned Gtk.Image password_strength_icon;
    private PasswordQuality.Settings pwquality = new PasswordQuality.Settings();

    construct {
        // Set the list of all keyrings as model, and select the default
        var model = Gkr.Backend.instance();
        this.keyring_row.set_model(model);

        for (uint i = 0; i < model.get_n_items(); i++) {
            var keyring = (Gkr.Keyring) model.get_item(i);
            if (keyring.is_default)
                this.keyring_row.set_selected(i);
        }

        this.response.connect(on_response);
        set_response_sensitive(Gtk.ResponseType.ACCEPT, false);

        this.password_row.changed.connect(on_password_row_changed);
    }

    public ItemAdd(Gtk.Window? parent) {
        GLib.Object(
            transient_for: parent,
            use_header_bar: 1
        );
    }

    [GtkCallback]
    private void on_description_row_changed(Gtk.Editable editable) {
        set_response_sensitive(Gtk.ResponseType.ACCEPT, editable.text != "");
    }

    private void on_password_row_changed(Gtk.Editable entry) {
        void* auxerr;
        int score = this.pwquality.check(entry.get_chars(), null, null, out auxerr);

        if (score < 0) {
            PasswordQuality.Error err = ((PasswordQuality.Error) score);
            this.password_strength_icon.tooltip_text = dgettext("libpwquality", err.to_string(auxerr));
            this.password_strength_icon.show();
        } else {
            this.password_strength_icon.hide();
        }

        this.password_strength_bar.value = ((score / 25) + 1).clamp(1, 5);
    }

    private void on_response(int resp) {
        if (resp != Gtk.ResponseType.ACCEPT)
            return;

        var keyring = (Keyring) this.keyring_row.selected_item;
        var cancellable = new Cancellable();
        var interaction = new Interaction(this);

        keyring.unlock.begin(interaction, cancellable, (obj, res) => {
            try {
                if (keyring.unlock.end(res)) {
                    create_secret(this.description_row.text,
                                  this.password_row.text,
                                  keyring);
                }
            } catch (Error e) {
                Util.show_error(this, _("Couldn’t unlock"), e.message);
            }
        });
    }

    private void create_secret(string item,
                               string secret,
                               Secret.Collection collection) {
        var secret_val = new Secret.Value(secret, -1, "text/plain");
        var cancellable = Dialog.begin_request(this);
        var attributes = new HashTable<string, string>(GLib.str_hash, GLib.str_equal);

        /* TODO: Workaround for https://bugzilla.gnome.org/show_bug.cgi?id=697681 */
        var schema = new Secret.Schema("org.gnome.keyring.Note", Secret.SchemaFlags.NONE);

        Secret.Item.create.begin(collection, schema, attributes,
                                 item, secret_val, Secret.ItemCreateFlags.NONE,
                                 cancellable, (obj, res) => {
            try {
                /* Clear the operation without cancelling it since it is complete */
                Dialog.complete_request(this, false);

                Secret.Item.create.end(res);
            } catch (GLib.Error err) {
                Util.show_error(this, _("Couldn’t add item"), err.message);
            }
        });
    }
}
