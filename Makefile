TOP_DIR = ../..
TOOLS_DIR = $(TOP_DIR)/tools
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
-include $(TOOLS_DIR)/Makefile.common

PERL_PATH = $(DEPLOY_RUNTIME)/bin/perl
SERVICE_NAME = metadata
SERVICE_PORT = 7085
SERVICE_URL = http://localhost
SERVICE_DIR = $(TARGET)/services/$(SERVICE_NAME)
ID_SERVER_URL = http://kbase.us/services/idserver
SHOCK_URL = http://140.221.43.49:80
DEFAULT_TEMPLATE_NODE = 7cae0733-b777-42cb-b305-aa8a8eca3b90

TPAGE_CGI_ARGS = --define perl_path=$(PERL_PATH) --define perl_lib=$(SERVICE_DIR)/api
TPAGE_LIB_ARGS = --define target=$(TARGET) \
		 --define api_dir=$(SERVICE_DIR)/api \
		 --define id_server_url=$(ID_SERVER_URL) \
		 --define shock_url=$(SHOCK_URL) \
		 --define default_template_node=$(DEFAULT_TEMPLATE_NODE)
# Need to add this back in once the service is deployed into production
#		 --define service_name=$(SERVICE_NAME) 
TPAGE := $(shell which tpage)

### Default make target
default: build-scripts

all: deploy

clean:
	-rm -rf support
	-rm -rf scripts
	-rm -rf docs
	-rm -rf lib
	-rm -rf api

uninstall: clean
	-rm -rf $(SERVICE_DIR)

deploy: deploy-cfg | deploy-service deploy-client deploy-docs
	@echo "stoping apache ..."
	service apache2 stop

build-scripts:
	-mkdir -p scripts
	@echo "auto-generating metadata scripts"
	generate_commandline -template $(TOP_DIR)/template/communities.template -config config/commandline.conf -outdir scripts
	@echo "done building command line scripts"

deploy-service: build-service
	-mkdir -p $(SERVICE_DIR)
	cp -vR api $(SERVICE_DIR)/.
	$(TPAGE) --define target=$(TARGET) service/start_service.tt > $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/stop_service
	chmod +x $(SERVICE_DIR)/start_service
	chmod +x $(SERVICE_DIR)/stop_service
	$(TPAGE) --define metadata_dir=$(SERVICE_DIR)/api --define metadata_api_port=$(SERVICE_PORT) config/apache.conf.tt > /etc/apache2/sites-available/default
	@echo "restarting apache ..."
	service nginx stop
	service apache2 restart
	@echo "done executing deploy-service target"

build-service:
	-rm -rf support
	git submodule init support
	git submodule update support
	cd support; git pull origin develop
	-mkdir -p api/resources
	cp support/src/MGRAST/lib/resources/resource.pm api/resources/resource.pm
	cp support/src/MGRAST/lib/resources/validation.pm api/resources/validation.pm
	cp support/src/MGRAST/lib/GoogleAnalytics.pm api/GoogleAnalytics.pm
	$(TPAGE) $(TPAGE_LIB_ARGS) config/Conf.pm.tt > api/Conf.pm
	sed '1d' support/src/MGRAST/cgi/api.cgi | cat config/header.tt - | $(TPAGE) $(TPAGE_CGI_ARGS) > api/api.cgi
	chmod +x api/api.cgi

deploy-client: deploy-scripts | build-libs deploy-libs
	@echo "client tools deployed"

build-libs:
	-mkdir -p lib
	-mkdir -p docs
	api2js -url $(SERVICE_URL):$(SERVICE_PORT)/api.cgi -outfile docs/metadata.json
	definition2typedef -json docs/metadata.json -typedef docs/metadata.typedef -service Metadata
	compile_typespec --impl Metadata --js Metadata --py Metadata docs/metadata.typedef lib
	@echo "done building typespec libs"

build-docs:
	api2html -url $(SERVICE_URL):$(SERVICE_PORT)/api.cgi -site_name Metadata -outfile docs/metadata-api.html
	pod2html --infile=lib/MetadataClient.pm --outfile=docs/Metadata.html --title="Metadata Client"

deploy-docs: build-docs
	mkdir -p $(SERVICE_DIR)/webroot
	cp docs/*.html $(SERVICE_DIR)/webroot/.
	cp docs/*.html $(SERVICE_DIR)/api/.

-include $(TOOLS_DIR)/Makefile.common.rules
