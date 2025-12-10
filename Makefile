# Define the directory containing the utilities
UTILITIES_DIR = utilities
WORKSHOP_SCRIPTS_DIR = workshop-scripts

# Define the commands
LAB_SERVE = $(UTILITIES_DIR)/lab-serve
LAB_STOP = $(UTILITIES_DIR)/lab-stop
LAB_BUILD = $(UTILITIES_DIR)/lab-build
LAB_CLEAN = $(UTILITIES_DIR)/lab-clean

# Workshop provisioning commands
PROVISION_SCRIPT = $(WORKSHOP_SCRIPTS_DIR)/provision-workshop.sh
DESTROY_SCRIPT = $(WORKSHOP_SCRIPTS_DIR)/destroy-workshop.sh
CLEANUP_VPC_SCRIPT = $(WORKSHOP_SCRIPTS_DIR)/cleanup-vpc.sh

# Workshop defaults
USERS ?= 5
START_USER ?= 1
USER_PREFIX ?= user

# Default target
all: help

# Target to display help
help:
	@echo "Available targets:"
	@echo ""
	@echo "Documentation:"
	@echo "  help          - Display this help message"
	@echo "  serve         - Run lab-serve"
	@echo "  stop          - Run lab-stop"
	@echo "  build         - Run lab-build (with document validation)"
	@echo "  clean         - Run lab-clean"
	@echo "  validate      - Validate all documents (YAML, AsciiDoc, Markdown)"
	@echo "  run-all       - Run build and then serve"
	@echo "  stop-clean    - Run stop and then clean"
	@echo "  clean-build   - Run clean and then build"
	@echo ""
	@echo "Workshop Provisioning:"
	@echo "  provision          - Deploy workshop (default: 5 users, sequential)"
	@echo "  provision-single   - Deploy single user (user1 only)"
	@echo "  destroy            - Destroy all workshop resources"
	@echo "  cleanup-vpc        - Advanced: Delete all resources in a VPC"
	@echo "  list-vpcs          - List all VPCs in AWS account"
	@echo ""
	@echo "Workshop Variables (use with provision):"
	@echo "  USERS=N            - Number of users (default: 5)"
	@echo "  START_USER=N       - Starting user number (default: 1)"
	@echo "  USER_PREFIX=name   - Username prefix (default: user)"
	@echo "  VPC_ID=vpc-xxx     - VPC ID for cleanup-vpc target"
	@echo ""
	@echo "Examples:"
	@echo "  make provision                    # Deploy user1-user5"
	@echo "  make provision USERS=10           # Deploy user1-user10"
	@echo "  make provision USERS=10 START_USER=6  # Deploy user6-user10"
	@echo "  make provision-single             # Deploy user1 only"
	@echo "  make provision USER_PREFIX=student    # Deploy student1-student5"
	@echo "  make destroy                      # Destroy all resources"
	@echo "  make list-vpcs                    # Show all VPCs"
	@echo "  make cleanup-vpc VPC_ID=vpc-xxx   # Delete VPC and all resources"

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

# ============================================
# Workshop Provisioning Targets
# ============================================

# Target to provision workshop (sequential, all users)
provision:
	@echo "Provisioning workshop..."
	@echo "  Users: $(USERS)"
	@echo "  Start User: $(START_USER)"
	@echo "  User Prefix: $(USER_PREFIX)"
	@echo ""
	@$(PROVISION_SCRIPT) $(USERS) $(START_USER) $(USER_PREFIX)

# Target to provision single user (user1)
provision-single:
	@echo "Provisioning single user ($(USER_PREFIX)1)..."
	@$(PROVISION_SCRIPT) 1 1 $(USER_PREFIX)

# Target to destroy workshop
destroy:
	@echo "Destroying workshop resources..."
	@$(DESTROY_SCRIPT) $(USERS) $(USER_PREFIX)

# ============================================
# Advanced Cleanup Targets
# ============================================

# Target to list all VPCs
list-vpcs:
	@echo "Listing VPCs in AWS account..."
	@echo ""
	@aws ec2 describe-vpcs \
		--query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`guid`].Value|[0],CidrBlock,State]' \
		--output table 2>/dev/null || echo "Failed to list VPCs. Check AWS credentials."

# Target to cleanup a specific VPC
cleanup-vpc:
ifndef VPC_ID
	@echo "Error: VPC_ID is required"
	@echo ""
	@echo "Usage: make cleanup-vpc VPC_ID=vpc-xxxxxxxxx"
	@echo ""
	@echo "To find VPC IDs, run: make list-vpcs"
	@exit 1
else
	@echo "Cleaning up VPC: $(VPC_ID)"
	@$(CLEANUP_VPC_SCRIPT) $(VPC_ID)
endif

# Target to force cleanup a VPC (no confirmation)
cleanup-vpc-force:
ifndef VPC_ID
	@echo "Error: VPC_ID is required"
	@echo ""
	@echo "Usage: make cleanup-vpc-force VPC_ID=vpc-xxxxxxxxx"
	@exit 1
else
	@echo "Force cleaning up VPC: $(VPC_ID)"
	@$(CLEANUP_VPC_SCRIPT) $(VPC_ID) --force
endif

# Phony targets
.PHONY: all help serve stop build clean validate run-all stop-clean clean-build provision provision-single destroy list-vpcs cleanup-vpc cleanup-vpc-force
