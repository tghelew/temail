DEPLOY = deploy.sh
HOSTNAME != hostname -s
# PARAMS ?=
TARGETS = terminal pf syslog dns certificate database httpd
CONTROLLER = terminal pf syslog dns certificate database httpd
MAIL = terminal pf syslog dns httpd

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

clean:
	@rm -f $(TARGETS_FILE) >/dev/null 2>&1

.PHONY: all controller mail clean $(TARGETS)
