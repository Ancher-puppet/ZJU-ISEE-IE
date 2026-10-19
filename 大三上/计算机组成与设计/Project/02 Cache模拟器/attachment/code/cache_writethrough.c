/*
 * cache.c
 */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "cache.h"
#include "main.h"

/* cache configuration parameters */
static int cache_split = 0;
static int cache_usize = DEFAULT_CACHE_SIZE;
static int cache_isize = DEFAULT_CACHE_SIZE;
static int cache_dsize = DEFAULT_CACHE_SIZE;
static int cache_block_size = DEFAULT_CACHE_BLOCK_SIZE;
static int words_per_block = DEFAULT_CACHE_BLOCK_SIZE / WORD_SIZE;
static int cache_assoc = DEFAULT_CACHE_ASSOC;
static int cache_writeback = DEFAULT_CACHE_WRITEBACK;
static int cache_writealloc = DEFAULT_CACHE_WRITEALLOC;

/* cache model data structures */
static Pcache icache;
static Pcache dcache;
static cache c1; // c1属于cache结构体
static cache c2;
static cache_stat cache_stat_inst;
static cache_stat cache_stat_data;

/************************************************************/
void set_cache_param(param, value) int param;
int value;
{

  switch (param) {
  case CACHE_PARAM_BLOCK_SIZE:
    cache_block_size = value;
    words_per_block = value / WORD_SIZE;
    break;
  case CACHE_PARAM_USIZE:
    cache_split = FALSE;
    cache_usize = value;
    break;
  case CACHE_PARAM_ISIZE:
    cache_split = TRUE;
    cache_isize = value;
    break;
  case CACHE_PARAM_DSIZE:
    cache_split = TRUE;
    cache_dsize = value;
    break;
  case CACHE_PARAM_ASSOC:
    cache_assoc = value;
    break;
  case CACHE_PARAM_WRITEBACK:
    cache_writeback = TRUE;
    break;
  case CACHE_PARAM_WRITETHROUGH:
    cache_writeback = FALSE; // 设置为写直达
    break;
  case CACHE_PARAM_WRITEALLOC:
    cache_writealloc = TRUE;
    break;
  case CACHE_PARAM_NOWRITEALLOC:
    cache_writealloc = FALSE;
    break;
  default:
    printf("error set_cache_param: bad parameter value\n");
    exit(-1);
  }
}
/************************************************************/

/************************************************************/
void init_cache() {

  /* initialize the cache, and cache statistics data structures */
  // 初始化统计数据
  cache_stat_inst.accesses = 0;
  cache_stat_inst.misses = 0;
  cache_stat_inst.replacements = 0;
  cache_stat_inst.demand_fetches = 0;
  cache_stat_inst.copies_back = 0;

  cache_stat_data.accesses = 0;
  cache_stat_data.misses = 0;
  cache_stat_data.replacements = 0;
  cache_stat_data.demand_fetches = 0;
  cache_stat_data.copies_back = 0;

  // Unified Cache
  icache = dcache = &c1;
  cache_usize = cache_usize;
  c1.size = cache_usize;
  c1.associativity = cache_assoc;
  c1.n_sets = cache_usize / (cache_assoc * cache_block_size);
  // 计算offset和mask
  c1.index_mask_offset = LOG2(cache_block_size);
  c1.index_mask = (c1.n_sets - 1) << c1.index_mask_offset;
  // 分配内存
  c1.LRU_head = (Pcache_line *)malloc(sizeof(Pcache_line) * c1.n_sets);
  c1.LRU_tail = (Pcache_line *)malloc(sizeof(Pcache_line) * c1.n_sets);
  c1.set_contents = (int *)malloc(sizeof(int) * c1.n_sets);
  // 清空
  for (int i = 0; i < c1.n_sets; i++) {
    c1.LRU_head[i] = (Pcache_line)NULL;
    c1.LRU_tail[i] = (Pcache_line)NULL;
    c1.set_contents[i] = 0;
  }
}
/************************************************************/

/************************************************************/
void perform_access(addr, access_type) unsigned addr, access_type;
{
  /* handle an access to the cache */
  int index, tag;

  index = (addr & c1.index_mask) >> c1.index_mask_offset;
  tag = addr >> (c1.index_mask_offset + LOG2(c1.n_sets));

  // -------------------------查找逻辑-----------------------
  Pcache_line current_line = c1.LRU_head[index];
  Pcache_line target_line = (Pcache_line)NULL;

  // 遍历链表查找
  while (current_line != (Pcache_line)NULL) {
    if (current_line->tag == tag) {
      target_line = current_line; // hit
      break;
    }
    current_line = current_line->LRU_next; // 继续遍历
  }

  // ----------------命中 HIT------------------
  if (target_line != (Pcache_line)NULL) {
    // 更新统计
    if (access_type == TRACE_INST_LOAD)
      cache_stat_inst.accesses++;
    else
      cache_stat_data.accesses++;

    // 处理写操作
    if (access_type == TRACE_DATA_STORE) {
      if (cache_writeback) {
        // [Write-Back]: 只标记脏，不写内存
        target_line->dirty = TRUE;
      } else {
        // [Write-Through]: 立即写内存
        cache_stat_data.copies_back += 1;
        target_line->dirty = FALSE;
      }
    }

    // LRU 更新：将命中行移至头部
    delete(&c1.LRU_head[index], &c1.LRU_tail[index], target_line);
    insert(&c1.LRU_head[index], &c1.LRU_tail[index], target_line);
  }

  // --------------未命中 MISS---------------------
  else {
    // 统计数据
    if (access_type == TRACE_INST_LOAD) {
      cache_stat_inst.accesses++;
      cache_stat_inst.misses++;
      cache_stat_inst.demand_fetches += words_per_block;
    } else {
      cache_stat_data.accesses++;
      cache_stat_data.misses++;
      cache_stat_data.demand_fetches += words_per_block;
    }

    // 准备新的数据块
    Pcache_line new_cache_line = (Pcache_line)malloc(sizeof(cache_line));
    new_cache_line->tag = tag;
    new_cache_line->LRU_next = NULL;
    new_cache_line->LRU_prev = NULL;

    // 设置 Dirty 位
    if (access_type == TRACE_DATA_STORE) {
      if (cache_writeback) {
        // [Write-Back]: 载入后写入，变脏
        new_cache_line->dirty = TRUE;
      } else {
        // [Write-Through]: 载入后写入并穿透到内存
        cache_stat_data.copies_back += 1;
        new_cache_line->dirty = FALSE;
      }
    } else {
      new_cache_line->dirty = FALSE;
    }

    // set已满员时,删除掉原来的数据,进行替换
    if (c1.set_contents[index] >= c1.associativity) {
      // 统计replacement
      if (access_type == TRACE_INST_LOAD)
        cache_stat_inst.replacements++;
      else
        cache_stat_data.replacements++;

      // 定义链表尾部
      Pcache_line victim = c1.LRU_tail[index];

      // 检查写回 (Eviction),Write-Through 模式下 dirty,永远为FALSE，所以这里不会触发
      if (victim->dirty) {
        if (access_type == TRACE_INST_LOAD)
          cache_stat_inst.copies_back += words_per_block;
        else
          cache_stat_data.copies_back += words_per_block;
      }

      // 删除并释放
      delete(&c1.LRU_head[index], &c1.LRU_tail[index], victim);
      free(victim);
    }
    // set未满员时，增加计数
    else {
      c1.set_contents[index]++;
      c1.contents++;
    }

    // 无论是否替换，都将新块插入头部
    insert(&c1.LRU_head[index], &c1.LRU_tail[index], new_cache_line);
  }
}
/************************************************************/

/************************************************************/
void flush() {
  int i;
  Pcache_line current;
  Pcache_line next;

  // 遍历所有的 Set
  for (i = 0; i < c1.n_sets; i++) {
    current = c1.LRU_head[i];

    // 遍历该 Set 的链表
    while (current != (Pcache_line)NULL) {
      // 检查脏位
      if (current->dirty == TRUE) {
        // 如果是脏的，强制写回，增加统计计数
        cache_stat_data.copies_back += words_per_block;
      }

      // 释放内存
      next = current->LRU_next;
      free(current);
      current = next;
    }

    c1.LRU_head[i] = NULL;
    c1.LRU_tail[i] = NULL;
    c1.set_contents[i] = 0;
  }
}
/************************************************************/

/************************************************************/
void delete(head, tail, item) Pcache_line *head, *tail;
Pcache_line item;
{
  if (item->LRU_prev) {
    item->LRU_prev->LRU_next = item->LRU_next;
  } else {
    /* item at head */
    *head = item->LRU_next;
  }

  if (item->LRU_next) {
    item->LRU_next->LRU_prev = item->LRU_prev;
  } else {
    /* item at tail */
    *tail = item->LRU_prev;
  }
}
/************************************************************/

/************************************************************/
/* inserts at the head of the list */
void insert(head, tail, item) Pcache_line *head, *tail;
Pcache_line item;
{
  item->LRU_next = *head;
  item->LRU_prev = (Pcache_line)NULL;

  if (item->LRU_next)
    item->LRU_next->LRU_prev = item;
  else
    *tail = item;

  *head = item;
}
/************************************************************/

/************************************************************/
void dump_settings() {
  printf("*** CACHE SETTINGS ***\n");
  if (cache_split) {
    printf("  Split I- D-cache\n");
    printf("  I-cache size: \t%d\n", cache_isize);
    printf("  D-cache size: \t%d\n", cache_dsize);
  } else {
    printf("  Unified I- D-cache\n");
    printf("  Size: \t%d\n", cache_usize);
  }
  printf("  Associativity: \t%d\n", cache_assoc);
  printf("  Block size: \t%d\n", cache_block_size);
  printf("  Write policy: \t%s\n",
         cache_writeback ? "WRITE BACK" : "WRITE THROUGH");
  printf("  Allocation policy: \t%s\n",
         cache_writealloc ? "WRITE ALLOCATE" : "WRITE NO ALLOCATE");
}
/************************************************************/

/************************************************************/
void print_stats() {
  printf("\n*** CACHE STATISTICS ***\n");

  printf(" INSTRUCTIONS\n");
  printf("  accesses:  %d\n", cache_stat_inst.accesses);
  printf("  misses:    %d\n", cache_stat_inst.misses);
  if (!cache_stat_inst.accesses)
    printf("  miss rate: 0 (0)\n");
  else
    printf("  miss rate: %2.4f