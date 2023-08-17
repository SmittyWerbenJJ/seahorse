/*
 * Seahorse
 *
 * Copyright (C) 2023 Jan-Michael Brummer <jan-michael.brummer1@volkswagen.de>
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

public class Seahorse.ChangePinPrompt : Gtk.Dialog {
    // gnome hig small space in pixels
    private const int HIG_SMALL = 6;
    // gnome hig large space in pixels
    private const int HIG_LARGE = 12;

    private Gtk.Entry old_pin_entry;
    private Gtk.Entry new_pin_entry;
    private Gtk.Entry? confirm_entry;

#if ! _DEBUG
    private bool keyboard_grabbed;
#endif

    public ChangePinPrompt (string? description) {
        GLib.Object(
            title: _("Change PIN"),
            modal: true,
            icon_name: "dialog-password-symbolic"
        );

        Gtk.Box wvbox = new Gtk.Box(Gtk.Orientation.VERTICAL, HIG_LARGE * 2);
        get_content_area().add(wvbox);
        wvbox.set_border_width(HIG_LARGE);

        Gtk.Box chbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, HIG_LARGE);
        wvbox.pack_start (chbox, false, false);

        // The image
        Gtk.Image img = new Gtk.Image.from_icon_name("dialog-password-symbolic", Gtk.IconSize.DIALOG);
        img.set_alignment(0.0f, 0.0f);
        chbox.pack_start(img, false, false);

        Gtk.Box box = new Gtk.Box(Gtk.Orientation.VERTICAL, HIG_SMALL);
        chbox.pack_start (box);

        // The description text
        Gtk.Label desc_label = new Gtk.Label(utf8_validate (description));
        desc_label.set_alignment(0.0f, 0.5f);
        desc_label.set_line_wrap(true);
        box.pack_start(desc_label, true, false);

        Gtk.Grid grid = new Gtk.Grid();
        grid.set_row_spacing(HIG_SMALL);
        grid.set_column_spacing(HIG_LARGE);
        box.pack_start(grid, false, false);

        /* Old PIN */
        Gtk.Label old_prompt_label = new Gtk.Label(utf8_validate (_("Old PIN")));
        old_prompt_label.set_alignment(0.0f, 0.5f);
        grid.attach(old_prompt_label, 0, 0);

        this.old_pin_entry = new Gtk.Entry.with_buffer(new Gcr.SecureEntryBuffer());
        this.old_pin_entry.set_visibility(false);
        this.old_pin_entry.set_size_request(200, -1);
        this.old_pin_entry.activate.connect(confirm_callback);
        this.old_pin_entry.changed.connect(entry_changed);
        grid.attach(this.old_pin_entry, 1, 0);
        this.old_pin_entry.grab_focus();

        /* New PIN */
        Gtk.Label prompt_label = new Gtk.Label(utf8_validate (_("New PIN")));
        prompt_label.set_alignment(0.0f, 0.5f);
        grid.attach(prompt_label, 0, 1);

        this.confirm_entry = new Gtk.Entry.with_buffer(new Gcr.SecureEntryBuffer());
        this.confirm_entry.set_visibility(false);
        this.confirm_entry.set_size_request(200, -1);
        this.confirm_entry.activate.connect(confirm_callback);
        this.confirm_entry.changed.connect(entry_changed);
        grid.attach(this.confirm_entry, 1, 1);

        // The second and main entry
        Gtk.Label confirm_label = new Gtk.Label(utf8_validate (_("Confirm:")));
        confirm_label.set_alignment(0.0f, 0.5f);
        grid.attach(confirm_label, 0, 2);

        this.new_pin_entry = new Gtk.Entry.with_buffer(new Gcr.SecureEntryBuffer());
        this.new_pin_entry.set_size_request(200, -1);
        this.new_pin_entry.set_visibility(false);
        this.new_pin_entry.activate.connect(() => {
            if (get_widget_for_response(Gtk.ResponseType.ACCEPT).sensitive)
                response(Gtk.ResponseType.ACCEPT);
        });
        grid.attach(new_pin_entry, 1, 2);
        this.new_pin_entry.changed.connect(entry_changed);

        grid.show_all();

        Gtk.Button cancel_button = new Gtk.Button.with_mnemonic(_("_Cancel"));
        add_action_widget(cancel_button, Gtk.ResponseType.REJECT);
        cancel_button.set_can_default(true);

        Gtk.Button ok_button = new Gtk.Button.with_mnemonic(_("_OK"));
        add_action_widget(ok_button, Gtk.ResponseType.ACCEPT);
        ok_button.set_can_default(true);
        ok_button.grab_default();

        // Signals
        this.map_event.connect(grab_keyboard);
        this.unmap_event.connect(ungrab_keyboard);
        this.window_state_event.connect(window_state_changed);
        this.key_press_event.connect(key_press);

        set_position(Gtk.WindowPosition.CENTER);
        set_resizable(false);
        set_keep_above(true);
        show_all();
        get_window().focus(Gdk.CURRENT_TIME);
    }

    // Kept for backwards compatibility with the C code
    public static ChangePinPrompt show_dialog(string? description) {
        return new ChangePinPrompt(description);
    }

    public string get_old_pin() {
        return this.old_pin_entry.text;
    }

    public string get_new_pin() {
        return this.new_pin_entry.text;
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

    private bool key_press (Gtk.Widget widget, Gdk.EventKey event) {
        // Close the dialog when hitting "Esc".
        if (event.keyval == Gdk.Key.Escape) {
            response(Gtk.ResponseType.REJECT);
            return true;
        }

        return false;
    }

    private bool grab_keyboard(Gtk.Widget win, Gdk.Event event) {
#if ! _DEBUG
        if (!this.keyboard_grabbed) {
            Gdk.Display display = Gdk.Display.get_default();
            Gdk.Seat seat = display.get_default_seat();

            var grab_status = seat.grab(win.get_window(),
                                        Gdk.SeatCapabilities.KEYBOARD,
                                        false,
                                        null,
                                        event,
                                        null);

            if (grab_status != Gdk.GrabStatus.SUCCESS)
                message("could not grab keyboard: %u", grab_status);
        }
        this.keyboard_grabbed = true;
#endif
        return false;
    }

    /* ungrab_keyboard - remove grab */
    private bool ungrab_keyboard (Gtk.Widget win, Gdk.Event event) {
#if ! _DEBUG
        if (this.keyboard_grabbed) {
            Gdk.Display display = Gdk.Display.get_default();
            Gdk.Seat seat = display.get_default_seat();

            seat.ungrab();
		}
        this.keyboard_grabbed = false;
#endif
        return false;
    }

    /* When enter is pressed in the confirm entry, move */
    private void confirm_callback(Gtk.Widget widget) {
        this.new_pin_entry.grab_focus();
    }

    private void entry_changed (Gtk.Editable? editable) {
        set_response_sensitive(Gtk.ResponseType.ACCEPT,
                               this.new_pin_entry.text == this.confirm_entry.text);
    }

    private bool window_state_changed (Gtk.Widget win, Gdk.EventWindowState event) {
        Gdk.WindowState state = win.get_window().get_state();

        if (Gdk.WindowState.WITHDRAWN in state ||
            Gdk.WindowState.ICONIFIED in state ||
            Gdk.WindowState.FULLSCREEN in state ||
            Gdk.WindowState.MAXIMIZED in state)
                ungrab_keyboard (win, event);
        else
            grab_keyboard (win, event);

        return false;
    }

}
