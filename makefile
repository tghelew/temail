DEPLOY = deploy.sh
HOSTNAME != hostname -s
# PARAMS ?=
TARGETS = terminal pf syslog user dns certificate database nginx dovecot spamd redis rspamd smtpd relayd php sogo backup
CONTROLLER = terminal pf user dns certificate database nginx redis smtpd relayd php rspamd sogo syslog backup
MAIL = terminal pf  user dns database dovecot spamd redis rspamd smtpd syslog backup

# C: controller M: mail
.ifndef PARAMS
. if $(HOSTNAME:U:C/[^ABC]+//g) == "A"
    PARAMS = C
. elif $(HOSTNAME:U:C/[^ABC]+//g) == "B" || $(HOSTNAME:U:C/[^ABC]+//g) == "C"
    PARAMS = M
. else
    PARAMS = X
. endif
.endif

# list of dependencies for targets
# FIXME: don't know how to handle those dependencies properly
# depends != find ./$(.TARGETS)  -type f -iname '*.sh' -or -iname '*.tmux' -or -iname '*.conf' -or -iname '*.key'

################################################################################

all: $(TARGETS)
controller: $(CONTROLLER)
mail: $(MAIL)

$(TARGETS):
	@echo "deploying $@"
	@./$@/$(DEPLOY) "$(PARAMS)"

.PHONY: all controller mail clean $(TARGETS)
