#
# For more information on some of the magic targets, variables and flags used, see:
#  - [1] https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
#  - [2] https://www.gnu.org/software/make/manual/html_node/Secondary-Expansion.html
#  - [3] https://www.gnu.org/software/make/manual/html_node/Suffix-Rules.html
#  - [4] https://www.gnu.org/software/make/manual/html_node/Options-Summary.html
#  - [5] https://www.gnu.org/software/make/manual/html_node/Special-Variables.html
#  - [6] https://www.gnu.org/software/make/manual/html_node/Choosing-the-Shell.html
#

# Ensure (intermediate) targets are deleted when an error occurred executing a recipe, see [1]
.DELETE_ON_ERROR:

# Enable a second expansion of the prerequisites, see [2]
.SECONDEXPANSION:

# Disable built-in implicit rules and variables, see [3, 4]
.SUFFIXES:
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

# Disable printing of directory changes, see [4]
MAKEFLAGS += --no-print-directory

# Warn about undefined variables -- useful during development of makefiles, see [4]
MAKEFLAGS += --warn-undefined-variables

# Show an auto-generated help if no target is provided, see [5]
.DEFAULT_GOAL := help

# Default shell, see [6]
SHELL := /bin/bash

help:
	@echo
	@printf "%-20s %s\n" Target Description
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo

#
# PROJECT TARGETS
#
# To learn more about automatic variables that can be used in target recipes, see:
#  https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html
#

PROJECT := phpbin

# Environment variable(s) for Symfony
export APP_ENV ?= dev
export RELEASE ?= $(shell git rev-parse HEAD)

# Environment variable(s) for Docker Compose
export COMPOSE_FILE ?= docker-compose.yml
export COMPOSE_PROJECT_NAME ?= phpbin

# Docker permissions
export DOCKER_UID ?= $(shell id -u)
export DOCKER_GID ?= $(shell id -g)
export DOCKER_USER ?= $(DOCKER_UID):$(DOCKER_GID)

#
# Traefik
#

.PHONY: traefik-network
traefik-network:
	@docker network ls | grep traefik &>/dev/null || docker network create traefik &>/dev/null

.PHONY: traefik
traefik: traefik-network
	@docker inspect -f {{.State.Running}} traefik &>/dev/null || docker run \
		--restart unless-stopped \
		--name traefik \
		--network traefik \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--publish 80:80 \
		--expose 80 \
		--expose 8080 \
		--health-cmd 'nc -z localhost 80' \
		--health-interval 5s \
		--label traefik.enable=true \
		--label 'traefik.http.routers.api.rule=Host(`traefik.localhost`)' \
		--label traefik.http.routers.api.service=api@internal \
		--detach \
		traefik:2.0 \
			--entrypoints.web.address=:80 \
			--api \
			--accesslog \
			--providers.docker=true \
			--providers.docker.network=traefik \
			--providers.docker.exposedbydefault=false

.PHONY: traefik-cleanup
traefik-cleanup:
	@docker stop traefik &>/dev/null
	@docker rm traefik &>/dev/null
	@-docker network rm traefik &>/dev/null

.PHONY: traefik-restart
traefik-restart: ## restart traefik
traefik-restart: traefik-cleanup traefik

.PHONY: build
build: ## build containers
	docker-compose --project-name $(PROJECT) build

.PHONY: fg
fg: traefik
fg: ## launch the docker-compose setup (foreground)
	docker-compose --project-name $(PROJECT) up --remove-orphans

.PHONY: up
up: traefik
up: ## launch the docker-compose setup (background)
	docker-compose --project-name $(PROJECT) up --remove-orphans --detach

.PHONY: down
down: ## terminate the docker-compose setup
	-docker-compose --project-name $(PROJECT) down --remove-orphans

.PHONY: logs
logs: ## show logs
	docker-compose --project-name $(PROJECT) logs

.PHONY: tail
tail: ## tail logs
	docker-compose --project-name $(PROJECT) logs -f

.PHONY: shell
shell: ## spawn a shell inside a php-fpm container
	docker-compose --project-name $(PROJECT) run --rm -e APP_ENV --user $(DOCKER_USER) --no-deps composer sh

.PHONY: install
install: ## install dependencies (composer)
install: vendor/composer/installed.json

.PHONY: update
update: ## update dependencies (composer)
	docker-compose --project-name $(PROJECT) run --rm -e APP_ENV --user $(DOCKER_USER) --no-deps composer \
		composer update --no-interaction --no-progress --no-suggest --prefer-dist

.PHONY: test
test: export APP_ENV := test
test: ## run phpunit test suite
	docker-compose --project-name $(PROJECT) run --rm -e APP_ENV --user $(DOCKER_USER) --no-deps fpm \
		bin/console cache:warmup
	docker-compose --project-name $(PROJECT) run --rm -e APP_ENV --user $(DOCKER_USER) --no-deps fpm \
		phpdbg -qrr vendor/bin/phpunit --colors=always --stderr --coverage-text --coverage-clover clover.xml

#
# PATH BASED TARGETS
#

docker/nginx/Dockerfile: $(shell find public -type f)
	docker-compose --project-name $(PROJECT) build nginx
	@touch $@

docker/%/.build: $$(shell find $$(@D) -type f -not -name .build)
	docker-compose --project-name $(PROJECT) build $*
	@touch $@

vendor/composer/installed.json: composer.json composer.lock var/cache var/log $(CONTAINERS)
	docker-compose --project-name $(PROJECT) run --rm -e APP_ENV --user $(DOCKER_USER) --no-deps composer \
		composer install --no-interaction --no-progress --no-suggest --prefer-dist
	@touch $@
