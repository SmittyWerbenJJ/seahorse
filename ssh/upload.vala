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

[GtkTemplate (ui = "/org/gnome/Seahorse/seahorse-ssh-upload.ui")]
public class Seahorse.Ssh.Upload : Gtk.Dialog {

    private unowned List<Key> keys;

    [GtkChild] private unowned Adw.EntryRow host_row;
    [GtkChild] private unowned Adw.EntryRow user_row;

    [GtkChild] private unowned Gtk.Button setup_button;

    public Upload(List<Key> keys, Gtk.Window? parent) {
        GLib.Object(use_header_bar: 1);
        this.transient_for = parent;
        this.keys = keys;

        // Default to the users current name
        this.user_row.text = Environment.get_user_name();

        on_upload_input_changed();
    }

    private void upload_keys() {
        string user = this.user_row.text.strip();
        string host_port = this.host_row.text.strip();

        if (!user.validate() || host_port == "" || !host_port.validate())
            return;

        // Port is anything past a colon
        string[] host_port_split = host_port.split(":", 2);
        string host = host_port_split[0];
        string? port = (host_port_split.length == 2)? host_port_split[1] : null;

        Cancellable cancellable = new Cancellable();

        // Start the upload process
        UploadOperation op = new UploadOperation();
        op.upload_async.begin(keys, user, host, port, cancellable, (obj, res) => {
            try {
                op.upload_async.end(res);
            } catch (GLib.Error e) {
                Seahorse.Util.show_error(this, _("Couldn’t configure Secure Shell keys on remote computer."), e.message);
            }
        });

        Seahorse.Progress.show(cancellable, _("Configuring Secure Shell Keys…"), false);
    }

    [GtkCallback]
    private void on_upload_input_changed () {
        string user = this.user_row.text;
        string host = this.host_row.text;

        if (!user.validate() || !host.validate())
            return;

        // Take off port if necessary
        int port_pos = host.index_of_char(':');
        if (port_pos > 0) {
            host = host.substring(0, port_pos);
        }

        this.setup_button.sensitive = (host.strip() != "") && (user.strip() != "");
    }

    /**
     * Prompt a dialog to upload keys.
     *
     * @param keys The set of SSH keys that should be uploaded
     */
    public static void prompt(List<Key>? keys, Gtk.Window? parent) {
        if (keys == null)
            return;

        Upload upload_dialog = new Upload(keys, parent);
        upload_dialog.response.connect((response) => {
            if (response == Gtk.ResponseType.ACCEPT)
                upload_dialog.upload_keys();
            upload_dialog.destroy();
        });
    }

}
