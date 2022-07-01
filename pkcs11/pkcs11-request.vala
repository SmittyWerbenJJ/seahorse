/*
 * Seahorse
 *
 * Copyright (C) 2008 Stefan Walter
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2013 Red Hat Inc.
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
 * Stef Walter <stefw@redhat.com>
 */

public class Seahorse.Pkcs11.Request : Gtk.Dialog {

    public Pkcs11.PrivateKey private_key { construct; get; }

    private Gtk.Entry _name_entry;
    private uint8[] _encoded;

    construct {
        var builder = new Gtk.Builder();
        var path = "/org/gnome/Seahorse/pkcs11-request.ui";
        try {
            builder.add_from_resource(path);
        } catch (GLib.Error err) {
            GLib.warning("couldn't load ui file: %s", path);
            return;
        }

        this.set_resizable(false);
        var content = this.get_content_area();
        var widget = (Gtk.Widget)builder.get_object("pkcs11-request");
        content.append(widget);

        this._name_entry = (Gtk.Entry)builder.get_object("request-name");
        this._name_entry.changed.connect(() => { update_response(); });

        // The buttons
        this.add_buttons(_("_Cancel"), Gtk.ResponseType.CANCEL,
                         _("Create"), Gtk.ResponseType.OK);
        this.set_default_response (Gtk.ResponseType.OK);

        this.update_response ();

        if (!(this.private_key is Gck.Object)) {
            GLib.critical("private key is not of type %s", typeof(Gck.Object).name());
        }
    }

    public Request(Gtk.Window? parent,
                   Pkcs11.PrivateKey private_key) {
        GLib.Object(transient_for: parent, private_key: private_key);
    }

    public override void response(int response_id) {
        if (response_id == Gtk.ResponseType.OK) {
            var interaction = new Interaction(this.transient_for);
            var session = this.private_key.get_session();
            session.set_interaction(interaction);

            var req = Gcr.CertificateRequest.prepare(Gcr.CertificateRequestFormat.CERTIFICATE_REQUEST_PKCS10,
                                                     this.private_key);
            req.set_cn(this._name_entry.get_text());
            req.complete_async.begin(null, (obj, res) => {
                try {
                    req.complete_async.end(res);
                    this.save_certificate_request(req, this.transient_for);
                } catch (GLib.Error err) {
                    Util.show_error(this.transient_for, _("Couldn’t create certificate request"), err.message);
                }
            });

            this.hide();
        }
    }

    private void update_response() {
        string name = this._name_entry.get_text();
        this.set_response_sensitive(Gtk.ResponseType.OK, name != "");
    }

    private static string BAD_FILENAME_CHARS = "/\\<>|?*";

    private void save_certificate_request(Gcr.CertificateRequest req,
                                          Gtk.Window? parent) {
        var dialog = new Gtk.FileDialog();
        dialog.title = _("Save certificate request");

        // Filter on specific extensions/mime types
        var filters = new GLib.ListStore(typeof(Gtk.FileFilter));

        var der_filter = new Gtk.FileFilter();
        der_filter.name = _("Certificate request");
        der_filter.add_mime_type("application/pkcs10");
        der_filter.add_pattern("*.p10");
        der_filter.add_pattern("*.csr");
        filters.append(der_filter);

        var pem_filter = new Gtk.FileFilter();
        pem_filter.name = _("PEM encoded request");
        pem_filter.add_mime_type("application/pkcs10+pem");
        pem_filter.add_pattern("*.pem");
        filters.append(pem_filter);

        dialog.filters = filters;
        dialog.default_filter = der_filter;

        // Set the initial filename
        string? label;
        this.private_key.get("label", out label);
        if (label == null || label == "")
            label = "Certificate Request";
        var filename = label + ".csr";
        filename = filename.delimit(BAD_FILENAME_CHARS, '_');
        dialog.initial_name = filename;

        dialog.save.begin(parent, null, (obj, res) => {
            try {
                var file = dialog.save.end(res);
                if (file == null)
                    return;

                bool textual = file.get_path().has_suffix(".pem");
                this._encoded = req.encode(textual);

                file.replace_contents_async.begin(this._encoded, null, false,
                                                  GLib.FileCreateFlags.NONE,
                                                  null, (obj, res) => {
                    try {
                        string new_etag;
                        file.replace_contents_async.end(res, out new_etag);
                    } catch (GLib.Error err) {
                        Util.show_error(parent, _("Couldn’t save certificate request"), err.message);
                    }
                });
            } catch (Error e) {
                Util.show_error(parent, _("Couldn’t save certificate request"), e.message);
            }
        });
    }
}
