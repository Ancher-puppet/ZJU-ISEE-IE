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
    cache_writeback = FALSE; // 写直达
    break;
  case CACHE_PARAM_WRITEALLOC:
    cache_writealloc = TRUE;
    break;
  case CACHE_PARAM_NOWRITEALLOC:
    cache_writealloc = FALSE; // 写不分配
    break;
  default:
    printf("error set_cache_param: bad parameter value\n");
    exit(-1);
  }
}
/************************************************************/

/************************************************************/
/* 辅助函数：初始化单个 Cache */
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

  if (cache_split) {
    icache = &c1;
    dcache = &c2;
    init_one_cache(icache, cache_isize);
    init_one_cache(dcache, cache_dsize);
  } else {
    icache = dcache = &c1;
    init_one_cache(icache, cache_usize);
  }
}
/************************************************************/

/************************************************************/
void perform_access(addr, access_type) unsigned addr, access_type;
{
  int index, tag;
  Pcache current_cache;
  Pcache_stat current_stat;

  // 1. Split Cache 选择逻辑
  if (access_type == TRACE_INST_LOAD) {
    current_cache = icache;
    current_stat = &cache_stat_inst;
  } else {
    current_cache = dcache;
    current_stat = &cache_stat_data;
  }

  // 2. 地址解码
  index =
      (addr & current_cache->index_mask) >> current_cache->index_mask_offset;
  tag =
      addr >> (current_cache->index_mask_offset + LOG2(current_cache->n_sets));

  // 3. 查找逻辑
  Pcache_line current_line = current_cache->LRU_head[index];
  Pcache_line target_line = NULL;

  while (current_line != NULL) {
    if (current_line->tag == tag) {
      target_line = current_line;
      break;
    }
    current_line = current_line->LRU_next;
  }

  // ----------------------命中 (HIT)----------------------
  if (target_line != NULL) {
    current_stat->accesses++;

    if (access_type == TRACE_DATA_STORE) {
      if (cache_writeback) {
        // [Write-Back]: 标记脏，不写内存
        target_line->dirty = TRUE;
      } else {
        // [Write-Through]: 立即写内存，cache保持干净
        current_stat->copies_back += 1;
        target_line->dirty = FALSE;
      }
    }

    // LRU 更新
    delete(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
           target_line);
    insert(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
           target_line);
  }

  // ------------------------缺失 (MISS) -----------------------
  else {
    current_stat->accesses++;
    current_stat->misses++;

    // [Write No-Allocate 逻辑]
    if (access_type == TRACE_DATA_STORE && !cache_writealloc) {
      current_stat->copies_back += 1;
      return; // 直接返回
    }

    // Fetch, 只有 Load Miss 或者 Store Miss + Write Allocate 才继续
    current_stat->demand_fetches += words_per_block;

    // 准备新数据
    Pcache_line new_line = (Pcache_line)malloc(sizeof(cache_line));
    new_line->tag = tag;
    new_line->LRU_next = NULL;
    new_line->LRU_prev = NULL;

    // Dirty处理
    if (access_type == TRACE_DATA_STORE) {
      if (cache_writeback) {
        // [Write-Back]: 载入后修改 -> 变脏
        new_line->dirty = TRUE;
      } else {
        // [Write-Through]: 载入后修改 -> 立即写内存
        current_stat->copies_back += 1;
        new_line->dirty = FALSE;
      }
    } else {
      new_line->dirty = FALSE; 
    }

    // 替换逻辑
    if (current_cache->set_contents[index] >= current_cache->associativity) {
      current_stat->replacements++;
      Pcache_line victim = current_cache->LRU_tail[index];

      // 检查写回
      if (victim->dirty) {
        current_stat->copies_back += words_per_block;
      }

      delete(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
             victim);
      free(victim);
    } else {
      current_cache->set_contents[index]++;
      current_cache->contents++;
    }

    // 插入新行
    insert(&current_cache->LRU_head[index], &current_cache->LRU_tail[index],
           new_line);
  }
}
/************************************************************/

/************************************************************/
/* 辅助函数：清理单个 Cache */
void flush_one_cache(Pcache c, Pcache_stat stat) {
  int i;
  Pcache_line current, next;
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
  if (cache_split) {
    flush_one_cache(icache, &cache_stat_inst);
    flush_one_cache(dcache, &cache_stat_data);
  } else {
    flush_one_cache(icache, &cache_stat_data);
  }
}
/************************************************************/

/************************************************************/
void delete(head, tail, item) Pcache_line *head, *tail;
Pcache_line item;
{
  if (item->LRU_prev)
    item->LRU_prev->LRU_next = item->LRU_next;
  else
    *head = item->LRU_next;

  if (item->LRU_next)
    item->LRU_next->LRU_prev = item->LRU_prev;
  else
    *tail = item->LRU_prev;
}
/************************************************************/

/************************************************************/
void insert(head, tail, item) Pcache_line *head, *tail;
Pcache_line item;
{
  item->LRU_next = *head;
  item->LRU_prev = NULL;
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