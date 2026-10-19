/*
 * cache.h
 */

#define TRUE 1
#define FALSE 0

/* default cache parameters--can be changed */
#define WORD_SIZE 4
#define WORD_SIZE_OFFSET 2
#define DEFAULT_CACHE_SIZE (8 * 1024)
#define DEFAULT_CACHE_BLOCK_SIZE 16
#define DEFAULT_CACHE_ASSOC 1
#define DEFAULT_CACHE_WRITEBACK TRUE
#define DEFAULT_CACHE_WRITEALLOC TRUE

/* constants for settting cache parameters */
#define CACHE_PARAM_BLOCK_SIZE 0
#define CACHE_PARAM_USIZE 1
#define CACHE_PARAM_ISIZE 2
#define CACHE_PARAM_DSIZE 3
#define CACHE_PARAM_ASSOC 4
#define CACHE_PARAM_WRITEBACK 5
#define CACHE_PARAM_WRITETHROUGH 6
#define CACHE_PARAM_WRITEALLOC 7
#define CACHE_PARAM_NOWRITEALLOC 8

/* structure definitions */
// 最小的数据单元
typedef struct cache_line_ {
  unsigned tag;
  int dirty;

  struct cache_line_ *LRU_next;
  struct cache_line_ *LRU_prev;
} cache_line, *Pcache_line;

// 整个 Cache 实体
typedef struct cache_ {
  int size;              /* cache size */
  int associativity;     /* cache associativity */
  int n_sets;            /* number of cache sets */
  unsigned index_mask;   /* mask to find cache index */
  int index_mask_offset; /* number of zero bits in mask */
  Pcache_line *LRU_head; // head of LRU list for each set
                         // 存放每一排的“头指针”（指向最新的书）
  Pcache_line *LRU_tail; // tail of LRU list for each set
                         // 存放每一排的“尾指针”（指向最老的书
  int *set_contents;     /* number of valid entries in set */
  int contents;          /* number of valid entries in cache */
} cache, *Pcache;

// 统计数据
typedef struct cache_stat_ {
  int accesses;       /* number of memory references */
  int misses;         /* number of cache misses */
  int replacements;   /* number of misses that cause replacments */
  int demand_fetches; // number of fetches 取内存次数
  int copies_back;    /* number of write backs */
} cache_stat, *Pcache_stat;

/* function prototypes */
void set_cache_param();
void init_cache();
void perform_access();
void flush();
void delete ();
void insert();
void dump_settings();
void print_stats();

/* macros */
#define LOG2(x) ((int)rint((log((double)(x))) / (log(2.0))))
