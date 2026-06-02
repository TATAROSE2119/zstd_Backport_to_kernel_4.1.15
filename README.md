# zstd Backport for Linux 4.1.15

将 Linux 4.15 内核中的 Zstandard (zstd) 压缩算法反向移植到 Linux 4.1.15 内核。

## 背景

Linux 4.1.15 内核（常用于 i.MX6ULL 等 ARM 平台）不支持 zstd 压缩算法。本项目将 zstd 压缩/解压库及 Crypto API 模块反向移植，使内核子系统（如 zram、squashfs、ubifs 等）可以使用 zstd 压缩。

## 项目结构

```
.
├── zstd.h                  # zstd 公共 API 头文件
├── zstd_internal.h         # zstd 内部头文件
├── zstd_opt.h              # zstd 优化参数头文件
├── compress.c              # zstd 压缩实现
├── decompress.c            # zstd 解压实现
├── fse.h / fse_compress.c / fse_decompress.c   # FSE 熵编码
├── huf.h / huf_compress.c / huf_decompress.c   # Huffman 编码
├── entropy_common.c        # 熵编码公共函数
├── zstd_common.c           # zstd 公共函数
├── xxhash.c / xxhash.h     # xxHash 快速哈希
├── bitstream.h             # 位流操作
├── mem.h                   # 内存操作
├── error_private.h         # 错误码定义
├── zstd_crypto_module.c    # Linux Crypto API 模块（核心）
├── Makefile                # 内核模块 Makefile
└── Linux 4.15内核eBPF支持.md  # 参考文档
```

## 编译

```bash
# 修改 Makefile 中的内核源码路径
# KDIR := /path/to/your/kernel/source

make
```

## 使用

### 1. 加载模块

```bash
insmod zstd_compressor.ko
```

### 2. 验证注册成功

```bash
cat /proc/crypto | grep zstd
```

### 3. 配合 zram 使用

> **重要**：4.1.15 内核的 zram 驱动默认不识别 zstd 算法，需要修改内核源码。

#### 3.1 修改内核 zram 驱动

在内核源码中，需要修改`drivers/block/zram/zcomp.c`:
```c
...
#include <linux/crypto.h>
#include <linux/err.h>

...

static void *zstd_crypto_create(void) {
        return crypto_alloc_comp("zstd", 0, 0);
}

static void zstd_crypto_destroy(void *private) {
        crypto_free_comp(private);
}

static int zstd_crypto_compress(const unsigned char *src, unsigned char *dst,
                                size_t *dst_len, void *private) {
        struct crypto_comp *comp = private;
        unsigned int dlen = PAGE_SIZE*2; // 预留足够空间
        int ret = crypto_comp_compress(comp, src, PAGE_SIZE, dst, &dlen);
        *dst_len = dlen;
        return ret;
}

static int zstd_crypto_decompress(const unsigned char *src, size_t src_len,
                                  unsigned char *dst) {
        // 强行临时分配一个引擎来解压（虽然有轻微性能损耗，但能完美绕过老 API 限制）
        struct crypto_comp *comp = crypto_alloc_comp("zstd", 0, 0);
        unsigned int dlen = PAGE_SIZE;
        int ret;
        
        if (IS_ERR(comp)) return -EINVAL;
        
        ret = crypto_comp_decompress(comp, src, src_len, dst, &dlen);
        crypto_free_comp(comp);
        return ret;
}

static struct zcomp_backend zcomp_zstd = {
        .compress = zstd_crypto_compress,
        .decompress = zstd_crypto_decompress,
        .create = zstd_crypto_create,
        .destroy = zstd_crypto_destroy,
        .name = "zstd",
};
/* ========================================================== */

static struct zcomp_backend *backends[] = {
	&zcomp_lzo,
#ifdef CONFIG_ZRAM_LZ4_COMPRESS
	&zcomp_lz4,
#endif
	&zcomp_zstd,
	NULL
};


```

然后重新编译内核的 zram 模块：

```bash
cd /path/to/kernel/source
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules SUBDIRS=drivers/block/zram
```

#### 3.2 在目标板上操作

```bash
# 加载 zstd 算法模块
insmod zstd_compressor.ko

# 替换 zram 模块（如果已加载）
rmmod zram
insmod drivers/block/zram/zram.ko

# 设置 zram 使用 zstd
echo 1 > /sys/block/zram0/reset
echo zstd > /sys/block/zram0/comp_algorithm
cat /sys/block/zram0/comp_algorithm   # 应显示: lzo [zstd]
echo 256M > /sys/block/zram0/disksize
```

## 目标平台

- 内核版本：Linux 4.1.15
- 架构：ARM (i.MX6ULL)
- 交叉编译器：arm-linux-gnueabihf-

## 许可证

GPL v2（与 Linux 内核保持一致）
