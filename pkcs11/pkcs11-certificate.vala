/*
 * Seahorse
 *
 * Copyright (C) 2008 Stefan Walter
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2013 Red Hat, Inc.
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
 */

public class Seahorse.Pkcs11.Certificate : Gck.Object, Gcr.Certificate,
                                           Gck.ObjectCache, Deletable, Exportable, Viewable {
    public Token? place {
        owned get { return (Token?)this._token.get(); }
        set { this._token.set(value); }
    }

    public Flags object_flags {
        get { ensure_flags(); return this._flags; }
    }

    public PrivateKey? partner {
        owned get { return (PrivateKey?)this._private_key.get(); }
        set {
            this._private_key.set(value);
            this._icon = null;
            this.notify_property("partner");
            this.notify_property("icon");
            this.notify_property("description");
        }
    }

    public Gck.Attributes attributes {
        owned get { return this._attributes; }
        set {
            this._attributes = value;
            this.notify_property("attributes");
        }
    }

    public bool deletable {
        get { return (this.place != null) && this.place.is_deletable(this); }
    }

    public bool exportable {
        get { return this._der != null; }
    }

    public GLib.Icon icon {
        owned get {
            if (this._icon != null)
                return this._icon;
            //XXX
            var icon = new GLib.ThemedIcon("application-certificate-symbolic");
            if (this._private_key.get() != null) {
            //     var eicon = new GLib.ThemedIcon (Gcr.ICON_KEY);
            //     var emblem = new GLib.Emblem (eicon);
            //     this._icon = new GLib.EmblemedIcon (icon, emblem);
            } else {
                this._icon = icon;
            }
            return this._icon;
        }
    }

    public string description {
        owned get {
            ensure_flags ();
            if (this._private_key.get() != null)
                return _("Personal certificate and key");
            if ((this._flags & Flags.PERSONAL) == Flags.PERSONAL)
                return _("Personal certificate");
            else
                return _("Certificate");
        }
    }

    public string? label {
        owned get { return get_subject_name(); }
    }

    public string? subject_name {
        owned get { return get_subject_name(); }
    }

    public string? issuer_name {
        owned get { return get_issuer_name(); }
    }

    public GLib.DateTime? expiry_date {
        owned get { return get_expiry_date(); }
    }

    private GLib.WeakRef _token;
    private Gck.Attributes? _attributes;
    private unowned Gck.Attribute? _der;
    private GLib.WeakRef _private_key;
    private GLib.Icon? _icon;
    private Flags _flags;

    private static uint8[] EMPTY = { };

    construct {
        this._flags = (Flags)uint.MAX;
        this._der = null;
        this._private_key = GLib.WeakRef(null);
        this._token = GLib.WeakRef(null);

        this.notify.connect((pspec) => {
            if (pspec.name != "attributes")
                return;
            if (this._attributes != null)
                this._der = this._attributes.find(CKA.VALUE);
            notify_property ("label");
            notify_property ("subject-name");
            notify_property ("issuer-name");
            notify_property ("expiry-date");
        });

        if (this._attributes != null)
            this._der = this._attributes.find(CKA.VALUE);
    }

    public override void dispose() {
        this.partner = null;
        base.dispose();
    }

    public Gtk.Window? create_viewer(Gtk.Window? parent) {
        var viewer = new Pkcs11.CertificateDialog.for_certificate(this, parent);
        viewer.show();
        return viewer;
    }

    public Seahorse.DeleteOperation create_delete_operation() {
        Seahorse.DeleteOperation delete_operation;

        PrivateKey? key = this.partner;
        if (key == null) {
            delete_operation = new Pkcs11.DeleteOperation.for_certificate(this);
        } else {
            delete_operation = key.create_delete_operation();
            //XXX not sure of this one
            // delete_operation.add_certificate(this);
        }

        return delete_operation;
    }

    public ExportOperation create_export_operation() {
        return new Pkcs11.CertificateDerExportOperation(this);
    }

    public void fill(Gck.Attributes attributes) {
        var builder = new Gck.Builder(Gck.BuilderFlags.NONE);

        if (this._attributes != null)
            builder.add_all(this._attributes);
        builder.set_all(attributes);
        this._attributes = builder.end();
        this.notify_property("attributes");
    }

    [CCode (array_length_type = "gsize")]
    public unowned uint8[] get_der_data() {
        if (this._der == null)
            return EMPTY;
        return this._der.get_data();
    }

    private Flags calc_is_personal_and_trusted() {
        ulong category = 0;
        bool is_ca;

        /* If a matching private key, then this is personal*/
        if (this._private_key.get() != null)
            return Flags.PERSONAL | Flags.TRUSTED;

        if (this._attributes != null &&
            this._attributes.find_ulong (CKA.CERTIFICATE_CATEGORY, out category)) {
            if (category == 2)
                return 0;
            else if (category == 1)
                return Flags.PERSONAL;
        }

        if (get_basic_constraints (out is_ca, null))
            return is_ca ? 0 : Flags.PERSONAL;

        return Flags.PERSONAL;
    }

    private void ensure_flags() {
        if (this._flags == uint.MAX)
            this._flags = calc_is_personal_and_trusted ();
    }
}
