TOP_DIR = ../..
TOOLS_DIR = $(TOP_DIR)/tools
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
-include $(TOOLS_DIR)/Makefile.common

SERVICE_NAME = metadata
SERVICE_PORT = 7446
SERVICE_URL = http://localhost
SERVICE_DIR = $(TARGET)/services/$(SERVICE_NAME)

TPAGE_CGI_ARGS = --define perl_path=$(PERL_PATH) --define perl_lib=$(SERVICE_DIR)/api
TPAGE_LIB_ARGS = --define target=$(TARGET) \
		 --define metadata_name=$(SERVICE_NAME) \
		 --define api_dir=$(SERVICE_DIR)/api
TPAGE := $(shell which tpage)

### Default make target
default: build-scripts

build-scripts:
	-mkdir scripts
	@echo "auto-generating metadata scripts"
	generate_commandline -template $(TOP_DIR)/template/communities.template -config config/commandline.conf -outdir scripts
	@echo "done building command line scripts"
