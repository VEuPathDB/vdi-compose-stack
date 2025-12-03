ENV_FILE := ${PWD}/.env
OPTIONS :=
COMMAND := --help
COMPOSE_FILES :=
SERVICES :=

KIND := $(shell [[ $PWD =~ remote ]] && echo "remote" || echo "local")

ifeq ($(KIND),remote)
	SITE_BUILD := $(shell grep -h SITE_BUILD $(ENV_FILE) .env ../../env/example.partial-local.env 2>/dev/null | head -n1 | cut -d'=' -f2)
else
	SITE_BUILD := $(shell grep -h SITE_BUILD $(ENV_FILE) .env ../../env/example.full-local.env 2>/dev/null | head -n1 | cut -d'=' -f2)
endif

MAKEFLAGS += --no-print-directory
.ONESHELL:

define PROJECT_REPOS_SANS_BIOM
vdi-service
vdi-plugin-bigwig
vdi-plugin-example
vdi-plugin-genelist
vdi-plugin-noop
vdi-plugin-rnaseq
vdi-plugin-wrangler
vdi-internal-db
endef

define PROJECT_REPOS
$(PROJECT_REPOS_SANS_BIOM)
vdi-plugin-biom
endef

define BUILD_WARNING

################################################################################
#                                                                              #
#                                 \033[91mWARNING\033[39m                                      #
#                                                                              #
#  This process may take a long time if building from scratch (10+ minutes).   #
#  If you only wish to build specific target images, it would be much faster   #
#  to build those separately.                                                  #
#                                                                              #
#  Are you sure you want to proceed?                                           #
#                                                                              #
################################################################################

endef

.PHONY: default
default:
	@awk '{ \
	  if ($$1 == "#") { \
	    $$1=""; \
	    if (ht != "") { \
	      ht=ht "\n"; \
	    } \
	    if ($$2 == "|") { \
	      $$2=" "; \
	    } \
	    ht=ht "    " $$0; \
	  } else if ($$1 == ".PHONY:") { \
	    print "  \033[94m" $$2 "\033[39m\n" ht "\n"; \
	    ht="" \
	  } else {\
	    ht="" \
	  } \
	}' <(grep -B10 '.PHONY' makefile | grep -v '[═║@]\|default\|__' | grep -E '^[.#]|$$' | grep -v '_') | less

.PHONY: prep-stack
prep-stack:
	@echo "preparing stack startup requirements"
	if [ $(KIND) = remote ]; then
		SRC_CONFIG=partial-local-dev-config.yml
		SRC_ENV=example.partial-local.env
		if [ ! -f "docker-compose.ssh.yml" ]; then
			echo -e "!! \033[91mREMEMBER TO CREATE SSH TUNNEL COMPOSE FILE\033[39m"
		fi
	else
		SRC_CONFIG=full-local-dev-config.yml
		SRC_ENV=example.full-local.env
	fi

	if [ ! -f stack-config.yml ]; then
		cp ../../config/$$SRC_CONFIG stack-config.yml
	fi
	if [ ! -f .env ]; then
		cp ../../env/$$SRC_ENV .env
	fi
	if [ ! -f docker-compose.yml ]; then
		cp ../../docker-compose.yml ./
	fi
	if [ ! -f docker-compose.dev.yml ]; then
		cp ../docker-compose.dev.yml ./
	fi

# Pulls down and performs a full build of all the images referenced in the
# docker compose stack definition files.
#
# This will use cached build layers from the host system if available, use the
# OPTIONS make var to change that behavior if desired.
.PHONY: build
build:
	@echo -e "$(BUILD_WARNING)"
	read -p "Continue (y/N) " yn
	case "$$yn" in
		[Yy]*) echo ""; $(MAKE) __the_big_build ;;
		*) exit 0;;
	esac

# Runs docker compose up, expecting a file named `.env` in the project root
# directory by default.
.PHONY: up
up: COMMAND := up
up: OPTIONS += --detach
up: __run_prereqs compose

# Runs docker compose down.
#
# Does not prune volumes or networks by default.
.PHONY: down
down: COMMAND := down
down: compose

# Runs docker compose start.
.PHONY: start
start: COMMAND := start
start: OPTIONS += --detach
start: __run_prereqs compose

# Runs docker compose stop.
.PHONY: stop
stop: COMMAND := stop
stop: compose

# Runs docker compose restart.
.PHONY: restart
restart: COMMAND := restart
restart: OPTIONS += --detach
restart: __run_prereqs compose

# Runs "docker compose logs" printing logs for the full stack.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: logs
logs: COMMAND := logs
logs: OPTIONS += -f
logs: compose

# Runs "docker compose logs" printing logs for the full stack.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log
log: logs

# Runs docker compose pull.
.PHONY: pull
pull: COMMAND := pull
pull: compose

# Runs an arbitrary compose command provided by the COMMAND make var.
.PHONY: compose
compose: COMPOSE_FILES := $(addprefix -f ,docker-compose.yml docker-compose.dev.yml $(COMPOSE_FILES))
compose: __test_env_file
	@if [ -z "$(SERVICES)" ] && [ "$(COMMAND)" = "logs" ]; then
		SERVICES="$(strip $(subst internal,cache,$(subst vdi-,,$(PROJECT_REPOS))))"
	else
		SERVICES="$(SERVICES)"
	fi

	if [ -f docker-compose.db.yml ]; then
		COMPOSE_FILES="$(COMPOSE_FILES) -f docker-compose.db.yml"
	else
		COMPOSE_FILES="$(COMPOSE_FILES)"
	fi

	if [ -f docker-compose.ssh.yml ]; then
		COMPOSE_FILES="$(COMPOSE_FILES) -f docker-compose.ssh.yml"
	else
		COMPOSE_FILES="$(COMPOSE_FILES)"
	fi

	script -qefc "docker compose --env-file \"$(ENV_FILE)\" $$COMPOSE_FILES $(COMMAND) $(OPTIONS) $$SERVICES" /dev/null 2>&1 | grep -v 'variable is not set'

# Runs "docker compose logs plugin-bigwig" printing logs for only the bigwig
# plugin service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-bigwig
log-bigwig: SERVICES := plugin-bigwig
log-bigwig: logs

# Runs "docker compose logs plugin-biom" printing logs for only the biom plugin
# service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-biom
log-biom: SERVICES := plugin-biom
log-biom: logs

# Runs "docker compose logs plugin-example" printing logs for only the example
# plugin service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-example
log-example: SERVICES := plugin-example
log-example: logs

# Runs "docker compose logs plugin-genelist" printing logs for only the genelist
# plugin service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-genelist
log-genelist: SERVICES := plugin-genelist
log-genelist: logs

# Runs "docker compose logs plugin-noop" printing logs for only the noop plugin
# service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-noop
log-noop: SERVICES := plugin-noop
log-noop: logs

# Runs "docker compose logs plugin-rnaseq" printing logs for only the rnaseq
# plugin service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-rnaseq
log-rnaseq: SERVICES := plugin-rnaseq
log-rnaseq: logs

# Runs "docker compose logs plugin-wrangler" printing logs for only the wrangler
# plugin service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-wrangler
log-wrangler: SERVICES := plugin-wrangler
log-wrangler: logs

# Runs "docker compose logs service" printing logs for only the core REST
# service.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-service
log-service: SERVICES := service
log-service: logs

# Runs "docker compose logs kafka" printing logs for only the Kafka server.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-kafka
log-kafka: SERVICES := kafka
log-kafka: logs

# Runs "docker compose logs cache-db" printing logs for only the internal cache
# database server.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-cache-db
log-cache-db: SERVICES := cache-db
log-cache-db: logs

# Runs "docker compose logs cache-db" printing logs for only the local test app
# database server.
#
# Logs may be tailed by providing OPTIONS=-f in the make call.
.PHONY: log-app-db
log-app-db: SERVICES := phony-app-db
log-app-db: logs

.PHONY: __the_big_build_prereqs
__the_big_build_prereqs:
	@if [ ! -r /run/docker.sock ] || [ ! -w /run/docker.sock ]; then
		echo
		echo -e "\033[91mYou do not have the permissions necessary to run docker commands without sudo\033[39m"
		echo
		exit 1
	fi

	if [ -z "${GITHUB_USERNAME}" ] || [ -z "${GITHUB_TOKEN}" ]; then
		echo
		echo -e "\033[91mYou do not have both \$$GITHUB_USERNAME and \$$GITHUB_TOKEN in your shell environment\033[39m"
		echo
		exit 1
	fi

.PHONY: __the_big_build_step_1
__the_big_build_step_1: __the_big_build_prereqs
	@rm -rf .vdi-repos
	mkdir .vdi-repos
	cd .vdi-repos
	while read -r project; do
		echo Cloning $$project
		git clone -q --depth=1 https://github.com/VEuPathDB/$$project.git
	done <<< "$(PROJECT_REPOS)"

.PHONY: __the_big_build_step_2
__the_big_build_step_2: COMMAND := build
__the_big_build_step_2: ENV_FILE := env/example.local.env
__the_big_build_step_2: SERVICES := $(shell echo "$(PROJECT_REPOS_SANS_BIOM)" | tr -d '\011\015' | sed 's/vdi-//g' | sed 's/internal-db/cache-db/')
__the_big_build_step_2: OPTIONS += --build-arg GH_USERNAME=${GITHUB_USERNAME}
__the_big_build_step_2: OPTIONS += --build-arg GH_TOKEN=${GITHUB_TOKEN}
__the_big_build_step_2: OPTIONS += --build-arg CONFIG_FILE=config/local-dev-config.yml
__the_big_build_step_2: __the_big_build_step_1 compose

.PHONY: __the_big_build_step_3
__the_big_build_step_3: COMMAND := build
__the_big_build_step_3: ENV_FILE := env/example.local.env
__the_big_build_step_3: SERVICES := plugin-biom
__the_big_build_step_3: OPTIONS += --build-arg GH_USERNAME=${GITHUB_USERNAME}
__the_big_build_step_3: OPTIONS += --build-arg GH_TOKEN=${GITHUB_TOKEN}
__the_big_build_step_3: OPTIONS += --build-arg CONFIG_FILE=config/local-dev-config.yml
__the_big_build_step_3: __the_big_build_step_2 compose

.PHONY: __the_big_build
__the_big_build: __the_big_build_step_3
	@rm -rf .vdi-repos

.PHONY: __test_env_file
__test_env_file:
	@if [ ! -f "$(ENV_FILE)" ]; then
		echo
		echo -e "\033[91mEnv file '$(ENV_FILE) could not be found\033[39m"
		echo
		exit 1
	fi

.PHONY: __run_prereqs
__run_prereqs:
	@if [ -z "$(SITE_BUILD)" ]; then
		echo
		echo -e "\033[91mNo site build number specified!\033[39m"
		echo
		exit 1
	fi
	mkdir -p ${PWD}/tmp/$(SITE_BUILD)
