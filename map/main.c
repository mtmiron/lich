#include "map.h"


static char *help_text[] = {
	"ESCAPE: Exit.",
	"F1: This list.",
	"F4: File selection dialog -- add a file's data to the currently loaded map.",
	"BACKSPACE: File selection dialog -- clears currently loaded map before loading the new file's data.",
	"TAB: Next room (determined by ID number).",
	"UP/DOWN/LEFT/RIGHT: Scroll map.",
	"LEFT-CLICK ON A SQUARE: Highlight selection (detailed info shown).",
	"LEFT-CLICK OFF A SQUARE: Clear the highlighted selection (unhighlight any/all nodes).",
	"LEFT-CLICK+DRAG: Scroll map.",
	"RIGHT-CLICK: Center map on the position of the mouse cursor.",
	"ENTER/SPACEBAR: Center map on currently highlighted node.",
	"SHIFT+TAB: Previous room (again, by ID number).",
	"SHIFT+UP/DOWN/LEFT/RIGHT: Scroll map 5x speed.",
	"SHIFT+ENTER/SPACEBAR: Reset center of map to default position.",
	NULL,
};


/* currently selected node */
mapnode_t *selected_node;

int debugging;

/* should each node's (x,y) coords be reconstructed? */
int reconstruct_node_coords = 1;

/* node size (note that each
   side is 2x the length of
	this value) */
int rect_len = 2;
/* the largest ID */
int max_id;
int min_id;

/* color to highlight
   currently-selected-node */
int highlight_color = 40;
/* background color */
int bgc = 255;

/* yoffset (for scrolling around map) */
int yoffset = 0;
/* xoffset (again, for scrolling) */
int xoffset = 0;



void
mouse_cb(int flags)
{
	const int mickey_thresh = 4;
	static int ldown = 0;
	static int xmickey_buf = 0;
	static int ymickey_buf = 0;
	int i, n, xmickey = 0, ymickey = 0;
	int xmin, ymin, xmax, ymax;
	vector_t *noderange, *savlist;
	mapnode_t *hl_save;

	if (!nodelist)
		return;

	if (flags & MOUSE_FLAG_RIGHT_DOWN)
	{
		mapnode_t nd;
		memset(&nd, '\0', sizeof(nd));
		nd.x = mouse_x - xoffset;
		nd.y = mouse_y - yoffset;
		center_on_node(&nd);
		return;
	}

	if (!is_inside_bitmap(screen, mouse_x, mouse_y, 1))
		return;

	if (flags & MOUSE_FLAG_LEFT_DOWN)
	{
		hl_save = selected_node;
		selected_node = node_at_coords(mouse_x, mouse_y);
		highlight_node(selected_node, bgc);

		render_image(backbuffer);
		blit(backbuffer, screen, 0, 0, 0, 0, screen->w, screen->h);

		get_mouse_mickeys(&xmickey, &ymickey);
		ldown = 1;
	}
	else if (flags & MOUSE_FLAG_MOVE)
	{
		if (ldown)
		{
			get_mouse_mickeys(&xmickey, &ymickey);
			xoffset += xmickey;
			yoffset += ymickey;

			xmickey_buf += abs(xmickey);
			ymickey_buf += abs(ymickey);
			if ((xmickey_buf >= mickey_thresh) || (ymickey_buf >= mickey_thresh))
			{
				xmickey_buf = ymickey_buf = 0;
				render_image(backbuffer);
				blit(backbuffer, screen, 0, 0, 0, 0, screen->w, screen->h);
			}
		}
	}
	else if (flags & MOUSE_FLAG_LEFT_UP)
	{
		if (ldown)
		{
			get_mouse_mickeys(&xmickey, &ymickey);
			yoffset += ymickey;
			xoffset += xmickey;
			ldown = 0;
			render_image(backbuffer);
			blit(backbuffer, screen, 0, 0, 0, 0, screen->w, screen->h);
		}
	}
	else
		get_mouse_mickeys(&xmickey, &ymickey);

	return;
}
END_OF_FUNCTION(mouse_cb)


mapnode_t *
lookup_node_by_id(int queryid)
{
	int i, len;
	mapnode_t *nd;

//	len = vector_len(nodelist);
	for (i = 0; i < vector_len((vector_t *)nodelist); i++)
	{
		nd = vector_aref((vector_t *)nodelist, i);
		if (!nd)
			continue;
		if (nd->id == queryid)
			return nd;
	}

	return NULL;
}


void
handle_keypress(int k)
{
	int i, incval;
	char helpbuffer[65536];

	switch (k)
	{
		case KEY_ESC:
			allegro_exit();
			exit(0);
			break;

		case KEY_F1:
			memset(helpbuffer, '\0', sizeof(helpbuffer));
			for (i = 0; help_text[i] != NULL; i++)
			{
				strncat(helpbuffer, help_text[i], sizeof(helpbuffer) - strlen(helpbuffer));
				strncat(helpbuffer, "\n\n", sizeof(helpbuffer) - strlen(helpbuffer));
			}

			allegro_message("%s", helpbuffer);
			break;

		case KEY_BACKSPACE:
			free_mapnode_list((vector_t *)nodelist);
			nodelist = NULL;
			/* fall through */
		case KEY_F4:
			prompt_to_load_file();
			break;

		case KEY_UP:
			if (key[KEY_LSHIFT] || key[KEY_RSHIFT])
				yoffset += 20;
			yoffset += 5;
			break;

		case KEY_DOWN:
			if (key[KEY_LSHIFT] || key[KEY_RSHIFT])
				yoffset -= 20;
			yoffset -= 5;
			break;

		case KEY_RIGHT:
			if (key[KEY_LSHIFT] || key[KEY_RSHIFT])
				xoffset -= 20;
			xoffset -= 5;
			break;

		case KEY_LEFT:
			if (key[KEY_LSHIFT] || key[KEY_RSHIFT])
				xoffset += 20;
			xoffset += 5;
			break;

		case KEY_ENTER:
		case KEY_SPACE:
			if (key[KEY_LSHIFT] || key[KEY_RSHIFT])
				xoffset = yoffset = 0;
			else
				center_on_node(selected_node);
			break;

		case KEY_TAB:
			if (selected_node)
			{
				if (key[KEY_LSHIFT] || key[KEY_RSHIFT])
					incval = -1;
				else
					incval = +1;

				i = selected_node->id + incval;
				selected_node = lookup_node_by_id(i);
				for(; (!selected_node) && (i >= 0) && (i <= max_id); i += incval)
					selected_node = lookup_node_by_id(i);
			}
			else
			{
				if (key[KEY_LSHIFT] || key[KEY_RSHIFT])
				{
					if (! (selected_node = lookup_node_by_id(max_id)) )
						selected_node = vector_aref((vector_t *)nodelist, -1);
				}
				else
				{
					if (! (selected_node = lookup_node_by_id(min_id)) )
						selected_node = vector_aref((vector_t *)nodelist, 0);
				}
			}
			break;

		default:
			break;
	}
}

int
main(int argc, char *argv[])
{
	int k = 0;

	if ((chdir((char*)dirname(argv[0])) == -1))
		perror("chdir");

	/* ensure callback is always resident in RAM */
	LOCK_FUNCTION(mouse_cb);
	LOCK_VARIABLE(xoffset);
	LOCK_VARIABLE(yoffset);
	LOCK_VARIABLE(selected_node);

	/* kick things off */
	program_init();
	set_window_title(MAP_WINDOW_TITLE);
	enable_hardware_cursor();

	srand(time(NULL));
	scare_mouse();

	/* load any filenames specified (if any) */
	while (--argc > 0)
	{
		load_file(*++argv);
	}
	/* if we still have no nodelist, prompt for the file */
	if (!nodelist)
		prompt_to_load_file();

	mouse_callback = mouse_cb;

	render_image(backbuffer);
	blit(backbuffer, screen, 0, 0, 0, 0, screen->w, screen->h);

	unscare_mouse();

	while (k != KEY_ESC)
	{
//		if (keypressed())
		{
			k = (readkey() >> 8);
			handle_keypress(k);
		}

		render_image(backbuffer);
		blit(backbuffer, screen, 0, 0, 0, 0, screen->w, screen->h);
	}

	return 0;
}

END_OF_MAIN()
