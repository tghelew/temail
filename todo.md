
# TODOs

## High
- [x] Setup makefile
- [x] Setup global kshrc
- [x] Setup prompt
- [x] setup pf
- [x] setup unbound
- [x] Create operator user
- [x] setup function to update crontab
- [x] setup bind & configure he.net
- [x] certificates & sync script
- [x] setup database and php admin
- [x] setup dovecot
- [x] setup spamd
- [x] basic smtp
- [x] setup redis
- [x] setup relayd
- [x] setup sogo
- [ ] Create operational scripts: temailctl -f /etc/tmailctl.conf
  - [ ] Config parser in toml
  - [ ] monitoring agent
  - [ ] monitoring command
- [x] Rewrite httpd for ngnix (due to proxy-pass)
- [x] test failure of eshub or eshuc
- [x] migrate mails
- [ ] SOGo Fix multi-domain support & Preference 
- [ ] Create backup scripts

## Medium
- [x] certs: Certificate manage external certificates (i.e: bought)
- [x] syslog: configure syslog to send logs to controller on mail servers
- [x] dns: migrate domain ghelew.net to secondary dns servers 
- [x] dovecot: Setup script for quota management
- [x] dovecot: Setup script for archived email in specific folder
- [x] pf: create a anchor.conf file to properly restart all anchors
- [x] dovecot: Setup script for junk mail cleanup script
~~- [x] dovecot: Setup master users~~
- [x] Add nvim script



## Low
- [ ] temail-spf-walk: add support for %{i}
