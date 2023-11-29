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
    private unowned Gtk.Grid password_grid;
    private Gtk.Entry generated_password;
    [GtkChild]
    private unowned Gtk.SpinButton password_length_spin;
    [GtkChild]
    private unowned Gtk.CheckButton capital_letters;
    [GtkChild]
    private unowned Gtk.CheckButton lowercase_letters;
    [GtkChild]
    private unowned Gtk.CheckButton numbers;
    [GtkChild]
    private unowned Gtk.CheckButton symbols;
    [GtkChild]
    private unowned Gtk.LevelBar password_strength_bar;
    [GtkChild]
    private unowned Gtk.Image password_strength_icon;

    private PasswordQuality.Settings pwquality = new PasswordQuality.Settings();

    construct {
        this.generated_password = new PasswordEntry();
        this.generated_password.visibility = false;
        this.generated_password.changed.connect(on_generated_password_changed);
        this.password_grid.attach(this.generated_password, 1, 0);
        this.generated_password.show();

        generate_password();
    }

    public GeneratePassword(Gtk.Window? parent) {
        GLib.Object(
            transient_for: parent,
            use_header_bar: 1
        );
    }

    private void generate_password() {
        string capital_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        string lower_chars = "abcdefghijklmnopqrstuvwxyz";
        string number_chars = "1234567890";
        string symbol_chars = ",.<>/?:;\\^~%$@![]#{}()";
        string characters = "";

        if (this.capital_letters.active == true)
            characters += capital_chars;
        if (this.lowercase_letters.active == true)
            characters += lower_chars;
        if (this.numbers.active == true)
            characters += number_chars;
        if (this.symbols.active == true)
            characters += symbol_chars;

        var password = new StringBuilder ();
        int len = (int) this.password_length_spin.get_value();
        for (int i = 0; i < len; i++) {
            int ran_char = Random.int_range(0, characters.length);
            password.append(characters.substring(ran_char, 1));
        }

        this.generated_password.set_text(password.str);
    }

    private void on_generated_password_changed (Gtk.Editable entry) {
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

    [GtkCallback]
    private void on_capital_letters_toggled (Gtk.ToggleButton status) {
        if (status.active == true)
            this.capital_letters.active = true;
         else
            this.capital_letters.active = false;

        if (this.lowercase_letters.active == false && this.numbers.active == false && this.symbols.active == false)
            status.set_active(true);

        generate_password();
    }

    [GtkCallback]
    private void on_lowercase_letters_toggled (Gtk.ToggleButton status) {
        if (status.active == true)
            this.lowercase_letters.active = true;
         else
            this.lowercase_letters.active = false;

        if (this.capital_letters.active == false && this.numbers.active == false && this.symbols.active == false)
            status.set_active(true);

        generate_password();
    }

    [GtkCallback]
    private void on_numbers_toggled (Gtk.ToggleButton status) {
         if (status.active == true)
            this.numbers.active = true;
         else
            this.numbers.active = false;

        if (this.lowercase_letters.active == false && this.capital_letters.active == false && this.symbols.active == false)
            status.set_active(true);

        generate_password();
    }

    [GtkCallback]
    private void on_symbols_toggled (Gtk.ToggleButton status) {
         if (status.active == true)
            this.symbols.active = true;
         else
            this.symbols.active = false;

        if (this.lowercase_letters.active == false && this.numbers.active == false && this.capital_letters.active == false)
            status.set_active(true);

        generate_password();
    }

    [GtkCallback]
    private void on_password_length_spin_value_changed (Gtk.SpinButton status) {
        generate_password();
    }
}
