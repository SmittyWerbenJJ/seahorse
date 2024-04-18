/*
 * Seahorse
 *
 * Copyright (C) 2003 Jacob Perkins
 * Copyright (C) 2004 - 2006 Stefan Walter
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2017 Niels De Graef
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

// TODO move these into a namespace or class
public const int SEAHORSE_PASS_BAD = 0x00000001;
public const int SEAHORSE_PASS_NEW = 0x01000000;

public class Seahorse.PassphrasePrompt : Gtk.Dialog {

    private Gtk.PasswordEntry pass_entry;
    private Gtk.PasswordEntry? confirm_entry;
    private Gtk.CheckButton? check_option;

    public PassphrasePrompt (string? title, string? description, string prompt, string? check, bool confirm) {
        GLib.Object(
            title: title,
            modal: true,
            icon_name: "dialog-password-symbolic"
        );

        Gtk.Box wvbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 24);
        set_child(wvbox);

        Gtk.Box chbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        wvbox.append(chbox);

        // The image
        Gtk.Image img = new Gtk.Image.from_icon_name("dialog-password-symbolic");
        chbox.append(img);

        Gtk.Box box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        chbox.append(box);

        // The description text
        if (description != null) {
            Gtk.Label desc_label = new Gtk.Label(utf8_validate (description));
            desc_label.xalign = 0;
            desc_label.wrap = true;
            box.append(desc_label);
        }

        Gtk.Grid grid = new Gtk.Grid();
        grid.set_row_spacing(6);
        grid.set_column_spacing(12);
        box.append(grid);

        // The first entry (if we have one)
        if (confirm) {
            Gtk.Label prompt_label = new Gtk.Label(utf8_validate (prompt));
            prompt_label.xalign = 0;
            grid.attach(prompt_label, 0, 0);

            this.confirm_entry = new Gtk.PasswordEntry();
            this.confirm_entry.set_size_request(200, -1);
            this.confirm_entry.activate.connect(confirm_callback);
            this.confirm_entry.changed.connect(entry_changed);
            grid.attach(this.confirm_entry, 1, 0);
            this.confirm_entry.grab_focus();
        }

        // The second and main entry
        Gtk.Label confirm_label = new Gtk.Label(utf8_validate (confirm? _("Confirm:") : prompt));
        confirm_label.xalign = 0;
        grid.attach(confirm_label, 0, 1);

        this.pass_entry = new Gtk.PasswordEntry();
        this.pass_entry.set_size_request(200, -1);
        this.pass_entry.activate.connect(() => {
            if (get_widget_for_response(Gtk.ResponseType.ACCEPT).sensitive)
                response(Gtk.ResponseType.ACCEPT);
        });
        grid.attach(pass_entry, 1, 1);
        if (confirm)
            this.pass_entry.changed.connect(entry_changed);
        else
            this.pass_entry.grab_focus();

        // The checkbox
        if (check != null) {
            this.check_option = new Gtk.CheckButton.with_mnemonic(check);
            grid.attach(this.check_option, 1, 2);
        }

        Gtk.Button cancel_button = new Gtk.Button.with_mnemonic(_("_Cancel"));
        add_action_widget(cancel_button, Gtk.ResponseType.REJECT);

        Gtk.Button ok_button = new Gtk.Button.with_mnemonic(_("_OK"));
        add_action_widget(ok_button, Gtk.ResponseType.ACCEPT);
        set_default_widget(ok_button);

        set_resizable(false);

        if (confirm)
            entry_changed (null);
    }

    // Kept for backwards compatibility with the C code
    public static PassphrasePrompt show_dialog(string? title, string? description, string? prompt,
                                               string? check, bool confirm) {
        return new PassphrasePrompt(title, description, prompt ?? _("Password:"), check, confirm);
    }

    public string get_text() {
        return this.pass_entry.text;
    }

    public bool checked() {
        return this.check_option.active;
    }

    // Convert passed text to utf-8 if not valid
    private string? utf8_validate(string? text) {
        if (text == null)
            return null;

        if (text.validate())
            return text;

        string? result = text.locale_to_utf8(-1, null, null);
        if (result == null) {
            // Convert unknown characters into "?"
            char* p = (char*) text;

            while (!((string)p).validate (-1, out p))
                *p = '?';

            result = text;
        }
        return result;
    }

    /* When enter is pressed in the confirm entry, move */
    private void confirm_callback(Gtk.Widget widget) {
        this.pass_entry.grab_focus();
    }

    private void entry_changed (Gtk.Editable? editable) {
        set_response_sensitive(Gtk.ResponseType.ACCEPT,
                               this.pass_entry.text == this.confirm_entry.text);
    }

}
