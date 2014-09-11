#ifndef MAP_H_INCLUDED
#define MAP_H_INCLUDED

#include <allegro.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#include "vector.h"

#ifdef __cplusplus
#	define ANYARGS ...
#else
#	define ANYARGS
#endif

#define ERROR_EXIT() do {	\
	allegro_message("%s\n%s", strerror(errno), allegro_error);	\
	allegro_exit();	\
	exit(1);	\
} while (0)

#define MAP_WINDOW_TITLE "MapRenderer"


typedef struct mapnode_st {
	unsigned long id;
	char *title;
	char *area;
	int x, y;

	struct adj_st {
		struct mapnode_st *nodeptr;
		char *movestr;
	} *adj;

	unsigned char touch : 1;

} mapnode_t;

extern BITMAP *backbuffer;
extern volatile vector_t *nodelist;
extern mapnode_t *selected_node;
extern int bgc, min_id, max_id, debugging, rect_len, highlight_color, xoffset, yoffset;
extern char last_file[FILENAME_MAX];

mapnode_t *push_adj(mapnode_t *, mapnode_t *, char *);

mapnode_t *lookup_node_by_id(int);

mapnode_t *mapnode_new();
int free_mapnode_st(void *);
void free_mapnode_list(vector_t *);

mapnode_t *string_to_value(char *, mapnode_t *);

mapnode_t *node_at_coords(int, int);
void highlight_node(mapnode_t *, int);
void center_on_node(mapnode_t *);

void render_info(BITMAP *);
int render_image(BITMAP *);

vector_t *load_file(char *);
vector_t *load_rb_file(char *);

void mouse_cb(int);

int initialize_allegro();
int initialize_internal();
int program_init();


#endif /* ifndef MAP_H_INCLUDED */
