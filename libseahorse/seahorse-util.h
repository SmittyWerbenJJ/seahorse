/*
 * Seahorse
 *
 * Copyright (C) 2003 Jacob Perkins
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
 * along with this program; if not, write to the
 * Free Software Foundation, Inc.,
 * 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __SEAHORSE_UTIL_H__
#define __SEAHORSE_UTIL_H__

#include <gtk/gtk.h>
#include <time.h>
#include <gpgme.h>

#include "seahorse-context.h"

typedef enum {
	SEAHORSE_CRYPT_SUFFIX,
	SEAHORSE_SIG_SUFFIX,
	SEAHORSE_ASC_SUFFIX
} SeahorseSuffix;

typedef enum {
    SEAHORSE_TEXT_TYPE_NONE,
    SEAHORSE_TEXT_TYPE_KEY,
    SEAHORSE_TEXT_TYPE_MESSAGE,
    SEAHORSE_TEXT_TYPE_SIGNED
} SeahorseTextType;

gchar*		seahorse_util_get_date_string		(const time_t		time);

#define SEAHORSE_GPGME_ERROR  (seahorse_util_gpgme_error_domain())
GQuark      seahorse_util_gpgme_error_domain();

void        seahorse_util_gpgme_to_error        (gpgme_error_t gerr, 
                                                 GError** err);

void        seahorse_util_show_error            (GtkWindow          *parent,
                                                 const char*        msg);
                                                 
void        seahorse_util_handle_error          (gpgme_error_t      err,
                                                 const gchar*       desc, ...);

void        seahorse_util_handle_gerror         (GError*            err,
                                                 const char*        desc, ...);
                                                 
gpgme_error_t	seahorse_util_write_data_to_file	(const gchar		*path,
							 gpgme_data_t		data);

gchar*		seahorse_util_write_data_to_text	(gpgme_data_t		data);

gboolean    seahorse_util_print_fd          (int fd, 
                                             const char* data);

gboolean    seahorse_util_printf_fd         (int fd, 
                                             const char* data, ...);

SeahorseTextType  seahorse_util_detect_text (const gchar *text, 
                                             gint len, 
                                             const gchar **start, 
                                             const gchar **end);
                                                                                              
gboolean    seahorse_util_uri_exists        (const gchar* uri);

gchar*      seahorse_util_uri_unique        (const gchar* uri);

gchar*      seahorse_util_uri_replace_ext   (const gchar *uri, 
                                             const gchar *ext);

const gchar* seahorse_util_uri_get_last     (const gchar* uri);

const gchar* seahorse_util_uri_split_last   (gchar* uri);

gchar**     seahorse_util_uris_expand       (const gchar **uris);

gboolean    seahorse_util_uris_package      (const gchar* package, 
                                             const gchar** uris);

gchar*      seahorse_util_uri_choose_save   (GtkFileChooserDialog *chooser);

gboolean	seahorse_util_check_suffix		(const gchar		*path,
							 SeahorseSuffix		suffix);

gchar*		seahorse_util_add_suffix		(gpgme_ctx_t		ctx,
							 const gchar		*path,
							 SeahorseSuffix		suffix);

gchar*		seahorse_util_remove_suffix		(const gchar		*path);

gchar**     seahorse_util_strvec_dup        (const gchar        **vec);

gpgme_key_t* seahorse_util_list_to_keys      (GList *keys);

void        seahorse_util_free_keys         (gpgme_key_t* keys);

/*
 * Functions for allocating keys we find from sources other than 
 * GPGME, like servers for example. 
 * 
 * Yes, we allocate gpgme_key_t structures and use them. The structure 
 * is open, we play by the rules and don't use fields we're asked not 
 * to. Of course we should never pass these structures to GPGME functions
 * like gpgme_key_unref etc....
 */

#define SUKEY_FLAG_REVOKED  0x01
#define SUKEY_FLAG_DISABLED 0x02

gpgme_key_t seahorse_util_key_alloc         ();
void        seahorse_util_key_add_subkey    (gpgme_key_t key,
                                             const char *fpr,
                                             guint flags,
                                             long int timestamp,
                                             long int expires,
                                             unsigned int length,
                                             gpgme_pubkey_algo_t algo);
void        seahorse_util_key_add_uid       (gpgme_key_t key,
                                             const gchar *uid,
                                             guint flags);
gboolean    seahorse_util_key_is_gpgme      (gpgme_key_t key);
void        seahorse_util_key_ref           (gpgme_key_t key);
void        seahorse_util_key_unref         (gpgme_key_t key);

/* For checking GPG error codes */
#define GPG_IS_OK(e)        (gpgme_err_code (e) == GPG_ERR_NO_ERROR)
#define GPG_OK              (gpgme_error (GPG_ERR_NO_ERROR))
#define GPG_E(e)            (gpgme_error (e))

#endif /* __SEAHORSE_UTIL_H__ */
