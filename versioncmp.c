#include "lich.h"

/*
 *
 * A simple lib that ensures some older variable names
 * now point to the updated names.  Its only purpose is
 * ensuring hassle-free backward compatibility and
 * implementing several global variable aliases for
 * some more "variable-like" character values.
 *
 */

static VALUE get_server()
{
	return rb_gv_get("$_SERVER_");
}

static VALUE get_client()
{
	return rb_gv_get("$_CLIENT_");
}

static VALUE get_client_buffer()
{
	return rb_gv_get("$_CLIENTBUFFER_");
}

static VALUE get_server_buffer()
{
	return rb_gv_get("$_SERVERBUFFER_");
}

static VALUE get_server_string()
{
	return rb_gv_get("$_SERVERSTRING_");
}

static VALUE get_client_string()
{
	return rb_gv_get("$_CLIENTSTRING_");
}

static void set_server(VALUE arg)
{
	rb_gv_set("$_SERVER_", arg);
}

static void set_client(VALUE arg)
{
	rb_gv_set("$_CLIENT_", arg);
}

static void set_client_buffer(VALUE arg)
{
	rb_gv_set("$_CLIENTBUFFER_", arg);
}

static void set_server_buffer(VALUE arg)
{
	rb_gv_set("$_SERVERBUFFER_", arg);
}

static void set_server_string(VALUE arg)
{
	rb_gv_set("$_SERVERSTRING_", arg);
}

static void set_client_string(VALUE arg)
{
	rb_gv_set("$_CLIENTSTRING_", arg);
}

static VALUE lich_health()
{
	return rb_eval_string("checkhealth()");
}

static VALUE lich_mana()
{
	return rb_eval_string("checkmana()");
}

static VALUE lich_spirit()
{
	return rb_eval_string("checkspirit()");
}

static VALUE lich_stamina()
{
	return rb_eval_string("checkstamina()");
}

static VALUE lich_maxhealth()
{
	return rb_eval_string("maxhealth()");
}

static VALUE lich_maxmana()
{
	return rb_eval_string("maxmana()");
}

static VALUE lich_maxspirit()
{
	return rb_eval_string("maxspirit()");
}

static VALUE lich_maxstamina()
{
	return rb_eval_string("maxstamina()");
}

void Init_versioncmp()
{
	rb_define_virtual_variable("$_PSINET_", get_client, set_client);
	rb_define_virtual_variable("$_PSINETSTRING_", get_client_string, set_client_string);
	rb_define_virtual_variable("$_PSINETBUFFER_", get_client_buffer, set_client_buffer);

	rb_define_virtual_variable("$_SIMU_", get_server, set_server);
	rb_define_virtual_variable("$_SIMUBUFFER_", get_server_buffer, set_server_buffer);
	rb_define_virtual_variable("$_SIMUSTRING_", get_server_string, set_server_string);

	rb_define_virtual_variable("$health", lich_health, 0);
	rb_define_virtual_variable("$mana", lich_mana, 0);
	rb_define_virtual_variable("$spirit", lich_spirit, 0);
	rb_define_virtual_variable("$stamina", lich_stamina, 0);
	
	rb_define_virtual_variable("$maxhealth", lich_maxhealth, 0);
	rb_define_virtual_variable("$maxmana", lich_maxmana, 0);
	rb_define_virtual_variable("$maxspirit", lich_maxspirit, 0);
	rb_define_virtual_variable("$maxstamina", lich_maxstamina, 0);
}
