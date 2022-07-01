/*
 * Seahorse
 *
 * Copyright (C) 2022 Niels De Graef
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

#pragma once

#include <gtk/gtk.h>

#include "pgp/seahorse-pgp-key.h"

#define SEAHORSE_PGP_TYPE_KEY_PROPERTIES (seahorse_pgp_key_properties_get_type ())
G_DECLARE_FINAL_TYPE (SeahorsePgpKeyProperties, seahorse_pgp_key_properties,
                      SEAHORSE_PGP, KEY_PROPERTIES,
                      GtkWindow);

GtkWindow *     seahorse_pgp_key_properties_new    (SeahorsePgpKey *pkey,
                                                    GtkWindow *parent);
