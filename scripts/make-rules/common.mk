HOST_ARCH ?= $(shell uname -m | tr A-Z a-z)
ifeq ($(HOST_ARCH),x86_64)
	HOST_ARCH=amd64
endif
ifeq ($(HOST_ARCH),aarch64)
	HOST_ARCH=arm64
endif
ifeq ($(HOST_ARCH),armv7l)
    HOST_ARCH=armv7
endif
ifeq ($(HOST_ARCH),loongarch64)
    HOST_ARCH=loong64
endif

ARCH ?= $(HOST_ARCH)

DOCKER_BUILDKIT ?= 1
DOCKER_BUILD_ARGS ?= 
