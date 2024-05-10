# Logging configuration
# Relevant documentation: https://rspamd.com/doc/configuration/logging.html

type = syslog
facility = mail
level = "info";

# Enable debug for specific modules (e.g. `debug_modules = ["dkim", "re_cache"];`)
debug_modules = []
