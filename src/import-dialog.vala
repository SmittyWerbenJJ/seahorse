/*
 * Seahorse
 *
 * Copyright (C) 2011 Collabora Ltd.
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
 *
 * Author: Stef Walter <stefw@collabora.co.uk>
 */

public class Seahorse.ImportDialog : Gtk.Dialog {

    private Gcr.Parser parser;
    private GLib.ListStore parsed_items = new GLib.ListStore(typeof(GLib.Object));

    public InputStream input { get; construct set; }

    construct {
        var button = new Gtk.Button.with_mnemonic(_("_Cancel"));
        add_action_widget(button, Gtk.ResponseType.CANCEL);

        var import_button = new Gtk.Button.with_mnemonic(_("_Import"));
        add_action_widget(import_button, Gtk.ResponseType.ACCEPT);
        set_response_sensitive(Gtk.ResponseType.ACCEPT, false);

        // Create the parser and listen to its signals
        this.parser = new Gcr.Parser();
        this.parser.parsed.connect(on_parser_parsed);
        this.parser.authenticate.connect(on_parser_authenticate);

        parse_input.begin();
    }

    public ImportDialog(InputStream input,
                        string? title,
                        Gtk.Window? parent) {
        GLib.Object(
            input: input,
            transient_for: parent,
            title: title ?? _("Import Data"),
            use_header_bar: 1
        );
    }

    private async void parse_input() {
        var cancellable = new Cancellable();

        try {
            debug("Parsing input");
            yield this.parser.parse_stream_async(this.input, cancellable);
            debug("Successfully parsed input");
        } catch (GLib.Error err) {
            warning("Error parsing input: %s", err.message);
            // XXX show some kind of error status page
        }
    }

    private void on_parser_parsed(Gcr.Parser parser) {
        var parsed = parser.get_parsed();
        var attributes = parsed.get_attributes();
        warning("Parsed a '%s' with format %d", parsed.get_description(), parsed.get_format());
        warning("ATTRIBUTES:\n%s", attributes.to_string());
        warning("CKO_PRIVATE_KEY == %d", Cryptoki.ObjectClass.PRIVATE_KEY);

        switch (parsed.get_format()) {
            case Gcr.DataFormat.DER_CERTIFICATE_X509:
                // Certificate
                debug("Parser found x.509 DER certificate");
                var certificate = new Gcr.SimpleCertificate(parsed.get_data());
                this.get_content_area().append(new Pkcs11.CertificateWidget(certificate));
                //XXX
                break;
            case Gcr.DataFormat.OPENPGP_PACKET:
                debug("Parser found OpenPGP packet");
                var key = Pgp.Backend.get().create_key_for_parsed(parsed);
                Viewable.view(key, null);
                break;
            case Gcr.DataFormat.OPENSSH_PUBLIC:
                debug("Parser found Public SSH Key");
                var stream = new MemoryInputStream.from_data(parsed.get_data());
                Ssh.Key.parse.begin(stream, null, (obj, res) => {
                    try {
                        var parse_res = Ssh.Key.parse.end(res);
                        // so much eek XXX
                        var key = new Ssh.Key(null, parse_res.public_keys[0]);
                        Viewable.view(key, null);
                        warning("Successfully parsed key data");
                    } catch (GLib.Error err) {
                        //XXX UI
                        warning("Couldn't parse SSH key data: %s", err.message);
                    }
                });
                break;
            default:
                warning("unsupported format %u", parsed.get_format());
                break;
        }

        // Check if we have any importers XXX
        var importers = Gcr.Importer.create_for_parsed(parsed);
        set_response_sensitive(Gtk.ResponseType.ACCEPT, importers == null);
    }

    private bool on_parser_authenticate(Gcr.Parser parser, int count) {
        //XXX
        return false; // not handled here
    }

    private void on_import_button_imported(GLib.Object importer, Error? error) {
        // if (error == null) {
        //     response(Gtk.ResponseType.OK);

        //     string uri = ((Gcr.Importer) importer).uri;
        //     foreach (Backend backend in Backend.get_registered()) {
        //         Place? place = backend.lookup_place(uri);
        //         if (place != null)
        //             place.load.begin(null);
        //     }

        // } else {
        //     if (!(error is GLib.IOError.CANCELLED))
        //         this.viewer.show_error(_("Import failed"), error);
        // }
    }
}
