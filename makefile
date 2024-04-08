DEPLOY = deploy.sh
TARGETS = terminal

# list of dependencies for targets
depends = $(shell find $(1) -type f -iname '*.sh' -or -iname '*.tmux' -or -iname '*.conf')
d-terminal = $(call depends, terminal)

################################################################################

all: $(TARGETS)

terminal: $(d-terminal)
	@echo "deploying terminal"
	@./$@/$(DEPLOY)
	@touch terminal

.PHONY: all $(TARGETS)
