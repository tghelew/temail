require ["vnd.dovecot.pipe", "fileinto", "copy", "imapsieve", "environment", "variables", "imap4flags"];
if environment :matches "imap.mailbox" "Junk" {
  set "mailbox" "${1}";
}

if environment :matches "imap.user" "*" {
  set "username" "${1}";
}

pipe :copy "temail-sa-learn" [ "spam", "${username}" ];

fileinto "Trash";
addflag "\\Seen";
