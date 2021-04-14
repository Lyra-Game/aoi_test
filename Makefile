.PHONY: all clean

TOP=server
BUILD_DIR=$(TOP)/build
BIN_DIR=$(TOP)/bin

INCLUDE_DIR=$(BUILD_DIR)/include
BUILD_CLUALIB_DIR=$(BUILD_DIR)/clualib
BUILD_CSERVICE_DIR=$(BUILD_DIR)/cservice
BUILD_CLIB_DIR=$(BUILD_DIR)/clib

all: build
build:
	-mkdir -p $(BUILD_DIR)
	-mkdir -p $(BIN_DIR)
	-mkdir -p $(INCLUDE_DIR)
	-mkdir -p $(BUILD_CLUALIB_DIR)
	-mkdir -p $(BUILD_CSERVICE_DIR)
	-mkdir -p $(BUILD_CLIB_DIR)

.PHONY: skynet
all: skynet
SKYNET_MAKEFILE=$(TOP)/skynet/Makefile
$(SKYNET_MAKEFILE):
	git submodule update --init
SKYNET_DEP_PATH= SKYNET_BUILD_PATH=../../$(BIN_DIR) \
		LUA_CLIB_PATH=../../$(BUILD_CLUALIB_DIR) \
		CSERVICE_PATH=../../$(BUILD_CSERVICE_DIR)
build-skynet: | $(SKYNET_MAKEFILE)
	cd $(TOP)/skynet && $(MAKE) PLAT=linux $(SKYNET_DEP_PATH)

skynet: build-skynet
	cp $(TOP)/skynet/skynet-src/skynet_malloc.h $(INCLUDE_DIR)
	cp $(TOP)/skynet/skynet-src/skynet.h $(INCLUDE_DIR)
	cp $(TOP)/skynet/skynet-src/skynet_env.h $(INCLUDE_DIR)
	cp $(TOP)/skynet/skynet-src/skynet_socket.h $(INCLUDE_DIR)
	cp $(TOP)/skynet/3rd/lua/*.h $(INCLUDE_DIR)
	cp $(TOP)/skynet/3rd/lua/lua $(BIN_DIR)

define CLEAN_SKYNET
	cd $(TOP)/skynet && $(MAKE) $(SKYNET_DEP_PATH) clean
endef
CLEAN += $(CLEAN_SKYNET)

all: nest

CFLAGS = -g3 -O2 -rdynamic -Wall -I$(INCLUDE_DIR)
LDFLAGS = -L$(BUILD_CLIB_DIR) -Wl,-rpath $(BUILD_CLIB_DIR) -pthread -lm -ldl -lrt
SHARED = -fPIC --shared

CLIB=
CLUALIB=cjson grid
CSERVICE=

CLIB_TARGET=$(patsubst %, $(BUILD_CLIB_DIR)/lib%.so, $(CLIB))
CLUALIB_TARGET=$(patsubst %, $(BUILD_CLUALIB_DIR)/%.so, $(CLUALIB))
CSERVICE_TARGET=$(patsubst %, $(BUILD_CSERVICE_DIR)/%.so, $(CSERVICE))

nest: $(CLIB_TARGET) \
	$(CLUALIB_TARGET) \
	$(CSERVICE_TARGET)

SUBMODULE_PATH=$(TOP)/3rd

CJSON_SOURCE=$(SUBMODULE_PATH)/lua-cjson/lua_cjson.c \
	$(SUBMODULE_PATH)/lua-cjson/strbuf.c \
	$(SUBMODULE_PATH)/lua-cjson/fpconv.c

$(SUBMODULE_PATH)/lua-cjson/lua_cjson.c:
	git submodule update --init $(SUBMODULE_PATH)/lua-cjson

$(BUILD_CLUALIB_DIR)/cjson.so: $(CJSON_SOURCE)
	gcc $(CFLAGS) -I$(SUBMODULE_PATH)/lua/lua-cjson $(SHARED) $^ -o $@ $(LDFLAGS)

GRID_SOURCE=$(SUBMODULE_PATH)/lua-grid/luabinding.c \
	$(SUBMODULE_PATH)/lua-grid/grid.c \
	$(SUBMODULE_PATH)/lua-grid/node_freelist.c \
	$(SUBMODULE_PATH)/lua-grid/intlist.c

GRIDMAKEFILE=$(SUBMODULE_PATH)/lua-grid/Makefile
$(GRIDMAKEFILE):
	git submodule update --init $(SUBMODULE_PATH)/lua-grid

$(BUILD_CLUALIB_DIR)/grid.so: $(GRID_SOURCE) | $(GRIDMAKEFILE)
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

clean:
	-rm -rf $(BUILD_DIR)
	$(CLEAN)
