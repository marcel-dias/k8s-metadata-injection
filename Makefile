BIN_DIR = ./bin
TOOLS_DIR := $(BIN_DIR)/dev-tools
BINARY_NAME ?= $(BIN_DIR)/k8s-metadata-injection
DOCKER_IMAGE_NAME ?= newrelic/k8s-metadata-injection
DOCKER_IMAGE_TAG ?= 1.3.2

GOLANGCILINT_VERSION = 1.33.0

# required for enabling Go modules inside $GOPATH
export GO111MODULE=on

# GOOS and GOARCH will likely come from env
GOOS ?=
GOARCH ?=
CGO_ENABLED ?= 0

ifneq ($(strip $(GOOS)), )
BINARY_NAME := $(BINARY_NAME)-$(GOOS)
endif

ifneq ($(strip $(GOARCH)), )
BINARY_NAME := $(BINARY_NAME)-$(GOARCH)
endif

.PHONY: all
all: build

.PHONY: build
build: lint test compile

$(TOOLS_DIR):
	@mkdir -p $@

$(TOOLS_DIR)/golangci-lint: $(TOOLS_DIR)
	@echo "[tools] Downloading 'golangci-lint'"
	@wget -O - -q https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | BINDIR=$(@D) sh -s v$(GOLANGCILINT_VERSION) > /dev/null 2>&1

.PHONY: lint
lint: $(TOOLS_DIR)/golangci-lint
	@echo "[validate] Validating source code running golangci-lint"
	@$(TOOLS_DIR)/golangci-lint run

compile:
	@echo "=== $(INTEGRATION) === [ compile ]: Building $(INTEGRATION)..."
	go mod download
	CGO_ENABLED=$(CGO_ENABLED) go build -o $(BINARY_NAME) ./cmd/server

.PHONY: build-container
build-container:
	grep -e "image: $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)" deploy/newrelic-metadata-injection.yaml > /dev/null || \
	( echo "Docker image tag being built $(DOCKER_IMAGE_TAG) is not synchronized with deployment yaml" && exit 1 )
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) $$DOCKERARGS .

.PHONY: test
test:
	@echo "[test] Running unit tests"
	@go test ./...

.PHONY: e2e-test
e2e-test:
	@echo "[test] Running e2e tests"
	./e2e-tests/tests.sh

.PHONY: benchmark-test
benchmark-test:
	@echo "[test] Running benchmark tests"
	@go test -run=^Benchmark* -bench .

deploy/combined.yaml: deploy/newrelic-metadata-injection.yaml deploy/job.yaml
	echo '---' | cat deploy/newrelic-metadata-injection.yaml - deploy/job.yaml > deploy/combined.yaml
