# Basic rspamd configuration
# Relevant documentation: https://rspamd.com/doc/configuration/options.html

filters = "chartable,dkim,regexp,fuzzy_check";
tempdir = "/tmp/rspamd";

neighbours {
    server1 { host = "@hostname@:11334"; }
}
