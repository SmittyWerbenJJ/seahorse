/*
 * Seahorse
 *
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
 * Author: Stef Walter <stefw@redhat.com>
 */

public class Seahorse.Pkcs11.DeleteOperation : Seahorse.DeleteOperation {

    public DeleteOperation.for_certificate(Pkcs11.Certificate certificate) {
        add_certificate(certificate);
        // XXX if partner set, use private key instead? not sure
    }

    public DeleteOperation.for_private_key(Pkcs11.PrivateKey key) {
        add_private_key(key);
        // XXX necessary to check for partner?
    }

    public void add_certificate(Pkcs11.Certificate certificate)
            requires(certificate.deletable) {
        this.items.add(certificate);
        //XXX do we need to add partner?
    }

    public void add_private_key(Pkcs11.PrivateKey key)
            requires(key.deletable) {
        this.items.add(key);
        //XXX do we need to add partner?
    }

    public override async bool execute(Cancellable? cancellable) throws GLib.Error {
        debug("Deleting %u PKCS#11 objects", this.items.length);
        foreach (unowned var item in this.items) {
            var object = (Gck.Object) item;

            try {
                yield object.destroy_async(cancellable);

                Token? token;
                object.get("place", out token);
                if (token != null)
                    token.remove_object(object);

            } catch (GLib.Error e) {
                /* Ignore objects that have gone away */
                if (e.domain != Gck.Error.quark() ||
                    e.code != CKR.OBJECT_HANDLE_INVALID)
                    throw e;
            }
        }
        return true;
    }
}
