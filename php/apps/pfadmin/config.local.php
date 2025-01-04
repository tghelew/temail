<?php
/**
 * Postfix Admin
 *
 * LICENSE
 * This source file is subject to the GPL license that is bundled with
 * this package in the file LICENSE.TXT.
 *
 * Further details on the project are available at http://postfixadmin.sf.net
 *
 * @license GNU GPL v2 or later.
 *
 * File: config.local.php
 * Contains configuration options.
 */


$CONF['configured'] = true;

// In order to setup Postfixadmin, you MUST specify a hashed password here.
// To create the hash, visit setup.php in a browser and type a password into the field,
// on submission it will be echoed out to you as a hashed value.

$CONF['setup_password'] = '$2y$10$mD5lRsxOOhxyKXkIdOcbGOmFaGhcP9wRxT5uRdbmSRYE3ivmqu4jO';

// Language config
// Language files are located in './languages', change as required..
$CONF['default_language'] = 'en';

// Database Config
// mysql = MySQL 3.23 and 4.0, 4.1 or 5
// mysqli = MySQL 4.1+ or MariaDB
// pgsql = PostgreSQL
// sqlite = SQLite 3
$CONF['database_type'] = 'pgsql';
$CONF['database_host'] = 'localhost';
$CONF['database_user'] = 'vmail';
$CONF['database_name'] = 'vmail';


// Site Admin
// Define the Site Admin's email address below.
// This will be used to send emails from to
//  * create mailboxes and
//  * Send Email / Broadcast message pages and
//  * In password reset emails.
//
// Leave blank to send email from the logged-in Admin's Email address.
$CONF['admin_email'] = '';

// Define the smtp password for admin_email.
// This will be used to send emails from to create mailboxes and
// from Send Email / Broadcast message pages.
// Leave blank to send emails without authentification
$CONF['admin_smtp_password'] = '';

// Site admin name
// This will be used as signature in notification messages
$CONF['admin_name'] = 'Postmaster';

// Mail Server
// Hostname (FQDN) of your mail server.
// This is used to send email to Postfix in order to create mailboxes.
$CONF['smtp_server'] = 'localhost';
$CONF['smtp_port'] = '25';

// The communication layer used.
//
// 'plain'    Everything in plain text (standard port: 25).
// 'tls'      TLS/SSL from the very beginning (standard port: 465).
// 'starttls' "STARTTLS" in plain text and then TLS/SSL (standard port: 587).
$CONF['smtp_type'] = 'starttls';

// SMTP Client
// Hostname (FQDN) of the server hosting Postfix Admin
// Used in the HELO when sending emails from Postfix Admin
$CONF['smtp_client'] = 'smtp.ghelew.ch';

// Encrypt - how passwords are stored/hashed in the database.
//
// See: https://github.com/postfixadmin/postfixadmin/blob/master/DOCUMENTS/HASHING.md
//
// - PLAIN, CLEAR or CLEARTEXT - plain text variants, may be useful for testing.
//
// - ARGON2ID, ARGON2I, SHA512-CRYPT, SHA256-CRYPT or BLF-CRYPT might be good options.
//
// - other, older variants are :
//   - md5crypt,
//   - md5,
//   - system,
//   - mysql_encrypt - mysql's password()
//   - dovecot:CRYPT-METHOD = use dovecotpw -s 'CRYPT-METHOD'.
//     - Note: dovecot relies on doveadm binary, and suitable permissions on config files - see https://github.com/postfixadmin/postfixadmin/issues/398
//
// - authlib = support for courier-authlib style passwords - also set $CONF['authlib_default_flavor']
//
// - php_crypt:CRYPT-METHOD:DIFFICULTY:PREFIX = use PHP built in crypt()-function. Example: php_crypt:SHA512:50000
// - php_crypt CRYPT-METHOD: Supported values are DES, MD5, BLOWFISH, SHA256, SHA512 (default)
// - php_crypt - DIFFICULTY: Larger value is more secure, but uses more CPU and time for each login.
// - php_crypt - DIFFICULTY: Set this according to your CPU processing power.
// - php_crypt - DIFFICULTY: Supported values are BLOWFISH:4-31, SHA256:1000-999999999, SHA512:1000-999999999
// - php_crypt - DIFFICULTY: leave empty to use default values (BLOWFISH:10, SHA256:5000, SHA512:5000). Example: php_crypt:SHA512
// - php_crypt - PREFIX: hash has specified prefix - example: php_crypt:SHA512::{SHA256-CRYPT}
//
// - sha512.b64 - {SHA512-CRYPT.B64} (base64 encoded sha512 crypt) (no dovecot dependency; should support migration from md5crypt)

$CONF['encrypt'] = 'php_crypt:BLOWFISH'; // SHA512


// Password validation
// New/changed passwords will be validated using all regular expressions in the array.
// If a password doesn't match one of the regular expressions, the corresponding
// error message from $PALANG (see languages/*.lang) will be displayed.
// See http://de3.php.net/manual/en/reference.pcre.pattern.syntax.php for details
// about the regular expression syntax.
// If you need custom error messages, you can add them using $CONF['language_hook'].
// If a $PALANG text contains a %s, you can add its value after the $PALANG key
// (separated with a space).
$CONF['password_validation'] = array(
#    '/regular expression/' => '$PALANG key (optional: + parameter)',
    '/.{5}/'                => 'password_too_short 5',      # minimum length 5 characters
    '/([a-zA-Z].*){3}/'     => 'password_no_characters 3',  # must contain at least 3 characters
    '/([0-9].*){1}/'        => 'password_no_digits 1',      # must contain at least 2 digits
    '/([!\".,*&^%$£)(_+=\-`\'#@~\[\]\\<>\/].*){1,}/' => 'password_no_special 1', # must contain at least 1 special character

    /*  support a 'callable' value which if it returns a non-empty string will be assumed to have failed, non-empty string should be a PALANG key */
    // 'length_check'          => function($password) { if (strlen(trim($password)) < 3) { return 'password_too_short'; } },
);

// Username legal characters
// New/changed usernames will be checked against this regular expression with javascript
// during entry, offending characters not displaying.
// For example:
$CONF['username_legal_chars'] = '^[a-zA-Z0-9-_.]+$';

// Page Size
// Set the number of entries that you would like to see
// in one page.
$CONF['page_size'] = '10';

// Default Aliases
// The default aliases that need to be created for all domains.
// You can specify the target address in two ways:
// a) a full mail address
// b) only a localpart ('postmaster' => 'admin') - the alias target will point to the same domain
$CONF['default_aliases'] = array (
    'abuse' => 'postmaster',
    'hostmaster' => 'postmaster',
    'postmaster' => 'postmaster',
    'webmaster' => 'postmaster'
);

// Mailboxes
// If you want to store the mailboxes per domain set this to 'YES'.
// Examples:
//   YES: /usr/local/virtual/domain.tld/username@domain.tld
//   NO:  /usr/local/virtual/username@domain.tld
$CONF['domain_path'] = 'YES';
// If you don't want to have the domain in your mailbox set this to 'NO'.
// Examples:
//   YES: /usr/local/virtual/domain.tld/username@domain.tld
//   NO:  /usr/local/virtual/domain.tld/username
// Note: If $CONF['domain_path'] is set to NO, this setting will be forced to YES.
$CONF['domain_in_mailbox'] = 'NO';

// Default Domain Values
// Specify your default values below. Quota in MB.
$CONF['aliases'] = '60';
$CONF['mailboxes'] = '60';
$CONF['maxquota'] = '10240';
$CONF['domain_quota_default'] = '8192';

// Quota
// When you want to enforce quota for your mailbox users set this to 'YES'.
$CONF['quota'] = 'YES';
// If you want to enforce domain-level quotas set this to 'YES'.
$CONF['domain_quota'] = 'YES';
// You can either use '1024000' or '1048576'
$CONF['quota_multiplier'] = '1048576';
// fill state threshold (in per cent) for medium level (displayed as orange)
$CONF['quota_level_med_pct'] = 55;
// fill state threshold (in per cent) for high level (displayed as red)
$CONF['quota_level_high_pct'] = 90;

$CONF['transport_default'] = 'virtual';



// Alias Control
// Postfix Admin inserts an alias in the alias table for every mailbox it creates.
// The reason for this is that when you want catch-all and normal mailboxes
// to work you need to have the mailbox replicated in the alias table.
// If you want to take control of these aliases as well set this to 'YES'.

// If you don't want edit alias tab (user mode) set this to 'NO';
$CONF['edit_alias'] = 'YES';

// Alias control for superadmins
$CONF['alias_control'] = 'YES';

// Alias Control for domain admins
$CONF['alias_control_admin'] = 'YES';

// Special Alias Control
// Set to 'NO' if your domain admins shouldn't be able to edit the default aliases
// as defined in $CONF['default_aliases']
$CONF['special_alias_control'] = 'NO';

// Alias Goto Field Limit
// Set the max number of entries that you would like to see
// in one 'goto' field in overview, the rest will be hidden and "[and X more...]" will be added.
// '0' means no limits.
$CONF['alias_goto_limit'] = '0';

// Alias Domains
// Alias domains allow to "mirror" aliases and mailboxes to another domain. This makes
// configuration easier if you need the same set of aliases on multiple domains, but
// also requires postfix to do more database queries.
// Note: If you update from 2.2.x or earlier, you will have to update your postfix configuration.
// Set to 'NO' to disable alias domains.
$CONF['alias_domain'] = 'YES';

// Fetchmail
// If you don't want fetchmail tab set this to 'NO';
$CONF['fetchmail'] = 'NO';

// fetchmail_extra_options allows users to specify any fetchmail options and any MDA
// (it will even accept 'rm -rf /' as MDA!)
// This should be set to NO, except if you *really* trust *all* your users.
$CONF['fetchmail_extra_options'] = 'NO';



// Header
$CONF['show_header_text'] = 'YES';
$CONF['header_text'] = ':: tE-Mail Admin ::';

// Footer
// Below information will be on all pages.
// If you don't want the footer information to appear set this to 'NO'.
$CONF['show_footer_text'] = 'YES';
$CONF['footer_text'] = 'mail.ghelew.ch';
$CONF['footer_link'] = 'https://mail.ghelew.ch';

// MOTD ("Motto of the day")
// You can display a MOTD below the menu on all pages.
// This can be configured seperately for users, domain admins and superadmins
$CONF['motd_user'] = '';
$CONF['motd_admin'] = '';
$CONF['motd_superadmin'] = '';

// Welcome Message
// This message is send to every newly created mailbox.
// Change the text between EOM.
$CONF['welcome_text'] = <<<EOM
Hi,

Welcome to your new account.
EOM;

// When creating mailboxes or aliases, check that the domain-part of the
// address is legal by performing a name server look-up.
$CONF['emailcheck_resolve_domain']='YES';

// When creating mailboxes or aliases, check that the domain-part of the
// address is local and managed by postfixadmin, preventing remote domains
// from being the destination for an alias
$CONF['emailcheck_localaliasonly']='YES';

// Use TOTP for logging into Postfixadmin, can be overridden for listed
// IPs to allow access by software that provide their own checking.
// Exceptions can be of user, domain or global scope.
// This also bundles several menu items in a "security" dropdown.
$CONF['totp'] = 'NO';

// Use revokable application passwords to limit the risk of storing a
// password in another system. These passwords can not access Postfixadmin.
$CONF['app_passwords'] = 'NO';


// OpenDKIM stuff
// Enable the dkim database component
$CONF['dkim'] = 'NO';
// Allow regular admins to add/edit/remove dkim entries
$CONF['dkim_all_admins'] = 'NO';
// End OpenDKIM stuff


// Optional:
// Analyze alias gotos and display a colored block in the first column
// indicating if an alias or mailbox appears to deliver to a non-existent
// account.  Also, display indications, for POP/IMAP mailboxes and
// for custom destinations (such as mailboxes that forward to a UNIX shell
// account or mail that is sent to a MS exchange server, or any other
// domain or subdomain you use)
// See http://www.w3schools.com/html/html_colornames.asp for a list of
// color names available on most browsers

//set to YES to enable this feature
$CONF['show_status']='YES';
//display a guide to what these colors mean
$CONF['show_status_key']='YES';
// 'show_status_text' will be displayed with the background colors
// associated with each status, you can customize it here
$CONF['show_status_text']='&nbsp;&nbsp;';
// show_undeliverable is useful if most accounts are delivered to this
// postfix system.  If many aliases and mailboxes are forwarded
// elsewhere, you will probably want to disable this.
$CONF['show_undeliverable']='YES';
$CONF['show_undeliverable_color']='tomato';
// mails to these domains will never be flagged as undeliverable
$CONF['show_undeliverable_exceptions']=array("unixmail.domain.ext","exchangeserver.domain.ext");
// show mailboxes with expired password; requires password_expiration to be enabled
$CONF['show_expired']='YES';
$CONF['show_expired_color']='orange';
// show vacation enabled mailboxes
$CONF['show_vacation']='YES';
$CONF['show_vacation_color']='turquoise';
// show disabled accounts
$CONF['show_disabled']='YES';
$CONF['show_disabled_color']='grey';
// show POP/IMAP mailboxes
$CONF['show_popimap']='YES';
$CONF['show_popimap_color']='darkgrey';
// you can assign special colors to some domains. To do this,
// - add the domain to show_custom_domains
// - add the corresponding color to show_custom_colors
$CONF['show_custom_domains']=array("subdomain.domain.ext","domain2.ext");
$CONF['show_custom_colors']=array("lightgreen","lightblue");
// If you use a recipient_delimiter in your postfix config, you can also honor it when aliases are checked.
// Example: $CONF['recipient_delimiter'] = "+";
// Set to "" to disable this check.
$CONF['recipient_delimiter'] = "";

// Optional:
// Show used quotas from Dovecot dictionary backend in virtual
// mailbox listing.
// See: DOCUMENTATION/DOVECOT.txt
//      http://wiki.dovecot.org/Quota/Dict
//
$CONF['used_quotas'] = 'YES';

// if you use dovecot >= 1.2, set this to yes.
// Note about dovecot config: table "quota" is for 1.0 & 1.1, table "quota2" is for dovecot 1.2 and newer
$CONF['new_quota_table'] = 'YES';

// Theme Config
$CONF['theme'] = 'default';
// Specify your own favicon, logo and CSS file
$CONF['theme_favicon'] = 'images/favicon.ico';
$CONF['theme_logo'] = 'images/logo-default.png';
$CONF['theme_css'] = 'css/bootstrap.css';
// If you want to customize some styles without editing the $CONF['theme_css'] file,
// you can add a custom CSS file. It will be included after $CONF['theme_css'].
$CONF['theme_custom_css'] = '';


//Account expiration info
//If enabled, mailbox passwords have a password_expiry field set, which is updated each time the password is changed, based on the parent domain's password_expiry (days) value.
//More details in Password_Expiration.md
$CONF['password_expiration'] = 'YES';
