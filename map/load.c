#include "map.h"



/* used to calculate offset of struct members */
static mapnode_t nodemap;

extern int reconstruct_node_coords;


/* as above */
static struct {
	char *s;
	void *d;
} stringmap[] = {
	{ "id", &nodemap.id},
	{ "title", &nodemap.title },
	{ "area", &nodemap.area },
	{ "geo", &nodemap.area },
	{ "x", &nodemap.x },
	{ "y", &nodemap.y },
	{ NULL, NULL },
};



/*
 * This is where we actually calc the offset of struct data.
 *
 * It's a confusing hack-job method of supporting arbitrary
 * text to assign to the corresponding struct members; still,
 * it's surprisingly smooth while executing.
 *
 * Basic principle is that each structure member gets a
 * text string and a memory pointer of itself stored
 * (this is done directly above).  When a matching text
 * string is found on a line in the file being loaded,
 * the memory offset of the struct member in question
 * is calculated by subtracting the base static-global
 * RAM addr of the `struct mapnode_st' identifier from
 * this file from the memory pointer tied to the text
 * (which was assigned directly above this comment).
 *
 * Strings should be in standard .ini file format, with
 * the notable exception of hash-symbols denoting comments;
 * e.g.:
 *
 * [1]	# ID
 * id = 1	# no harm in assigning it again
 * title = Town Square Central	# room title
 * area=Wehnimer's Landing		# room area
 * x=3	# x-axis value
 * y = 4		# y-axis value
 *
 * (etc.)
 *
 */
mapnode_t *
string_to_value(char *str, mapnode_t *nd)
{
	int i = 0, valpos;
	char *sav, *ptr, lhs[1024]={'\0'}, buf[65536]={'\0'}, rhs[65536]={'\0'};
	int idx;

	if (!str)
		return NULL;
	else if (! (sav = strchr(str, '=')) )
		return NULL;

	/* strip out comments */
	if ((ptr = strchr(str, '#')))
		while (*ptr != '\0')
			*ptr++ = '\0';
	ptr = sav;

	/* strip off leading whitespace from left-hand side */
	while ((*str == ' ') || (*str == '\t'))
		str++;
	snprintf(buf, sizeof(buf), "%s", str);
	ptr = (buf + (ptr - str));

	/* strip off leading whitespace from right-hand side */
	while ((*ptr == ' ') || (*ptr == '\t') || (*ptr == '='))
		ptr++, i++;

	/* strip off trailing whitespace from right-hand side */
	snprintf(rhs, sizeof(rhs), "%s", ptr);
	sav = ptr;
	for (ptr = (rhs + strlen(rhs) - 1);
	     *ptr == '\n' || *ptr == '\r' ||
	     *ptr == ' ' || *ptr == '\0'; ptr--)
		*ptr = '\0';
	ptr = (sav - i);

	/* strip off trailing whitespace from left-hand side */
	while ((*ptr == '=') || (*ptr == ' '))
		*ptr-- = '\0';
	snprintf(lhs, sizeof(lhs), "%s", buf);

	/* if this is the specially-handled "adj" string, push the rhs ID to the lhs' adj stack */
	if (strcasecmp(lhs, "adj") == 0)
	{
		ptr = strchr(rhs, ',');
		if (!ptr)
			return NULL;
		*ptr++ = '\0';
		return push_adj(nd, lookup_node_by_id(atoi(rhs)), ptr);
	}

	/* iterative string comparisons to look for a match */
	for (i = 0; stringmap[i].s != NULL; i++)
	{
		/* continue from top if not a match */
		if (strcasecmp(stringmap[i].s, lhs) != 0)
			continue;

		if (debugging)
			fprintf(stderr, "lhs: %s, buf: %s, rhs: %s.  changing ID from %d to %d\n", lhs, buf, rhs, nd->id, atoi(rhs));

		/* matching strings: store the memory offset of the struct member in question */
		for (idx = 0; (((void*)&nodemap) + idx) < ((void*)(stringmap[i].d)); idx++)
			/* we need to be certain we can't run amok scanning all addressable RAM */
			if ( (((void*)&nodemap) + idx) > ((void*)stringmap[i].d) )
				ERROR_EXIT();

		/* does this look like a numeric value? */
		if (isdigit(rhs[0]) || (rhs[0] == '-'))
			/* if so, assign it as an int */
			*((int*)(((void*)nd) + idx)) = atoi(rhs);
		else
			/* if not, assign it as a string */
			*( (char**)(((void*)nd) + idx) ) = strdup(rhs);

		/* the `struct mapnode_st *' passed as an argument has been assigned to -- now we return it */
		return nd;
	}

	/* we were unable to find a recognized match for this string's left-hand side; return NULL to indicate failure */
	return NULL;
}


void
free_mapnode_list(vector_t *list)
{
	if (list)
	{
		vector_foreach(list, free_mapnode_st);
		free(list);
	}
	max_id = min_id = 0;
}


vector_t *
new_mapnode_list(vector_t *list)
{
	free_mapnode_list(list);
	list = vector_new();
	if (!list)
		ERROR_EXIT();

	return list;
}


static void
pad_coords(void *vnode, int *xpad, int *ypad)
{
	mapnode_t *node;
	const int padding = rect_len * 3;

	node = (mapnode_t*)vnode;
	node->x = node->x + padding * ++(*xpad);
	node->y = node->y + padding * (*xpad);
}


static void
reconstruct_coordinates(vector_t *nodes)
{
	int qnt = rect_len*3; /* quantum (minimum space between nodes) */
	int i, j, len = vector_len(nodes);
	int xpad = 0, ypad = 0;
	mapnode_t *nd, *adj_nd;

	for (i = 0; i < len; i++)
	{
		nd = vector_aref(nodes, i);
		if (!nd || nd->touch)
			continue;
		nd->touch = 1;

		for (j = 0; nd->adj[j].nodeptr != NULL; j++)
		{
			adj_nd = nd->adj[j].nodeptr;
			if (adj_nd->touch)
//				continue;
//			adj_nd->touch = 1;

			switch (*nd->adj[j].movestr)
			{
				case 'n':
					adj_nd->y = nd->y+qnt;
					if (nd->adj[j].movestr[1] == 'e')
						adj_nd->x = nd->x+qnt;
					else if (nd->adj[j].movestr[1] == 'w')
						adj_nd->x = nd->x-qnt;
					break;

				case 'e':
					adj_nd->x = nd->x+qnt;
					break;

				case 's':
					adj_nd->y = nd->y-qnt;
					if (nd->adj[j].movestr[1] == 'e')
						adj_nd->x = nd->x+qnt;
					else if (nd->adj[j].movestr[1] == 'w')
						adj_nd->x = nd->x-qnt;
					break;

				case 'w':
					adj_nd->x = nd->x-qnt;
					break;

				default:
					adj_nd->x = nd->x+qnt;
					adj_nd->y = nd->y+qnt;
					break;
			}
		}
	}
}


vector_t *
load_file(char *fname)
{
	int i, sel_id, lineno = 0, ln = 1, tot = 0, prcnt = 0;
	int xpad = 0, ypad = 0;
	FILE *file;
	char buf[65536];
	mapnode_t *nd, *cur_node;

	/* setup variables */
	file = fopen(fname, "r");
	if (!file)
		ERROR_EXIT();

	if (selected_node)
		sel_id = selected_node->id;
	else
		sel_id = 0;

	if (!nodelist)
		nodelist = new_mapnode_list((vector_t *)nodelist);

	/* Get the total number of bytes (for percentage loaded display) */
	while (fgets(buf, sizeof(buf), file))
		ln += strlen(buf);
	tot = ln;
	ln = 1;
	rewind(file);

	/* read lines until EOF, setting values as specified */
	while (fgets(buf, sizeof(buf), file))
	{
		lineno++;
		if (*buf == '[')
		{
			if (!isdigit(buf[1]))
			{
				allegro_message("parse error:%s:%d:\n%s", fname, lineno, buf);
				if (fclose(file) == EOF)
					allegro_message("error closing file: %s", strerror(errno));

				return (vector_t *)nodelist;
			}

			cur_node = lookup_node_by_id(atoi(&buf[1]));
			if (cur_node)
				continue;

			cur_node = mapnode_new();
			cur_node->id = atoi(&buf[1]);
			vector_push((vector_t *)nodelist, (void*)cur_node);
		}
		/* parse this line and assign a value, if recognized */
		string_to_value(buf, cur_node);

		/* Display the current completion percentage */
		ln += strlen(buf);
		prcnt = (int)(100 / (tot / (float)ln));
		textprintf_ex(screen, font, 2, 2, 255, 0, "Loading: %d%%", prcnt);
	}

	/* ensure min_id and max_id are updated/accurate */
	for (i = 0; i < vector_len((vector_t *)nodelist); i++)
	{
		pad_coords(vector_aref((vector_t *)nodelist, i), &xpad, &ypad);

		cur_node = vector_aref((vector_t *)nodelist, i);
		if (cur_node->id > max_id)
			max_id = cur_node->id;
		if (cur_node->id < min_id)
			min_id = cur_node->id;
	}

	/* if there was previously a highlighted node, highlight any node w/
	   the same ID value as the old one (if the new list has such an ID) */
	if (sel_id)
		selected_node = lookup_node_by_id(sel_id);
	if (fclose(file) == EOF)
		allegro_message("error closing file: %s", strerror(errno));

	if (reconstruct_node_coords)
	{
		reconstruct_coordinates((vector_t *)nodelist);
	}

	strncpy(last_file, fname, sizeof(last_file));
	return (vector_t *)nodelist;
}


void
prompt_to_load_file()
{
	char msg[] = "Please select the map file you wish to load";
	char path[FILENAME_MAX * 6] = { "\0" };
	int result;

	mouse_callback = NULL;
	result = file_select_ex(msg, path, "txt", sizeof(path), 0, 0);
	if (!result)
	{
		if (nodelist != NULL && vector_len((vector_t*)nodelist) > 0)
			return;
		allegro_message("You did not select a file to load: there's nothing for the program to do.  Exiting.");
		exit(0);
	}

	if (debugging)
		fprintf(stderr, "%s\n", path);
	nodelist = load_file(path);

	render_image(screen);
	render_image(backbuffer);
	render_info(screen);
	render_info(backbuffer);
	strncpy(last_file, path, sizeof(last_file));
	mouse_callback = mouse_cb;
}
