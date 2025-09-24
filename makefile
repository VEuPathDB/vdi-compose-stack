ENV_FILE := ${PWD}/.env
SERVICES :=
OPTIONS :=
COMMAND := --help
COMPOSE_FILES :=

MAKEFLAGS += --no-print-directory
.ONESHELL:

.PHONY: default
default:
	exit 1

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

.PHONY: build
build:
	@echo -e "$(BUILD_WARNING)"
	read -p "Continue (y/N) " yn
	case "$$yn" in
		[Yy]*) echo ""; $(MAKE) __the_big_build ;;
		*) exit 0;;
	esac

.PHONY: up
up: COMMAND := up
up: compose

.PHONY: down
down: COMMAND := down
down: compose

.PHONY: start
start: COMMAND := start
start: compose

.PHONY: stop
stop: COMMAND := stop
stop: compose

.PHONY: restart
restart: COMMAND := restart
restart: compose

.PHONY: logs
logs: COMMAND := logs
logs: compose

.PHONY: compose
compose: COMPOSE_FILES := $(addprefix -f ,docker-compose.yml docker-compose.dev.yml $(COMPOSE_FILES))
compose: __test_env_file
	docker compose --env-file "$(ENV_FILE)" $(COMPOSE_FILES) $(COMMAND) $(OPTIONS) $(SERVICES)

define PROJECT_REPOS_SANS_BIOM
vdi-service
vdi-plugin-bigwig
vdi-plugin-example
vdi-plugin-genelist
vdi-plugin-isasimple
vdi-plugin-noop
vdi-plugin-rnaseq
vdi-plugin-wrangler
vdi-internal-db
endef

define PROJECT_REPOS
$(PROJECT_REPOS_SANS_BIOM)
vdi-plugin-biom
endef

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