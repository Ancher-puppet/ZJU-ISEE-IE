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
  // offset为块内偏移，由于按块寻找，所以这一部分忽略
  c1.index_mask_offset = LOG2(cache_block_size);
  // mask为掩码，后续与addr相与即可提取index
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
  // 计算index和tag, index = (addr & my_cache.index_mask) >>
  // my_cache.index_mask_offset 地址切分：tag || index || block offset
  // index掩码后移位
  index = (addr & c1.index_mask) >> c1.index_mask_offset;
  // tag 将addr舍弃掉offset和indexs
  tag = addr >> (c1.index_mask_offset + LOG2(c1.n_sets));

  // -----------如果set是空的，初始化状态------------
  if (c1.LRU_head[index] == NULL) {
    // 分配内存
    Pcache_line new_cache_line = (Pcache_line)malloc(sizeof(cache_line));
    // 填入数据
    new_cache_line->tag = tag;
    new_line->dirty = (access_type == TRACE_DATA_STORE) ? TRUE : FALSE;
    new_cache_line->LRU_next = NULL;
    new_cache_line->LRU_prev = NULL;
    // 将new_cache_line插入到LRU链表
    insert(&c1.LRU_head[index], &c1.LRU_tail[index], new_cache_line);
    // set内容数+1，总的内容数量+1，以判断该set是否已满员
    c1.set_contents[index]++;
    c1.contents++;

    // 统计数据
    if (access_type == TRACE_INST_LOAD) {
      cache_stat_inst.accesses++;
      cache_stat_inst.misses++;
      cache_stat_inst.demand_fetches += words_per_block;
    } else {
      cache_stat_data.accesses++;
      cache_stat_data.misses++;
      // 取内存数=取到的words数，每次取一个block
      cache_stat_data.demand_fetches += words_per_block;
    }
  }

  // ----------------如果set不是空的---------------------
  else {
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
    // -------------命中hit,此时target_line不为NULL-----
    if (target_line != (Pcache_line)NULL) {
      // 更新统计
      if (access_type == TRACE_INST_LOAD)
        cache_stat_inst.accesses++;
      else
        cache_stat_data.accesses++;

      // 处理写操作 (Dirty Bit)
      if (access_type == TRACE_DATA_STORE)
        target_line->dirty = TRUE;

      // LRU 更新：将命中行移至头部
      delete (&c1.LRU_head[index], &c1.LRU_tail[index], target_line);
      insert(&c1.LRU_head[index], &c1.LRU_tail[index], target_line);
    }
    // --------------未命中miss--------------------------
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
      // 填入数据
      new_cache_line->tag = tag;
      new_line->dirty = (access_type == TRACE_DATA_STORE) ? TRUE : FALSE;
      new_cache_line->LRU_next = NULL;
      new_cache_line->LRU_prev = NULL;
      // set已满员时,删除掉原来的数据,进行替换
      if (c1.set_contents[index] >= c1.associativity) {
        // 统计replacement
        if (access_type == TRACE_INST_LOAD)
          cache_stat_inst.replacements++;
        else
          cache_stat_data.replacements++;
        // 定义链表尾部
        Pcache_line victim = c1.LRU_tail[index];
        // 检查写回Write Back逻辑，Cache和Mem交互
        if (victim->dirty) {
          if (access_type == TRACE_INST_LOAD)
            cache_stat_inst.copies_back += words_per_block;
          else
            cache_stat_data.copies_back += words_per_block;
        }
        // 删除
        delete (&c1.LRU_head[index], &c1.LRU_tail[index], victim);
        // 释放内存，防止泄漏
        free(victim);
        insert(&c1.LRU_head[index], &c1.LRU_tail[index], new_cache_line);
      }
      // set未满员时，直接插入到头部
      else {
        // 将new_cache_line插入到LRU链表
        insert(&c1.LRU_head[index], &c1.LRU_tail[index], new_cache_line);
        c1.set_contents[index]++;
        c1.contents++;
      }
    }
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
void delete (head, tail, item)Pcache_line *head, *tail;
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
