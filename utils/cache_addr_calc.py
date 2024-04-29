#! /usr/bin/env python3

import math

CACHE_SIZE = 1024 * 4
CACHE_BLOCK_SIZE = 8 * 4
CACHE_WAY_NUM = 2

CACHE_IDX_OFS = int(math.log2(CACHE_BLOCK_SIZE))
CACHE_TAG_OFS = int(math.log2(CACHE_SIZE / CACHE_WAY_NUM))

# 输出cache的参数
print(f"CACHE_SIZE: {CACHE_SIZE}, CACHE_BLOCK_SIZE: {CACHE_BLOCK_SIZE}, CACHE_WAY_NUM: {CACHE_WAY_NUM}")

# 输出cache各个分段的区间
print(f"CACHE_TAG: [31:{CACHE_TAG_OFS}], CACHE_IDX: [{CACHE_TAG_OFS - 1}:{CACHE_IDX_OFS}], CACHE_OFS: [{CACHE_IDX_OFS - 1}:0]")
print()

# 计算cache的tag、index、offset
def cache_addr_calc(addr):
    ofs = addr & ((1 << CACHE_IDX_OFS) - 1)
    idx = (addr >> CACHE_IDX_OFS) & ((1 << (CACHE_TAG_OFS - CACHE_IDX_OFS)) - 1)
    tag = (addr >> CACHE_TAG_OFS) & ((1 << (32 - CACHE_TAG_OFS)) - 1)
    return tag, idx, ofs

# 生成一个好看的输出
def calc(addr):
    tag, idx, ofs = cache_addr_calc(addr)
    print(f"addr: 0x{addr:08x}", end=" ")
    # 输出addr二进制 每四位一个空格
    print(" ".join([f"{(addr >> i) & 0xf:04b}" for i in range(28, -1, -4)]))
    print(f"tag: 0x{tag:08x}, idx: 0x{idx:08x}, ofs: 0x{ofs:08x}")
    
    # 输出addr二进制 按照cache的tag、index、offset分段
    print(f"tag: {tag:08x} " + " ".join([f"{(tag >> i) & 0xf:04b}" for i in range(28, -1, -4)]))
    print(f"idx: {idx:08x} " + " ".join([f"{(idx >> i) & 0xf:04b}" for i in range(28, -1, -4)]))
    print(f"ofs: {ofs:08x} " + " ".join([f"{(ofs >> i) & 0xf:04b}" for i in range(28, -1, -4)]))
    print()




if __name__ == "__main__":
    addr = 0x0000277C
    calc(addr)
    addr = 0x00F44F74
    calc(addr)