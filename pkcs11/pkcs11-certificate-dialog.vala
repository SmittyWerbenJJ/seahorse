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

[GtkTemplate (ui = "/org/gnome/Seahorse/pkcs11-certificate-dialog.ui")]
public class Seahorse.Pkcs11.CertificateDialog : Gtk.ApplicationWindow {

    [GtkChild] private unowned Adw.ViewSwitcherTitle switcher_title;
    [GtkChild] private unowned Adw.ViewStack stack;

    public Pkcs11.Certificate? certificate { get; construct set; default = null; }
    public Pkcs11.PrivateKey? private_key { get; construct set; default = null; }

    static construct {
        install_action("export-certificate", null, (Gtk.WidgetActionActivateFunc) action_export_certificate);
        install_action("request-certificate", null, (Gtk.WidgetActionActivateFunc) action_request_certificate);
        install_action("delete-certificate", null, (Gtk.WidgetActionActivateFunc) action_delete_certificate);
    }

    construct {
        bind_property("title", this.switcher_title, "title", BindingFlags.SYNC_CREATE);

        if (this.certificate != null) {
            var cert_widget = new Pkcs11.CertificateWidget(this.certificate);
            this.stack.add_titled(cert_widget,
                                  "certificate-page",
                                  _("Certificate"));

            this.title = this.certificate.description;
        }

        if (this.private_key != null) {
            var key_widget = new Pkcs11.PrivateKeyWidget(this.private_key);
            this.stack.add_titled(key_widget,
                                  "private-key-page",
                                  _("Private key"));

            if (this.certificate == null)
                this.title = this.private_key.description;
        }
    }

    public CertificateDialog.for_certificate(Pkcs11.Certificate certificate,
                                             Gtk.Window? window = null) {
        GLib.Object(certificate: certificate,
                    private_key: certificate.partner,
                    transient_for: window);

        // XXX update on notify? necessary?
        action_set_enabled("export-certificate", this.certificate.exportable);
        action_set_enabled("delete-certificate", this.certificate.deletable);
    }

    public CertificateDialog.for_private_key(Pkcs11.PrivateKey key,
                                             Gtk.Window? window = null) {
        GLib.Object(private_key: key,
                    certificate: key.partner,
                    transient_for: window);
        //XXX actions
    }

    private void action_export_certificate(string action_name, Variant? param) {
        export_certificate_async.begin();
    }

    private async void export_certificate_async() {
        var export_op = this.certificate.create_export_operation();

        try {
            var prompted = yield export_op.prompt_for_file(this, null);
            if (!prompted) {
                debug("no file picked by user");
                return;
            }

            yield export_op.execute(null);
        } catch (GLib.IOError.CANCELLED e) {
            debug("Exporting of certificate cancelled by user");
        } catch (GLib.Error e) {
            Util.show_error(this, _("Couldn’t export certificate"), e.message);
        }
    }

    private void action_delete_certificate(string action_name, Variant? param) {
        DeleteOperation delete_op = null;
        if (this.private_key != null)
            delete_op = new Pkcs11.DeleteOperation.for_private_key(this.private_key);
        else
            delete_op = new Pkcs11.DeleteOperation.for_certificate(this.certificate);

        delete_op.execute_interactively.begin(this, null, (obj, res) => {
            try {
                delete_op.execute_interactively.end(res);
            } catch (GLib.IOError.CANCELLED e) {
                debug("Delete cancelled by user");
            } catch (GLib.Error e) {
                if (this.private_key == null)
                    Util.show_error(this,
                                    _("Couldn’t delete private key"),
                                    e.message);
                else
                    Util.show_error(this,
                                    _("Couldn’t delete certificate"),
                                    e.message);
            }
        });
    }

    private void action_request_certificate (string action_name, Variant? param) {
        //XXX
        // var req_dialog = new Pkcs11.Request(this, this._request_key);
        // req_dialog.response.connect((resp) => {
        //     req_dialog.destroy();
        // });
        // req_dialog.present();
    }
}
