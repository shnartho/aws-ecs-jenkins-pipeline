ifeq ($(OS),Windows_NT)
SHELL := C:/Progra~1/Git/usr/bin/sh.exe
GREP := C:/Progra~1/Git/usr/bin/grep.exe
WC := C:/Progra~1/Git/usr/bin/wc.exe
else
SHELL := /bin/sh
GREP := grep
WC := wc
endif

PYTHON ?= python
AWS_PROFILE ?= gold-restaurant
AWS_REGION ?= eu-central-1
EXPECTED_AWS_ACCOUNT_ID ?=

-include Makefile.local

export AWS_PROFILE
export AWS_REGION
export EXPECTED_AWS_ACCOUNT_ID

.PHONY: help verify validate guard-account terraform-init guard-backend terraform-check scripts-check flaws

help:
	$(info make verify          Verify the live AWS deployment)
	$(info make validate        Run local repository validation)
	$(info make terraform-init  Initialize the workload Terraform backend)
	$(info make terraform-check Format-check and validate both Terraform roots)
	$(info make scripts-check   Compile Python and syntax-check Bash)
	$(info make flaws           Confirm exactly three protected FLAW markers)
	@$(SHELL) -c true

verify: guard-account
	$(PYTHON) scripts/verify_deployment.py \
		--profile "$(AWS_PROFILE)" \
		--region "$(AWS_REGION)" \
		--expected-account "$(EXPECTED_AWS_ACCOUNT_ID)"

validate: terraform-check scripts-check flaws

guard-account:
	$(if $(strip $(EXPECTED_AWS_ACCOUNT_ID)),,$(error Set EXPECTED_AWS_ACCOUNT_ID in Makefile.local))

terraform-init: guard-backend
	terraform -chdir=terraform/envs/eu-central-1 init -backend-config=backend.hcl

guard-backend:
	$(if $(wildcard terraform/envs/eu-central-1/backend.hcl),,$(error Create terraform/envs/eu-central-1/backend.hcl from backend.hcl.example))

terraform-check:
	terraform -chdir=terraform fmt -recursive -check
	terraform -chdir=terraform/envs/eu-central-1 validate
	terraform -chdir=terraform/bootstrap validate

scripts-check:
	$(PYTHON) -m py_compile scripts/render_task_def.py scripts/verify_deployment.py
	$(SHELL) -n scripts/verify_health.sh

flaws:
	@count=$$($(GREP) -R "FLAW:" terraform jenkins scripts | $(WC) -l); \
		test "$$count" -eq 3 || { echo "Expected 3 FLAW markers, found $$count"; exit 1; }; \
		echo 'Confirmed exactly 3 protected FLAW markers'
