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

    private bool capitals_status;
    private bool lowers_status;
    private bool numbers_status;
    private bool symbols_status;
    private int pw_length;
    private string capital_letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private string lower_letters = "abcdefghijklmnopqrstuvwxyz";
    private string numbers = "1234567890";
    private string symbols = ",.<>/?:;\\^~%$@![]#{}()";

    construct {
        this.capitals_status = true;
        this.lowers_status = true;
        this.numbers_status = true;
        this.symbols_status = false;
        this.pw_length = 24;
    }

    public GeneratePassword(Gtk.Window? parent) {
        GLib.Object(
            transient_for: parent,
            use_header_bar: 1
        );
    }

    private void generate_password() {
        string characters = "";
        if (this.capitals_status == true)
            characters += this.capital_letters;
        if (this.lowers_status == true)
            characters += this.lower_letters;
        if (this.numbers_status == true)
            characters += this.numbers;
        if (this.symbols_status == true)
            characters += this.symbols;
    }

    [GtkCallback]
    private void on_add_item_entry_changed (Gtk.Editable entry) {
        set_response_sensitive(Gtk.ResponseType.ACCEPT, this.item_entry.text != "");
    }

    [GtkCallback]
    private void on_capital_letters_toggled (Gtk.ToggleButton status) {
        if (status.active == true)
            this.capitals_status = true;
         else
            this.capitals_status = false;

        if (this.lowers_status == false && this.numbers_status == false && this.symbols_status == false)
            status.set_active(true);
    }

    [GtkCallback]
    private void on_lowercase_letters_toggled (Gtk.ToggleButton status) {
        if (status.active == true)
            this.lowers_status = true;
         else
            this.lowers_status = false;

        if (this.capitals_status == false && this.numbers_status == false && this.symbols_status == false)
            status.set_active(true);
    }

    [GtkCallback]
    private void on_numbers_toggled (Gtk.ToggleButton status) {
         if (status.active == true)
            this.numbers_status = true;
         else
            this.numbers_status = false;

        if (this.lowers_status == false && this.capitals_status == false && this.symbols_status == false)
            status.set_active(true);
    }

    [GtkCallback]
    private void on_symbols_toggled (Gtk.ToggleButton status) {
         if (status.active == true)
            this.symbols_status = true;
         else
            this.symbols_status = false;

        if (this.lowers_status == false && this.numbers_status == false && this.capitals_status == false)
            status.set_active(true);
    }

    [GtkCallback]
    private void on_password_length_value_changed (Gtk.SpinButton entry) {
        this.pw_length = (int) entry.get_value();
    }
}
