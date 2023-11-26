/*
 * Seahorse
 *
 * Copyright (C) 2023 Steven Oliver
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

[GtkTemplate (ui = "/org/gnome/Seahorse/seahorse-gkr-generate-password.ui")]
public class Seahorse.Gkr.GeneratePassword : Gtk.Dialog {
    [GtkChild]
    private unowned Gtk.Entry item_entry;

    construct {
    }

    public GeneratePassword(Gtk.Window? parent) {
        GLib.Object(
            transient_for: parent,
            use_header_bar: 1
        );
    }

    private void generate_password() {
        // TODO
    }

    [GtkCallback]
    private void on_add_item_entry_changed (Gtk.Editable entry) {
        set_response_sensitive(Gtk.ResponseType.ACCEPT, this.item_entry.text != "");
    }

    [GtkCallback]
    private void on_capital_letters_toggled (Gtk.ToggleButton status) {
        // TODO
    }

    [GtkCallback]
    private void on_lowercase_letters_toggled (Gtk.ToggleButton status) {
        // TODO
    }

    [GtkCallback]
    private void on_numbers_toggled (Gtk.ToggleButton status) {
        // TODO
    }

    [GtkCallback]
    private void on_symbols_toggled (Gtk.ToggleButton status) {
        // TODO
    }

    [GtkCallback]
    private void on_password_length_value_changed (Gtk.SpinButton entry) {
        // TODO
    }
}
