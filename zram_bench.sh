#!/bin/sh

# ---------------------------------------------------------
# ZRAM 压缩算法自动化基准测试脚本
# 适用环境: 嵌入式 Linux (BusyBox)
# ---------------------------------------------------------


TEST_FILE="/tmp/zram_test.tar"
ZRAM_DEV="/dev/zram0"
SYS_ZRAM="/sys/block/zram0"

echo "=================================================="
echo "    🚀 ZRAM 压缩算法全自动性能测评仪"
echo "=================================================="

# 1. 准备测试弹药 (如果不存在则自动抓取系统文件打包)
if [ ! -f "$TEST_FILE" ]; then
    echo "[*] 正在生成真实系统指令测试包 (这可能需要几秒钟)..."
    tar -cf $TEST_FILE /bin /sbin /lib 2>/dev/null
fi

# 获取文件精确大小
ORIG_SIZE=$(stat -c %s $TEST_FILE)
ORIG_MB=$(awk "BEGIN {printf \"%.2f\", $ORIG_SIZE / 1048576}")
echo "[*] 测试目标: $TEST_FILE"
echo "[*] 原始体积: $ORIG_SIZE 字节 ($ORIG_MB MB)"
echo "=================================================="

# 测试核心逻辑
run_benchmark() {
    ALG=$1
    echo ""
    echo ">>> 开始测评引擎: [$ALG] <<<"

    # a) 重置环境
    swapoff $ZRAM_DEV 2>/dev/null
    echo 1 > $SYS_ZRAM/reset
    
    # b) 切换算法并验证是否生效
    echo $ALG > $SYS_ZRAM/comp_algorithm
    CUR_ALG=$(cat $SYS_ZRAM/comp_algorithm | grep -o "\[$ALG\]")
    if [ -z "$CUR_ALG" ]; then
        echo "  [!] 失败: 切换到 $ALG 失败，请检查内核是否勾选该算法！"
        return
    fi
    
    # c) 分配容量
    echo 50M > $SYS_ZRAM/disksize

    # d) 清除页面缓存 (Drop Caches) 保证每次读取不受上次影响
    echo 3 > /proc/sys/vm/drop_caches

    # e) 计时并暴力写入 (将 dd 的输出重定向，只保留 time 的耗时)
    echo "  -> 正在极限写入并测速..."
    time dd if=$TEST_FILE of=$ZRAM_DEV bs=4K 2>/dev/null

    # f) 读取底层雷达数据
    STAT=$(cat $SYS_ZRAM/mm_stat)
    IN_DATA=$(echo $STAT | awk '{print $1}')
    COMP_DATA=$(echo $STAT | awk '{print $2}')

    # g) 容错处理 (防止除以 0)
    if [ "$COMP_DATA" -eq 0 ]; then
        echo "  [!] 错误: 未读取到压缩数据。"
        return
    fi

    # h) 计算终极战报
    RATIO=$(awk "BEGIN {printf \"%.2f\", $IN_DATA / $COMP_DATA}")
    SAVED_MB=$(awk "BEGIN {printf \"%.2f\", ($IN_DATA - $COMP_DATA) / 1048576}")
    COMP_MB=$(awk "BEGIN {printf \"%.2f\", $COMP_DATA / 1048576}")

    echo "  ------------------------------------"
    echo "  ✅ 测评结果 [$ALG]:"
    echo "  压缩后体积: $COMP_DATA 字节 ($COMP_MB MB)"
    echo "  压榨出内存: $SAVED_MB MB"
    echo "  极限压缩率: ${RATIO}x"
    echo "  ------------------------------------"
}

# 依次执行三大门派的测试
run_benchmark "lzo"
run_benchmark "lz4"
run_benchmark "zstd"

echo ""
echo "[*] 所有测试执行完毕，请对比上方 time (real 时间) 与压缩率！"
echo "=================================================="