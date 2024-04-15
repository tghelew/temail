DEPLOY = deploy.sh
# C: controller M: mail
PARAMS ?= C
TARGETS = terminal pf dns httpd certificate
CONTROLLER = terminal pf dns certificate
MAIL = terminal pf dns httpd certificate

# list of dependencies for targets
depends = $(shell find $(1) -type f -iname '*.sh' -or -iname '*.tmux' -or -iname '*.conf')

################################################################################

all: $(TARGETS)
controller: $(CONTROLLER)
mail: $(MAIL)

$(TARGETS): $(call depends, $@)
	@echo "deploying $@"
	@./$@/$(DEPLOY) "$(PARAMS)"

clean:
	@rm -f $(TARGETS) >/dev/null 2>&1

.PHONY: all controller mail clean $(TARGETS)
