GO_BIN_PATH = bin
GO_SRC_PATH = NFs
C_BUILD_PATH = build
ROOT_PATH = $(shell pwd)

NF = $(GO_NF)
GO_NF = amf ausf nrf nssf pcf smf udm udr n3iwf upf chf

WEBCONSOLE = webconsole

NF_GO_FILES = $(shell find $(GO_SRC_PATH)/$(NF) -name "*.go" ! -name "*_test.go")
WEBCONSOLE_GO_FILES = $(shell find $(WEBCONSOLE) -name "*.go" ! -name "*_test.go")
WEBCONSOLE_JS_FILES = $(shell find $(WEBCONSOLE)/frontend -name '*.tsx' ! -path "*/node_modules/*")
WEBCONSOLE_FRONTEND = $(WEBCONSOLE)/public

VERSION = $(shell git describe --tags)
BUILD_TIME = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT_HASH = $(shell git submodule status | grep $(GO_SRC_PATH)/$(@F) | awk '{print $$(1)}' | cut -c1-8)
COMMIT_TIME = $(shell cd $(GO_SRC_PATH)/$(@F) && git log --pretty="@%at" -1 | xargs date -u +"%Y-%m-%dT%H:%M:%SZ" -d)
LDFLAGS = -X github.com/free5gc/util/version.VERSION=$(VERSION) \
          -X github.com/free5gc/util/version.BUILD_TIME=$(BUILD_TIME) \
          -X github.com/free5gc/util/version.COMMIT_HASH=$(COMMIT_HASH) \
          -X github.com/free5gc/util/version.COMMIT_TIME=$(COMMIT_TIME)

WEBCONSOLE_COMMIT_HASH = $(shell git submodule status | grep $(WEBCONSOLE) | awk '{print $$(1)}' | cut -c1-8)
WEBCONSOLE_COMMIT_TIME = $(shell cd $(WEBCONSOLE) && git log --pretty="@%at" -1 | xargs date -u +"%Y-%m-%dT%H:%M:%SZ" -d)
WEBCONSOLE_LDFLAGS = -X github.com/free5gc/util/version.VERSION=$(VERSION) \
                     -X github.com/free5gc/util/version.BUILD_TIME=$(BUILD_TIME) \
                     -X github.com/free5gc/util/version.COMMIT_HASH=$(WEBCONSOLE_COMMIT_HASH) \
                     -X github.com/free5gc/util/version.COMMIT_TIME=$(WEBCONSOLE_COMMIT_TIME)

.PHONY: $(NF) $(WEBCONSOLE) clean install-upf-deps

.DEFAULT_GOAL: nfs

nfs: $(NF)

all: $(NF) $(WEBCONSOLE)

debug: GCFLAGS += -N -l
debug: all

$(GO_NF): % : $(GO_BIN_PATH)/%

$(GO_BIN_PATH)/%: $(NF_GO_FILES)
	@echo "Start building $(@F)...."
	cd $(GO_SRC_PATH)/$(@F)/cmd && \
	CGO_ENABLED=$(if $(filter upf,$(@F)),1,0) go build -gcflags "$(GCFLAGS)" -ldflags "$(LDFLAGS)" -o $(ROOT_PATH)/$@ main.go

vpath %.go $(addprefix $(GO_SRC_PATH)/, $(GO_NF))

$(WEBCONSOLE): $(WEBCONSOLE)/$(GO_BIN_PATH)/$(WEBCONSOLE) $(WEBCONSOLE_FRONTEND)

$(WEBCONSOLE)/$(GO_BIN_PATH)/$(WEBCONSOLE): $(WEBCONSOLE)/server.go $(WEBCONSOLE_GO_FILES)
	@echo "Start building $(@F)...."
	cd $(WEBCONSOLE) && \
	CGO_ENABLED=1 go build -ldflags "$(WEBCONSOLE_LDFLAGS)" -o $(ROOT_PATH)/$@ ./server.go

$(WEBCONSOLE_FRONTEND): $(WEBCONSOLE_JS_FILES)
	@echo "Start building $(@F) frontend...."
	cd $(WEBCONSOLE)/frontend && \
	corepack enable && \
	yarn install && \
	yarn build && \
	rm -rf ../public && \
	cp -R build ../public

clean:
	rm -rf $(addprefix $(GO_BIN_PATH)/, $(GO_NF))
	rm -rf $(addprefix $(GO_SRC_PATH)/, $(addsuffix /$(C_BUILD_PATH), $(C_NF)))
	rm -rf $(WEBCONSOLE)/$(GO_BIN_PATH)/$(WEBCONSOLE)

install-upf-deps:
	apt-get update && \
	apt-get install -y libpcap-dev build-essential

$(GO_BIN_PATH)/upf: install-upf-deps
$(GO_BIN_PATH)/upf: $(NF_GO_FILES)
	@echo "Start building UPF...."
	cd $(GO_SRC_PATH)/upf/cmd && \
	CGO_ENABLED=1 go build -gcflags "$(GCFLAGS)" -ldflags "$(LDFLAGS)" -o $(ROOT_PATH)/$@ main.go