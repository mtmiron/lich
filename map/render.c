#include "map.h"


BITMAP *backbuffer;
volatile vector_t *nodelist;
char last_file[FILENAME_MAX];


void
render_info(BITMAP *bmp)
{
	char buf[256];

	scare_mouse();

	rectfill(bmp, 0, bmp->h - 16, bmp->w/2, bmp->h, bgc);
	rectfill(bmp, bmp->w/3, 0, (int)bmp->w*.66, 10, bgc);

	if (selected_node)
	{
		snprintf(buf, sizeof(buf), "%s: %s (ID: %d   coord: %d,%d)",
		         (selected_node->area?selected_node->area:"(unknown area)"),
		         (selected_node->title?selected_node->title:"(unknown title)"),
		         selected_node->id, selected_node->x, selected_node->y);

		textprintf_centre_ex(bmp, font, bmp->w/2, 2, 0, -1, "%s",
		                     buf);
		hline(bmp, bmp->w/2 - text_length(font, buf)/2, 10,
		      bmp->w/2 + text_length(font, buf)/2, 0);

		highlight_node(selected_node, highlight_color);
	}

	textprintf_ex(bmp, font, 2, (bmp->h - 8) - 2 - text_height(font), 0, -1,
		              "Center: %d,%d", (int)(bmp->w/2.0+xoffset), (int)(bmp->h/2.0+yoffset));
	textprintf_ex(bmp, font, 2, bmp->h - 8, 0, -1,
		              "Mouse: %d,%d", mouse_x+xoffset, mouse_y+yoffset);

	if (last_file)
	{
		snprintf(buf, sizeof(buf), "Most recent file: \"%s\"   (%d nodes total)", last_file, vector_len((vector_t *)nodelist));
		rectfill(bmp, text_length(font, buf), bmp->h - text_height(font), bmp->w, bmp->h, bgc);

		textprintf_right_ex(bmp, font, bmp->w, bmp->h-10, 0, -1, "%s", buf);
	}

	unscare_mouse();
}


void
highlight_node(mapnode_t *nd, int color)
{
	int l = rect_len;

	if (!nd)
		return;

	rectfill(screen, nd->x-l+xoffset, nd->y-l+yoffset,
	     nd->x+l+xoffset, nd->y+l+yoffset, color);
	rectfill(backbuffer, nd->x-l+xoffset, nd->y-l+yoffset,
	     nd->x+l+xoffset, nd->y+l+yoffset, color);
/*	rect(screen, selected_node->x-l+xoffset,
	     selected_node->y-l+yoffset,
	     selected_node->x+l+xoffset,
	     selected_node->y+l+yoffset,
	     color); */
}


mapnode_t *
node_at_coords(int parmx, int parmy)
{
	int x, y, ndx, ndy, i;
	int sz = rect_len+1;// len = vector_len(nodelist);
	mapnode_t *nd;

	/* handle multiple nodes at the same position (return next in list) */
	i = vector_find((vector_t *)nodelist, selected_node) + 1;

	for (; i < vector_len((vector_t *)nodelist); i++)
	{
		nd = vector_aref((vector_t *)nodelist, i);
		if (!nd)
			continue;

		ndx = nd->x;
		ndy = nd->y;

		for (x = -sz; x <= sz; x++)
		{
			for (y = -sz; y <= sz; y++)
			{
				if ((ndx + x + xoffset == parmx) &&
				    (ndy + y + yoffset == parmy))
				{
					if ((selected_node != NULL) && (selected_node == nd))
						goto skip;
					else
						return nd;
				}
			}
		}
		skip:
			continue;
	}

	if ((selected_node != NULL))
	{
		selected_node = NULL;
		return node_at_coords(parmx, parmy);
	}

	return NULL;
}


void
center_on_node(mapnode_t *nd)
{
	if (!nd)
		nd = selected_node;
	if (!nd)
		return;

	yoffset = screen->h/2 - nd->y;
	xoffset = screen->w/2 - nd->x;

	render_image(screen);
}


mapnode_t *
mapnode_new()
{
	mapnode_t *ptr;

	ptr = calloc(1, sizeof(mapnode_t));
	if (!ptr)
		ERROR_EXIT();

	ptr->adj = calloc(1, sizeof(struct adj_st));
	if (!ptr->adj)
		ERROR_EXIT();

	return ptr;
}


int
free_mapnode_st(void *voidptr)
{
	int i;
	mapnode_t *node;

	node = (mapnode_t*)voidptr;

	for (i = 0; node->adj[i].nodeptr != NULL; i++)
		free(node->adj[i].movestr);

	free(node->adj);
	free(node->title);
	node->title = NULL;
	node->adj = NULL;

	free(node);
	return VECTOR_CONTINUE;
}


mapnode_t *
push_adj(mapnode_t *dest, mapnode_t *src, char *str)
{
	int i;

	for (i = 0; dest->adj[i].nodeptr != NULL; i++); /* null */

	dest->adj = realloc(dest->adj, sizeof(struct adj_st) * (i + 2));
	if (!dest->adj)
		ERROR_EXIT();

	dest->adj[i].nodeptr = src;
	if (str)
		dest->adj[i].movestr = strdup(str);

	dest->adj[++i].nodeptr = NULL;
	dest->adj[i].movestr = NULL;

	return dest;
}


int
render_image(BITMAP *canvas)
{
	int color = 0, linecolor = 55;
	int i, j, len, sz = rect_len;
	int minx, miny, maxx, maxy;
	mapnode_t *nd;

	minx = 0 - xoffset;
	miny = 0 - yoffset;
	maxx = canvas->w - xoffset;
	maxy = canvas->h - yoffset;

	scare_mouse();

	if (!canvas)
		canvas = backbuffer;
	if (!canvas)
		ERROR_EXIT();

	clear_to_color(canvas, bgc);
	len = vector_len((vector_t *)nodelist);

	for (i = 0; i < len; i++)
	{
		nd = vector_aref((vector_t *)nodelist, i);
		if (!nd)
			continue;

		/* ensure the node is in current screen bounds */
		if ((nd->x < minx) || (nd->y < miny))
			continue;
		else if ((nd->x > maxx) || (nd->y > maxy))
			continue;

		/* draw the connections to adjacent rooms */
		for (j = 0; nd->adj[j].nodeptr != NULL; j++)
		{
			/* restrict lines drawn to those ending in on-screen nodes only */
			if (nd->adj[j].nodeptr->x < minx)
				continue;
			else if (nd->adj[j].nodeptr->y < miny)
				continue;
			else if (nd->adj[j].nodeptr->x > maxx)
				continue;
			else if (nd->adj[j].nodeptr->y > maxy)
				continue;

			line(canvas, nd->x+xoffset, nd->y+yoffset,
			     nd->adj[j].nodeptr->x+xoffset,
			     nd->adj[j].nodeptr->y+yoffset,
              linecolor);
		}
	}

	/* draw the rectangles representing each on-screen node */
	for (i = 0; i < len; i++)
	{
		nd = vector_aref((vector_t *)nodelist, i);
		if (!nd)
			continue;
		else if ((nd->x < minx) || (nd->y < miny))
			continue;
		else if ((nd->x > maxx) || (nd->y > maxy))
			continue;

		rectfill(canvas, nd->x-sz+xoffset, nd->y-sz+yoffset,
		     nd->x+sz+xoffset, nd->y+sz+yoffset, color);
	}

	/* make sure the selected node always has
	   all adjacent rooms drawn as connections */
	if (selected_node)
	{
		nd = selected_node;
		for (j = 0; nd->adj[j].nodeptr != NULL; j++)
		{
			line(canvas, nd->x+xoffset, nd->y+yoffset,
			     nd->adj[j].nodeptr->x+xoffset,
	   		  nd->adj[j].nodeptr->y+yoffset,
		   	  highlight_color);
		}
	}

	render_info(canvas);
	return 0;
}
