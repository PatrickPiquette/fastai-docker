# Copyright (c) 2017 ElementAI. All rights reserved.
#
# Get usage notes at github.com/ElementAI/eai-deployzor

# Parameters to configure behavior before inclusion:
#
# DEPLOYZOR_PROJECT: (MANDATORY)
#   Used as a namespace in the Docker image name.

$(if $(DEPLOYZOR_PROJECT),,$(error DEPLOYZOR_PROJECT should be set before including $(lastword $(MAKEFILE_LIST))))
#
# DEPLOYZOR_BASE_PATH:
#   Path from where the components files will be searched from. (default: empty, thus current directory)
#
# DEPLOYZOR_USE_COMPONENT_PREFIX:
#   Should be set to "1" if more than one component are to be built and maybe deployed
#   from the same repo. If set, the component Dockerfile and k8s-deploy.template will
#   be found in the $(COMPONENT)/ subdirectory under $(DEPLOYZOR_COMPONENTS_ROOT). If not,
#   both the Dockerfile and k8s-deploy.template will be found in the $(DEPLOYZOR_COMPONENTS_ROOT)
#   directory. (default: unset, thus false)

COMPONENT_PREFIX_DIR=$(if $(DEPLOYZOR_BASE_PATH),$(DEPLOYZOR_BASE_PATH)/)$(if $(findstring 1,$(DEPLOYZOR_USE_COMPONENT_PREFIX)),%/)

# Version synthesis
#
_VERSION ?= $(shell \
	if [ -z "`git status --porcelain`" ]; then \
	    git rev-parse --short HEAD; \
	else \
	    echo `whoami`-`git rev-parse --abbrev-ref HEAD`-`git rev-parse --short HEAD`-`date +%Y%m%d%H%M%S`; \
	fi)
VERSION_SPECIFIED:=$(if $(VERSION),true,false)
VERSION:=$(if $(VERSION),$(VERSION),$(_VERSION))

# Image naming and building
#
DEPLOYZOR_DOCKER_REGISTRY?=images.borgy.elementai.lan
COMPONENT?=
DOCKER_IMAGE_NAME?=$(DEPLOYZOR_DOCKER_REGISTRY)/$(DEPLOYZOR_PROJECT)/$(COMPONENT)
DOCKER_FULL_IMAGE_NAME?=$(DEPLOYZOR_DOCKER_REGISTRY)/$(DEPLOYZOR_PROJECT)/$(COMPONENT):$(VERSION)
_FORCE_BUILD:=$(if $(findstring 1,$(FORCE_BUILD)),true,false)

# This makes sure that the required Dockerfile exists
#
$(COMPONENT_PREFIX_DIR)Dockerfile:
	@echo ""; echo "     " Expected \"$@\" is not found, can not build image.; echo ""; exit 1

# Generic docker build target
# `make image.build.foo` builds a docker based on the foo/Dockerfile file.
#
image.build.%: COMPONENT=$*
image.build.%: $(COMPONENT_PREFIX_DIR)Dockerfile $(if $(findstring 1,$(DEPLOYZOR_ENABLE_BUILD_DEPENDENCY)),build.%)
	docker build --build-arg version=$(VERSION) -f $< -t $(DOCKER_FULL_IMAGE_NAME) $(if $(findstring 1,$(DEPLOYZOR_GLOBAL_DOCKER_CONTEXT)),.,$(<D))

image.run.%: COMPONENT=$*
image.run.%: image.build.%
	docker run --rm $(DOCKER_FULL_IMAGE_NAME) $(CMD)

image.delete.%: COMPONENT=$*
image.delete.%:
	docker rmi $(DOCKER_FULL_IMAGE_NAME)

image.volatile_run.%: COMPONENT=$*
image.volatile_run.%:
	rc=0; \
	  make image.run.$* VERSION=$(VERSION) \
	    CMD='$(CMD)' || rc=$$?; \
	  make image.delete.$* VERSION=$(VERSION)>/dev/null; exit $$rc;

image.publish.%: COMPONENT=$*
image.publish.%:
	@echo Checking for $(DOCKER_FULL_IMAGE_NAME) in registry;\
	set -e; \
	if ($(_FORCE_BUILD) || ! curl -k -f --head https://$(DEPLOYZOR_DOCKER_REGISTRY)/v2/$(DEPLOYZOR_PROJECT)/$(COMPONENT)/manifests/$(VERSION) 2>/dev/null >/dev/null); \
	then \
	  if ($(_FORCE_BUILD) || ! docker inspect $(DOCKER_FULL_IMAGE_NAME) > /dev/null 2> /dev/null); then \
	    if ! $(_FORCE_BUILD) && $(VERSION_SPECIFIED); then \
	      echo ; \
	      echo "Version was specified and image does not exist locally. Aborting" >&2; \
	      echo "Use FORCE_BUILD=1 to override." >&2; \
	      echo ; \
	      exit 1; \
	    fi; \
	    echo Image does not exists in registry nor locally. It will be built now; \
	    $(MAKE) -f $(firstword $(MAKEFILE_LIST)) image.build.$* VERSION=$(VERSION); \
	  else \
	    echo Image exists locally but not in the registry. Only need to push it; \
	  fi; \
	  docker push $(DOCKER_FULL_IMAGE_NAME); \
	else \
	  echo Image found in registry, good to go.; \
	fi

image.latest.%: COMPONENT=$*
image.latest.%: image.publish.%
	docker tag $(DOCKER_FULL_IMAGE_NAME) $(DOCKER_IMAGE_NAME):latest
	docker push $(DOCKER_IMAGE_NAME):latest

.PHONY: image.publish.% image.build.%

# k8s deploy file parameterization

# Make sure tha the k8s-deploy.template file exists
#
$(COMPONENT_PREFIX_DIR)k8s-deploy.template:
	@echo ""; echo "     " Expected \"$@\" is not found, can not deploy image.; echo ""; exit 1

# Replace the docker image name with the one that has been built/published
#
k8s-deploy.%.yml: COMPONENT=$*
k8s-deploy.%.yml: $(COMPONENT_PREFIX_DIR)k8s-deploy.template image.publish.% FORCE
	sed -e 's|DOCKER_IMAGE|$(DOCKER_FULL_IMAGE_NAME)|g' < $< > $@

.PHONY: k8s-deploy.%.yml FORCE
FORCE: ;


