# Basic rspamd configuration
# Relevant documentation: https://rspamd.com/doc/configuration/options.html

filters = "chartable,dkim,regexp,fuzzy_check";
tempdir = "/tmp/rspamd";

neighbours {
   eshub  { host = "https://spam.ghelew.ch:443";
            path = "/eshub/"; }
   eshuc  { host = "https://spam.ghelew.ch:443";
            path = "/eshuc/"; }
}

local_addrs = [192.168.0.0/16
                ,10.0.0.0/8
                ,172.16.0.0/12
                ,fd00::/8
                ,169.254.0.0/16
                ,fe80::/10
                ,"93.177.66.222"
                ,"2a03:4000:38:e::0"
                ,"46.23.94.97"
                ,"2a03:6000:6f67:622::97"
                ,"46.23.93.235"
                ,"2a03:6000:6f67:622::235"
              ];
