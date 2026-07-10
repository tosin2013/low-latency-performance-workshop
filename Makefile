# Define the directory containing the utilities
UTILITIES_DIR = utilities
SCRIPTS_DIR = scripts

# Define the commands
LAB_SERVE = $(UTILITIES_DIR)/lab-serve
LAB_STOP = $(UTILITIES_DIR)/lab-stop
LAB_BUILD = $(UTILITIES_DIR)/lab-build
LAB_CLEAN = $(UTILITIES_DIR)/lab-clean

# Default target
all: help

# Target to display help
help:
	@echo "Available targets:"
	@echo ""
	@echo "Onboarding & Setup:"
	@echo "  setup         - Run bootstrap.sh (interactive prod mode)"
	@echo "  setup-dev     - Run bootstrap.sh in dev mode (contributors)"
	@echo "  check         - Run validation checks only (CI-friendly)"
	@echo ""
	@echo "Documentation:"
	@echo "  serve         - Run lab-serve"
	@echo "  stop          - Run lab-stop"
	@echo "  build         - Run lab-build (with document validation)"
	@echo "  clean         - Run lab-clean"
	@echo "  validate      - Validate all documents (YAML, AsciiDoc, Markdown)"
	@echo "  run-all       - Run build and then serve"
	@echo "  stop-clean    - Run stop and then clean"
	@echo "  clean-build   - Run clean and then build"
	@echo ""
	@echo "Workshop Deployment (AgnosticD v2):"
	@echo "  quota         - Check AWS quotas (request increases with QUOTA_REQUEST=1)"
	@echo "  deploy        - Deploy full workshop (Hub + Student clusters)"
	@echo "  deploy-sno    - Deploy a single SNO cluster (prompts for args)"
	@echo "  status        - Check cluster status (prompts for args)"
	@echo "  destroy       - Destroy a cluster (prompts for args)"
	@echo ""

# ─── Onboarding & Setup ──────────────────────────────────────────────────────

# Target to run bootstrap setup (prod mode)
setup:
	@./bootstrap.sh --mode prod

# Target to run bootstrap setup (dev/contributor mode)
setup-dev:
	@./bootstrap.sh --mode dev

# Target to run validation checks only (CI-friendly)
check:
	@./bootstrap.sh --non-interactive --check-only

# ─── Workshop Deployment ─────────────────────────────────────────────────────

# Check AWS quotas and optionally request increases
quota:
	@if [ "$(QUOTA_REQUEST)" = "1" ]; then \
		$(SCRIPTS_DIR)/check-quotas.sh --request; \
	else \
		$(SCRIPTS_DIR)/check-quotas.sh; \
	fi

# Deploy full workshop using the automated script
deploy:
	@$(SCRIPTS_DIR)/deploy-workshop.sh

# Deploy a single SNO cluster
deploy-sno:
	@if [ -z "$(STUDENT)" ] || [ -z "$(ACCOUNT)" ]; then \
		echo "Usage: make deploy-sno STUDENT=student1 ACCOUNT=sandbox1234"; \
		exit 1; \
	fi
	@$(SCRIPTS_DIR)/deploy-sno.sh $(STUDENT) $(ACCOUNT)

# Check cluster status
status:
	@if [ -z "$(STUDENT)" ] || [ -z "$(ACCOUNT)" ]; then \
		echo "Usage: make status STUDENT=student1 ACCOUNT=sandbox1234"; \
		exit 1; \
	fi
	@$(SCRIPTS_DIR)/status-sno.sh $(STUDENT) $(ACCOUNT)

# Destroy a cluster
destroy:
	@if [ -z "$(STUDENT)" ] || [ -z "$(ACCOUNT)" ]; then \
		echo "Usage: make destroy STUDENT=student1 ACCOUNT=sandbox1234"; \
		exit 1; \
	fi
	@$(SCRIPTS_DIR)/destroy-sno.sh $(STUDENT) $(ACCOUNT)

# ─── Documentation ───────────────────────────────────────────────────────────

# Target to run lab-serve
serve:
	@echo "Running lab-serve..."
	@$(LAB_SERVE)

# Target to run lab-stop
stop:
	@echo "Running lab-stop..."
	@$(LAB_STOP)

# Target to run lab-build
build:
	@echo "Running lab-build..."
	@$(LAB_BUILD)

# Target to run lab-clean
clean:
	@echo "Running lab-clean..."
	@$(LAB_CLEAN)

# Target to validate all documents
validate:
	@echo "Validating all documents..."
	@./scripts/validate-documents.sh

# Target to run all commands in sequence
run-all: build serve

# Target to stop and clean
stop-clean: stop clean

# Target to clean and build
clean-build: clean build

# Phony targets
.PHONY: all help setup setup-dev check quota deploy deploy-sno status destroy serve stop build clean validate run-all stop-clean clean-build
