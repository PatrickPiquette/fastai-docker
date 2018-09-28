DEPLOYZOR_PROJECT=fastai
DEPLOYZOR_BASE_PATH=.
VERSION=$(USER)
DEPLOYZOR_USE_COMPONENT_PREFIX=0
DEPLOYZOR_GLOBAL_DOCKER_CONTEXT=1
FORCE_BUILD=1

include deployzor.mk
NOTEBOOK_FULL_IMAGE_NAME=$(DEPLOYZOR_DOCKER_REGISTRY)/$(DEPLOYZOR_PROJECT)/notebook-fastai:$(VERSION)

build.notebook-fastai:
	make image.build.notebook-fastai

publish.notebook-fastai: build.notebook-fastai
	make image.publish.notebook-fastai
