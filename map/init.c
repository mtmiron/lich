#include "map.h"


int
initialize_allegro()
{
	if (install_allegro(SYSTEM_AUTODETECT,
	                    &errno, atexit) != 0)
		ERROR_EXIT();

	install_timer();
	install_keyboard();
	install_mouse();

	set_color_depth(8);
	if (set_gfx_mode(GFX_AUTODETECT_WINDOWED,
	                 800, 600, 0, 0) < 0)
		ERROR_EXIT();

	clear_bitmap(screen);
	show_mouse(screen);

	return 0;
}


int
initialize_internal()
{
	backbuffer = create_bitmap(screen->w, screen->h);
	if (!backbuffer)
		ERROR_EXIT();

	clear_bitmap(backbuffer);
	return 0;
}


int
program_init()
{
	initialize_allegro();
	initialize_internal();
	return 0;
}
