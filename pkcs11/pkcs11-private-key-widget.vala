/*
 * Seahorse
 *
 * Copyright (C) 2008 Stefan Walter
 * Copyright (C) 2013 Red Hat Inc.
 * Copyright (C) 2020 Niels De Graef
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *
 * Author: Stef Walter <stefw@redhat.com>
 */

//XXX XXX
[GtkTemplate (ui = "/org/gnome/Seahorse/pkcs11-private-key-widget.ui")]
public class Seahorse.Pkcs11.PrivateKeyWidget : Adw.PreferencesPage {

    public Pkcs11.PrivateKey key { construct; get; }

    [GtkChild] private unowned Gtk.Label name_label;
    [GtkChild] private unowned Gtk.Label description_label;

    //XXX
    // private Gcr.Viewer _viewer;
    private Pkcs11.PrivateKey _request_key;

    construct {
        // this._viewer = Gcr.Viewer.new_scrolled();
        // this.content.append(this._viewer);
        // this._viewer.set_hexpand(true);
        // this._viewer.set_vexpand(true);
        // this._viewer.show();

        /* ... */

        set_label_value (this.name_label, this.key.label, _("Unnamed key"));
        set_label_value (this.description_label, this.key.description, _("No description"));

        this.key.attributes.dump();
        // XXX
        // object.notify["label"].connect(() => { update_label(); });
        // update_label();

        // GLib.List<Exporter> exporters = null;
        // if (this.key is Exportable)
        //     exporters = ((Exportable)this.key).create_exporters(ExporterType.ANY);

        // this.export_button.set_visible(exporters != null);
    }

    public PrivateKeyWidget(Pkcs11.PrivateKey key) {
        GLib.Object(key: key);
    }

    private void set_label_value(Gtk.Label label, string? value, string fallback = _("Unknown")) {
        if (value != null && value != "") {
            label.label = value;
            label.selectable = true;
        } else {
            label.label = fallback;
            label.add_css_class("dim-label");
            label.selectable = false;
        }
    }

    private void check_certificate_request_capable(GLib.Object object) {
        if (!(object is PrivateKey))
            return;

        Gcr.CertificateRequest.capable_async.begin((PrivateKey)object, null, (obj, res) => {
            try {
                if (Gcr.CertificateRequest.capable_async.end(res)) {
                    //XXX
                    // this.request_certificate_button.set_visible(true);
                    this._request_key = (Pkcs11.PrivateKey) object;
                }
            } catch (GLib.Error err) {
                GLib.message("couldn't check capabilities of private key: %s", err.message);
            }
        });
    }
}
