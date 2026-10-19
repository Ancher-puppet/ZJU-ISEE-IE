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
static cache c1;
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
    cache_writeback = FALSE;
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
/* 辅助函数：初始化单个 Cache 结构体 */
void init_one_cache(Pcache c, int size) {
  c->size = size;
  c->associativity = cache_assoc;
  c->n_sets = size / (cache_assoc * cache_block_size);

  c->index_mask_offset = LOG2(cache_block_size);
  c->index_mask = (c->n_sets - 1) << c->index_mask_offset;

  c->LRU_head = (Pcache_line *)malloc(sizeof(Pcache_line) * c->n_sets);
  c->LRU_tail = (Pcache_line *)malloc(sizeof(Pcache_line) * c->n_sets);
  c->set_contents = (int *)malloc(sizeof(int) * c->n_sets);
  c->contents = 0;

  for (int i = 0; i < c->n_sets; i++) {
    c->LRU_head[i] = NULL;
    c->LRU_tail[i] = NULL;
    c->set_contents[i] = 0;
  }
}

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

  // 分离式 Cache (Split)
  if (cache_split) {
    icache = &c1;
    dcache = &c2;
    init_one_cache(icache, cache_isize);
    init_one_cache(dcache, cache_dsize);
  }
  // 统一式 Cache (Unified)
  else {
    icache = &c1;
    dcache = &c1; // 指向同一个结构体
    init_one_cache(icache, cache_usize);
  }
}
/************************************************************/

/************************************************************/
void perform_access(addr, access_type) unsigned addr, access_type;
{
  int index, tag;
  Pcache current_cache;     // 操作的 Cache 指针
  Pcache_stat current_stat; // 统计数据指针

  // 根据访问类型，决定去哪个 Cache (I-Cache 还是 D-Cache)
  if (access_type == TRACE_INST_LOAD) {
    current_cache = icache;
    current_stat = &cache_stat_inst;
  } else {
    current_cache = dcache;
    current_stat = &cache_stat_data;
  }

  // 计算 Index 和 Tag
  index =
      (addr & current_cache->index_mask) >> current_cache->index_mask_offset;
  tag =
      addr >> (current_cache->index_mask_offset + LOG2(current_cache->n_sets));

  // 查找
  Pcache_line current_line = current_cache->LRU_head[index];
  Pcache_line target_line = NULL;

  while (current_line != NULL) {
    if (current_line->tag == tag) {
      target_line = current_line;
      break;
    }
    current_line = current_line->LRU_next;
  }

  // 处理命中 (HIT)
  if (target_line != NULL) {
    current_stat->accesses++;

    if (access_type == TRACE_DATA_STORE) {
      target_line->dirty = TRUE;
    }

    // LRU 更新：移到头部
    delete(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
           target_line);
    insert(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
           target_line);
  }

  // 处理缺失 (MISS)
  else {
    current_stat->accesses++;
    current_stat->misses++;
    current_stat->demand_fetches += words_per_block;

    // 准备新行
    Pcache_line new_line = (Pcache_line)malloc(sizeof(cache_line));
    new_line->tag = tag;
    new_line->dirty = (access_type == TRACE_DATA_STORE) ? TRUE : FALSE;
    new_line->LRU_next = NULL;
    new_line->LRU_prev = NULL;

    // 检查容量
    if (current_cache->set_contents[index] >= current_cache->associativity) {
      // Set 满了则替换
      current_stat->replacements++;

      Pcache_line victim = current_cache->LRU_tail[index];

      // 检查写回 (Copy Back)
      if (victim->dirty) {
        current_stat->copies_back += words_per_block;
      }

      delete(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
             victim);
      free(victim); // 释放内存
    } else {
      // Set 没满则增加计数
      current_cache->set_contents[index]++;
      current_cache->contents++;
    }

    // 插入新行到头部
    insert(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
           new_line);
  }
}
/************************************************************/

/************************************************************/
/* 辅助函数：清理单个 Cache */
void flush_one_cache(Pcache c, Pcache_stat stat) {
  int i;
  Pcache_line current;
  Pcache_line next;

  for (i = 0; i < c->n_sets; i++) {
    current = c->LRU_head[i];
    while (current != NULL) {
      if (current->dirty == TRUE) {
        stat->copies_back += words_per_block;
      }
      next = current->LRU_next;
      free(current);
      current = next;
    }
    c->LRU_head[i] = NULL;
    c->LRU_tail[i] = NULL;
    c->set_contents[i] = 0;
  }
}

void flush() {
  /* flush the cache */
  if (cache_split) {
    flush_one_cache(icache, &cache_stat_inst);
    flush_one_cache(dcache, &cache_stat_data);
  } else {
    // Unified Cache: 所有的 Dirty 都是 Data store 造成的
    flush_one_cache(icache, &cache_stat_data);
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
    *head = item->LRU_next;
  }

  if (item->LRU_next) {
    item->LRU_next->LRU_prev = item->LRU_prev;
  } else {
    *tail = item->LRU_prev;
  }
}
/************************************************************/

/************************************************************/
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
    printf("  miss rate: %2.4f (hit rate %2.4f)\n",
           (float)cache_stat_inst.misses / (float)cache_stat_inst.accesses,
           1.0 -
               (float)cache_stat_inst.misses / (float)cache_stat_inst.accesses);
  printf("  replace:   %d\n", cache_stat_inst.replacements);

  printf(" DATA\n");
  printf("  accesses:  %d\n", cache_stat_data.accesses);
  printf("  misses:    %d\n", cache_stat_data.misses);
  if (!cache_stat_data.accesses)
    printf("  miss rate: 0 (0)\n");
  else
    printf("  miss rate: %2.4f (hit rate %2.4f)\n",
           (float)cache_stat_data.misses / (float)cache_stat_data.accesses,
           1.0 -
               (float)cache_stat_data.misses / (float)cache_stat_data.accesses);
  printf("  replace:   %d\n", cache_stat_data.replacements);

  printf(" TRAFFIC (in words)\n");
  printf("  demand fetch:  %d\n",
         cache_stat_inst.demand_fetches + cache_stat_data.demand_fetches);
  printf("  copies back:   %d\n",
         cache_stat_inst.copies_back + cache_stat_data.copies_back);
}
/************************************************************/