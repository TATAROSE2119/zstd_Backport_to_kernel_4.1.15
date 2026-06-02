PROJECT_ROOT := /home/tatarose/zstd_Backport
BUILD_DIR    := $(PROJECT_ROOT)/build
KERNELDIR    := /home/tatarose/linux_for_imx6ull/linux-imx-rel_imx_4.1.15_2.1.0_ga_alientek/
ARCH         ?= arm
CROSS_COMPILE?= arm-linux-gnueabihf-
CURRENT_PATH := $(shell pwd)

obj-m := zstd_compressor.o
zstd_compressor-y := zstd_crypto_module.o \
                     compress.o decompress.o \
                     huf_compress.o huf_decompress.o \
                     fse_compress.o fse_decompress.o \
                     entropy_common.o zstd_common.o \
                     xxhash.o
                     
# 下面接之前写过的 all 和 clean 目标
.PHONY: all  clean
all:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules
clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) clean