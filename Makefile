MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))

DOCKER_HOST_SOCKET ?= /var/run/docker.sock
DOCKER_CONTAINER_SOCKET ?= $(DOCKER_HOST_SOCKET)

IMAGE_NAME ?= productization-3scale-eguzki
CONTAINER_NAME ?= $(shell echo $(IMAGE_NAME) | sed -E -e 's/\//-/g')-container

nameservers = $(shell awk 'BEGIN{ORS=" "} $$1=="nameserver" {print $$2}' $(1))

RESOLVER ?= $(call nameservers,/etc/resolv.conf)

default: info

.PHONY: info
info:
	@echo "Variables you should care about:\n\n"\
		"RHEL_SUB_USER           = $(RHEL_SUB_USER)\n"\
		"IMAGE_NAME              = $(IMAGE_NAME)\n" \
		"CONTAINER_NAME          = $(CONTAINER_NAME)\n"

.PHONY: build
build:
	docker history -q $(IMAGE_NAME) 2> /dev/null >&2 || \
		$(MAKE) build-image

.PHONY: build-image
build-image: info
	# Make sure you have access to the Red Hat VPN while building
	docker build -t $(IMAGE_NAME) \
		--build-arg RHEL_SUB_USER=$(RHEL_SUB_USER) \
		--build-arg RHEL_SUB_PASSWD="$(RHEL_SUB_PASSWD)" \
		$(PROJECT_PATH)

.PHONY: container
container:
	- docker create -it -h $(IMAGE_NAME) --name $(CONTAINER_NAME) \
		$(addprefix --dns , $(RESOLVER)) \
		--privileged \
		-v $(DOCKER_HOST_SOCKET):$(DOCKER_CONTAINER_SOCKET) \
		$(IMAGE_NAME)

.PHONY: run
run: container
	- docker start $(CONTAINER_NAME) > /dev/null
	docker exec -it $(CONTAINER_NAME) /bin/bash

# Use this target to have your SSH key copied over to the container
.PHONY: add-ssh-key
add-ssh-key: export KEY_PATH?=$(HOME)/.ssh/id_rsa
add-ssh-key: export KEYPUB_PATH?=$(KEY_PATH).pub
add-ssh-key: container
	@echo "*** Using KEY_PATH=$(KEY_PATH) and KEYPUB_PATH=$(KEYPUB_PATH)..."
	docker cp $(KEY_PATH) $(CONTAINER_NAME):/root/.ssh/id_rsa
	docker cp $(KEYPUB_PATH) $(CONTAINER_NAME):/root/.ssh/id_rsa.pub

.PHONY: clean-container
clean-container:
	- docker rm --volumes --force $(CONTAINER_NAME) 2> /dev/null

.PHONY: clean-image
clean-image: clean-container
	docker rmi $(IMAGE_NAME)

.PHONY: clean
clean: clean-image
