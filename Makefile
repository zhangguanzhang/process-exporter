MK_FILES := $(wildcard $(CURDIR)/scripts/make-rules/*.mk) 
include $(MK_FILES) 
-include $(CURDIR)/ci-gen.mk


pkgs          = $(shell go list ./...)

BIN_DIR                 ?= bin
DOCKER_IMAGE_NAME       ?= zhangguanzhang/process-exporter

BRANCH      ?= $(shell git rev-parse --abbrev-ref HEAD)
BUILDDATE   ?= $(shell date --iso-8601=seconds)
BUILDUSER   ?= $(shell whoami)@$(shell hostname)
REVISION    ?= $(shell git rev-parse HEAD)
TAG_VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null|| echo master)

GO_IMG ?= golang:1.23
IMAGE_NAME ?= $(DOCKER_IMAGE_NAME):$(TAG_VERSION)

ARCHS?=amd64 arm64
comma := ,
space := $(empty) $(empty)
PLATFORMS := $(subst $(space),$(comma),$(ARCHS))

VERSION_LDFLAGS := \
  -X github.com/prometheus/common/version.Branch=$(BRANCH) \
  -X github.com/prometheus/common/version.BuildDate=$(BUILDDATE) \
  -X github.com/prometheus/common/version.BuildUser=$(BUILDUSER) \
  -X github.com/prometheus/common/version.Revision=$(REVISION) \
  -X main.version=$(TAG_VERSION)

SMOKE_TEST = -config.path packaging/conf/all.yaml -once-to-stdout-delay 1s |grep -q 'namedprocess_namegroup_memory_bytes{groupname="process-exporte",memtype="virtual"}'

all: format vet test bin smoke

style:
	@echo ">> checking code style"
	@! gofmt -d $(shell find . -name '*.go' -print) | grep '^'

test:
	@echo ">> running short tests"
	go test -short $(pkgs)

.PHONY: format
format:
	@echo ">> formatting code"
	go fmt $(pkgs)

vet:
	@echo ">> vetting code"
	go vet $(pkgs)

build:
	@echo ">> building code"
	CGO_ENABLED=0 GOOS=linux GOARCH=$(ARCH) go build -ldflags "$(VERSION_LDFLAGS)" -o $(BIN_DIR)/process-exporter -a cmd/process-exporter/main.go

smoke:
	@echo ">> smoke testing process-exporter"
	./process-exporter $(SMOKE_TEST)

integ:
	@echo ">> integration testing process-exporter"
	go build -o $(BIN_DIR)/integration-tester cmd/integration-tester/main.go
	go build -o $(BIN_DIR)/load-generator cmd/load-generator/main.go
	cd $(BIN_DIR) && ./integration-tester -write-size-bytes 65536

install:
	@echo ">> installing binary"
	cd cmd/process-exporter; CGO_ENABLED=0 go install -a 

docker-smoke:
	docker run --rm -v $(PWD):/v -w /v $(IMAGE_NAME) $(SMOKE_TEST)

docker:
	@echo ">> building docker image"
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker build . $(DOCKER_BUILD_ARGS) -t $(IMAGE_NAME)

dockerx:
	@echo ">> buildx building docker image"
	docker buildx build --platform=$(PLATFORMS) . $(DOCKER_BUILD_ARGS) -t $(IMAGE_NAME)

dockertest:
	docker run --rm -it -v `pwd`:/opt/process-exporter $(GO_IMG)  make -C /opt/process-exporter test

dockerinteg:
	docker run --rm -it -v `pwd`:/opt/process-exporter $(GO_IMG)  make -C /opt/process-exporter build integ

.PHONY: update-go-deps
update-go-deps:
	@echo ">> updating Go dependencies"
	@for m in $$(go list -mod=readonly -m -f '{{ if and (not .Indirect) (not .Main)}}{{.Path}}{{end}}' all); do \
		go get $$m; \
	done
	go mod tidy

.PHONY: all style format test vet build integ docker
