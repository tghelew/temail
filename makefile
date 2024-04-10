DEPLOY = deploy.sh
PARAMS ?= C # C: controller M: mail
TARGETS = terminal pf

# list of dependencies for targets
depends = $(shell find $(1) -type f -iname '*.sh' -or -iname '*.tmux' -or -iname '*.conf')
d-terminal = $(call depends, terminal)
d-pf = $(call depends, pf)

################################################################################

all: $(TARGETS)

terminal: $(d-terminal)
	@echo "deploying terminal"
	@./$@/$(DEPLOY)
	@touch terminal

pf: $(d-pf)
	@echo "deploying pf"
	@./$@/$(DEPLOY) "$(PARAMS)"
	@touch pf

.PHONY: all $(TARGETS)
