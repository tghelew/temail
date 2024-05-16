# Controller worker setup
# Please don't modify this file as your changes might be overwritten with
# the next update.
#
# You can modify 'local.d/worker-controller.inc' to add and merge
# parameters defined inside this section
#
# You can modify 'override.d/worker-controller.inc' to strictly override all
# parameters defined inside this section
#
# See https://rspamd.com/doc/faq.html#what-are-the-locald-and-overrided-directories
# for details
# Module documentation: https://rspamd.com/doc/workers/controller.html

count = 1;
secure_ip = [
                "127.0.0.1"
               ,"::1"
               ,"93.177.66.222"
               ,"2a03:4000:38:e::0"
               ,"46.23.94.97"
               ,"2a03:6000:6f67:622::97"
               ,"46.23.93.235"
               ,"2a03:6000:6f67:622::235"
            ];
static_dir = "${WWWDIR}";
bind_socket = "*:11334"
password = "$2$cugy7qu1qarybugdd44md9yrtseop9ie$nzkare1t8h7gx8m9fh6fde9yasdrdhhtda4yfwkhdw41oqcjid1b";
