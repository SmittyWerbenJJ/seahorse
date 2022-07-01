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

[GtkTemplate (ui = "/org/gnome/Seahorse/pkcs11-certificate-widget.ui")]
public class Seahorse.Pkcs11.CertificateWidget : Adw.PreferencesPage {

    public Gcr.Certificate certificate { get; construct set; }

    [GtkChild] private unowned Gtk.Label name_label;
    [GtkChild] private unowned Gtk.Label issuer_short_label;
    [GtkChild] private unowned Gtk.Label expires_short_label;

    [GtkChild] private unowned Adw.ActionRow subject_cn_row;
    [GtkChild] private unowned Adw.ActionRow subject_ou_row;
    [GtkChild] private unowned Adw.ActionRow subject_o_row;
    [GtkChild] private unowned Adw.ActionRow subject_c_row;

    [GtkChild] private unowned Adw.ActionRow issuer_cn_row;
    [GtkChild] private unowned Adw.ActionRow issuer_ou_row;
    [GtkChild] private unowned Adw.ActionRow issuer_o_row;
    [GtkChild] private unowned Adw.ActionRow issuer_c_row;

    [GtkChild] private unowned Gtk.Label issued_date_label;
    [GtkChild] private unowned Gtk.Label expires_label;

    [GtkChild] private unowned Gtk.Label version_label;
    [GtkChild] private unowned Gtk.Label serial_nr_label;

    [GtkChild] private unowned Adw.ActionRow sha256_fingerprint_row;
    [GtkChild] private unowned Adw.ActionRow sha1_fingerprint_row;
    [GtkChild] private unowned Adw.ActionRow md5_fingerprint_row;

    [GtkChild] private unowned Gtk.Label public_key_algo_label;
    [GtkChild] private unowned Gtk.Label public_key_size_label;
    [GtkChild] private unowned Gtk.Label public_key_label;

    private Pkcs11.PrivateKey _request_key;

    construct {
        fill_in_certificate_details(this.certificate);

        //XXX
        // var partner = this.certificate.partner;
        // if (partner != null) {
        //     add_renderer_for_object(partner);
        //     check_certificate_request_capable(partner);
        // }

        // XXX update on notify? necessary?
        action_set_enabled("export-certificate", Exportable.can_export(this.certificate));
        action_set_enabled("delete-certificate", Deletable.can_delete(this.certificate));
    }

    public CertificateWidget(Gcr.Certificate certificate) {
        GLib.Object(certificate: certificate);
    }

    private void fill_in_certificate_details(Gcr.Certificate cert) {
        // Summary
        set_label_value(this.name_label,
                        cert.get_subject_name(),
                        _("Nameless certificate"));
        this.issuer_short_label.label = _("Issued by: %s").printf(cert.get_issuer_name() ?? _("Unknown"));
        var expiry_date = cert.get_expiry_date();
        if (expiry_date != null)
            this.expires_short_label.label = _("Expires at %s").printf(expiry_date.format("%F"));
        else
            this.expires_short_label.label = _("Never expires");
        //XXX this certificate has expired

        // Subject name
        set_row_value(this.subject_cn_row, cert.get_subject_part("cn"));
        set_row_value(this.subject_ou_row, cert.get_subject_part("ou"));
        set_row_value(this.subject_o_row, cert.get_subject_part("o"));
        set_row_value(this.subject_c_row, cert.get_subject_part("c"));

        // Issuer name
        set_row_value(this.issuer_cn_row, cert.get_issuer_part("cn"));
        set_row_value(this.issuer_ou_row, cert.get_issuer_part("ou"));
        set_row_value(this.issuer_o_row, cert.get_issuer_part("o"));
        set_row_value(this.issuer_c_row, cert.get_issuer_part("c"));

        // Validity
        if (expiry_date != null)
            set_label_value(this.expires_label, expiry_date.format("%F"));
        else
            set_label_value(this.expires_label, _("No expiry date"));
        if (cert.get_issued_date() != null)
            set_label_value(this.issued_date_label, cert.get_issued_date().format("%F"));
        else
            set_label_value(this.issued_date_label, _("No issued date"));

        // XXX issued parameters

        // XXX MISSING VERSION API IN GCR
        set_label_value(this.serial_nr_label, cert.get_serial_number_hex());

        // fingerprints
        var der_data = cert.get_der_data();
        set_row_value(this.sha256_fingerprint_row,
                      Checksum.compute_for_data(ChecksumType.SHA256, der_data));
        set_row_value(this.sha1_fingerprint_row,
                      Checksum.compute_for_data(ChecksumType.SHA1, der_data));
        set_row_value(this.md5_fingerprint_row,
                      Checksum.compute_for_data(ChecksumType.MD5, der_data));

        // XXX public key info
        set_label_value(this.public_key_size_label, "%u bits".printf(cert.get_key_size()));

        // XXX extensions
    }

    //XXX what about hex labels?
    private void set_label_value(Gtk.Label label,
                                 string? value,
                                 string fallback = _("Unknown")) {
        if (value != null && value != "") {
            label.label = value;
            label.remove_css_class("dim-label");
            label.selectable = true;
        } else {
            label.label = fallback;
            label.add_css_class("dim-label");
            label.selectable = false;
        }
    }

    private void set_row_value(Adw.ActionRow row,
                               string? value,
                               string fallback = _("Unknown")) {
        if (value != null && value != "") {
            row.subtitle = value;
            row.remove_css_class("dim-label");
            row.subtitle_selectable = true;
        } else {
            row.subtitle = fallback;
            row.add_css_class("dim-label");
            row.subtitle_selectable = false;
        }
    }
}
