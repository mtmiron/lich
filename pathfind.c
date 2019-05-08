/********************************************************************************
*  Standard new-style BSD license follows:
*
*
*  Copyright (C) 2005-2006 Murray Miron.
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without
*  modification, are permitted provided that the following conditions
*  are met:
*
*	Redistributions of source code must retain the above copyright
*  notice, this list of conditions and the following disclaimer.
*
*	Redistributions in binary form must reproduce the above copyright
*  notice, this list of conditions and the following disclaimer in the
*  documentation and/or other materials provided with the distribution.
*
*	Neither the name of the organization nor the names of its contributors
*  may be used to endorse or promote products derived from this software
*  without specific prior written permission.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
*  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
*  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
*  A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER
*  OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
*  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
*  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
*  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
*  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
*  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
*  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
********************************************************************************/


/*
 *  Ruby extension library for performing pathfinding.
 *  Written for the Lich project.  Last update to this: Lich v3.46, 2006-12-06.
 *
 *
 *  There are three algorithms, two of which function in tandem to
 *  make up the "estimated distance" method, which is efficient but
 *  may not find the shortest route; the third involves no spatial
 *  estimation of any kind and is less efficient, but is guaranteed
 *  to find the shortest possible route.
 *
 *  (2019-05-08: note that the A*Star algorithm mentioned above is broken
 *     because I screwed up by overestimating the cost of some paths).
 *
 *  You'll probably want to use the Map class from "lich-libmap.rb,"
 *  but it isn't necessary: use it only as an example for your own
 *  implementation if desired.
 *
 *	call-seq:
 *		require 'pathfind'
 *		class YourClass
 * 		include Pathfind				# Include the Pathfind module in the class
 * 		def get_wayto(node_id)		# The library calls this method of your class so it can graph the spatial relationship of the nodes
 * 			if @wayto[node_id] == "north" then return Pathfind::N				# if `node_id' is north of the current node, `1' should be returned
 * 			elsif @wayto[node_id] == "northeast" then return Pathfind::NE	# else if `node_id' is northeast of the current node, '2' should be returned
 * 			elsif @wayto[node_id] == "east" then return Pathfind::E			# etc.
 *				elsif @wayto[node_id] == "southeast" then return Pathfind::SE
 * 			elsif @wayto[node_id] == "south" then return Pathfind::S
 * 			elsif @wayto[node_id] == "southwest" then return Pathfind::SW
 * 			elsif @wayto[node_id] == "west" then return Pathfind::W
 * 			elsif @wayto[node_id] == "northwest" then return Pathfind::NW
 * 			else return Pathfind::NODIR												# If there's no way to accurately judge a spatial direction, anything else will do
 * 			end
 * 		end
 *			(... any other methods you want for this class would be here ...)
 *		end
 *
 *		obj = YourClass.new
 *		obj2 = YourClass.new
 *		obj3 = YourClass.new
 *		obj.mknode						# => true (this tells the Pathfinding module to add this Ruby object to its internal list of nodes)
 *		obj.inspect						# => [ @id=1, @title=nil, @desc=nil, @paths=nil, @wayto={} ]
 *		obj2.mknode; obj3.mknode	# (tell the Pathfinding module these should also be internally tracked as nodes)
 * 	obj2.inspect					# => [ @id=2, @title=nil, @desc=nil, @paths=nil, @wayto={} ]
 *		obj.wayto[3] = "northeast"	# => "northeast" (set how to get from node1 to node3, which need not be a string)
 *		obj3.wayto[2] = "south"		# => "south" (and now set how to get from node3 to node2)
 *		obj.inspect						# => [ @id=1, @title=nil, @desc=nil, @paths=nil, @wayto={3=>"northeast"} ]
 *		obj3.inspect					# => [ @id=3, @title=nil, @desc=nil, @paths=nil, @wayto={2=>"south"} ]
 *		Pathfind.reassoc_nodes		# => true (tells the Pathfind module to make sure all nodes are traced and properly connected)
 *		Pathfind.trace_field_positions	# => nil (create the internal representation of spatial relationships -- i.e., estimate distances)
 *		Pathfind.list					# => [ obj, obj2, obj3 ] (this returns an array consisting of all the nodes you've added)
 *		path = obj.pathfind(obj2)	# => [ 1, 3, 2 ] (this returns the IDs of the 'steps' on the shortest route the pathfinding library was able to find)
 *		Pathfind.find_node(1)		# =>  obj
 *		Pathfind.find_node(3)		# =>  obj3
 *		Pathfind.find_node(2)		# =>  obj2
 * 	until path.length <= 1
 * 		node_id = path.shift
 * 		node = Pathfind.find_node(node_id)
 * 		puts "go " + node.wayto[path.first]
 * 	end
 * 	puts "... and you're there."
 *
 *
 * 	Output would be:
 * 		go northeast
 * 		go south
 * 		... and you're there.
 *
 *		<code>obj.pathfind(obj3)</code> returns the IDs of the 'steps' on the way to your destination.
 *
 * 	Notes:
 * 		<code>@wayto</code> is a hash of any object who's class has had the <code>Pathfind</code> module included in it.
 *			Since it's a hash, you can override the <code>Pathfind</code> module's default ID numbering of the nodes in
 * 		anyway you please by setting each node's ID to whatever suits your purposes, for example, <code>node.id = "5"</code>
 * 		and then calling the <code>Pathfind.reassoc_nodes</code> method.  As long as you manually define the
 * 		<code>get_wayto</code> in any class you include the <code>Pathfind</code> module in (and you setup
 * 		the integer return values properly -- see below), you can use or not use pretty much whatever you need.
 *
 * 	Integer map for the <code>get_wayto</code> return value (so that the <code>Pathfind</code> module can graph nodes):
 *     1
 *   8   2
 *  7     3
 *	  6   4
 *     5
 * 9 == impossible to classify this particular "movement" as conforming to a 2-dimensional cardinal direction
 */

#include "lich.h"
#include "st.h"


#ifdef __cplusplus
	extern "C" {
#endif

// Data type for keeping track of how many nodes are adjacent to the current one; an unsigned short allows 65535 max
#define MXADJTYPE unsigned short
// Max number of adjacent rooms: 16 bits (a short is 2 bytes) means 2 to the 16th power possible values
#define MXADJNUM 65535

// Causes a CPU-intensive algorithm that's guaranteed to return the shortest possible path to be compiled in
#ifndef GUARANTEED_SHORTEST_ALGORITHM
#	define GUARANTEED_SHORTEST_ALGORITHM
#endif

// Commenting out one of these will slightly increase the speed of pathfinding at the cost of finding a longer route
#define DO_SEQ_PFIND	1 // Simple sequential search, ignores estimated distance
#define DO_DIST_PFIND 1	// Estimates which room is closer to the destination and checks the closest ones first

// Diagonal movements in GemStone IV have the same "cost" as any other move (going NE is just 1 room, the same as going E is) -- so we need a heuristic that takes that into account; part of which is our brain-dead MAX macro here ;)
#define MAX(a,b) ((a) > (b) ? (a) : (b))


// Used to place each area/room/node on the (imaginary) graph -- allows X- and Y-axes values to be assigned to a room
enum dir { NODIR, N, NE, E, SE, S, SW, W, NW, UP, DN };

typedef struct lich_area {
	unsigned long id;
	int x, y;
	unsigned char searched;
	struct lich_area **adj;
	MXADJTYPE nadj;
	VALUE rb_obj;
#ifdef GUARANTEED_SHORTEST_ALGORITHM
	struct lich_area *parent;
	int realcost;
#endif
} Area;


static int unique_coords = 0;
static st_table *x_tbl;
static Area **ptrbuf, *nodes;
static unsigned long slist, ulist, glist, numnodes;
extern VALUE lich_mPathfind;


static Area *find_node_by_value(VALUE self);
static Area *find_node_by_id_c(unsigned long id);
static inline void reap_area(Area *ptr);
static unsigned char recursive_pfind(Area *ostruct, const Area *dstruct, VALUE *path);
static unsigned char recursive_pfind_unsorted(Area *ostruct, const Area *dstruct, VALUE *path);
static void reset_flags();
static void mark_adj_field_positions(Area *origin);
static void trace_paths_from_node(Area *node);
void Init_pathfind();


VALUE mknode(VALUE self)
{
	ptrbuf = (Area **)(REALLOC_N(nodes, Area, numnodes + 1));
	if (!ptrbuf) rb_raise(rb_eNoMemError, "out of memory");
	nodes = (Area *)ptrbuf;
	nodes[numnodes].id = NUM2ULONG(rb_iv_get(self, "@id"));
	if (NIL_P(nodes[numnodes].id)) nodes[numnodes].id = numnodes;
#ifdef GUARANTEED_SHORTEST_ALGORITHM
	nodes[numnodes].parent = NULL;
	nodes[numnodes].realcost = -1;
#endif
	nodes[numnodes++].rb_obj = self;
	return self;
}

/* Make a reference to a node at this (X,Y) coordinate */
static void
coordinate_insert(Area *node, int co_x, int co_y)
{
	st_table *y_tbl;

	if (!st_lookup(x_tbl, (st_data_t)co_x, (st_data_t *)&y_tbl))
	{
		y_tbl = st_init_numtable();
		st_insert(x_tbl, (st_data_t)co_x, (st_data_t)y_tbl);
	}
	st_insert(y_tbl, (st_data_t)co_y, (st_data_t)node);
	if (unique_coords)
	{
		node->x = co_x;
		node->y = co_y;
	}
}

/* If there's already an entry for this (X,Y) coordinate,
   shift the existing entry up by calling ourself recursively
	(thereby causing a chain of recursive calls to shift all
	previously existing nodes up until we hit an empty (X,Y)
	coordinate). */
static void
finalize_coordinate(Area *node, int co_x, int co_y)
{
	st_table *y_tbl;
	Area *existing_node;
	int flag;

	flag = st_lookup(x_tbl, (st_data_t)co_x, (st_data_t *)&y_tbl);
	if (!flag)
		goto insert;
	
	flag = st_lookup(y_tbl, (st_data_t)co_y, (st_data_t *)&existing_node);
	if (!flag)
		goto insert;

	/* Shift the prior node at this (X,Y) pair
	   up an X or a Y, whichever value is lower */
	if (co_x > co_y)
		finalize_coordinate(existing_node, co_x, co_y + 1);
	else
		finalize_coordinate(existing_node, co_x + 1, co_y);
	/* fall through */
	insert:
		coordinate_insert(node, co_x, co_y);
		return;
}
	
static inline void reassoc_nodes_internal(VALUE self)
{
	register unsigned long i, j;
	VALUE list = rb_cv_get(lich_mPathfind, "@@list");
	VALUE *ptr = RARRAY(list)->ptr;

	for (i = 0; i < numnodes; i++)
	{
		reap_area(&nodes[i]);	// Make sure we avoid memory leaks
	}
	numnodes = RARRAY(list)->len;
	ptrbuf = (Area **)(REALLOC_N(nodes, Area, numnodes));
	nodes = (Area *)ptrbuf;
	for (i = 0; i < numnodes; i++)
	{
		nodes[i].id = NUM2ULONG(rb_iv_get(ptr[i], "@id"));
		if (NIL_P(nodes[i].id))
			nodes[i].id = i;
#ifdef GUARANTEED_SHORTEST_ALGORITHM
		nodes[i].parent = NULL;
		nodes[i].realcost = -1;
#endif
		nodes[i].rb_obj = ptr[i];
		nodes[i].x = 0, nodes[i].y = 0;
		nodes[i].searched = 0;
		nodes[i].nadj = 0;
		if (NIL_P(nodes[i].id)) nodes[i].id = i;
	}
	for (i = 0; i < numnodes; i++)
	{
		list = rb_funcall(rb_iv_get(nodes[i].rb_obj, "@wayto"), rb_intern("keys"), 0);
		nodes[i].nadj = RARRAY(list)->len;
		ptrbuf = (Area **)ALLOC_N(Area *, nodes[i].nadj);
		nodes[i].adj = ptrbuf;
		for (j = 0; j < nodes[i].nadj; j++)
		{
			nodes[i].adj[j] = find_node_by_id_c(NUM2ULONG(rb_funcall(RARRAY(list)->ptr[j], rb_intern("to_i"), 0)));
		}
	}
}

static VALUE reassoc_nodes(VALUE self)
{
	reassoc_nodes_internal(self);
	return Qtrue;
}

static VALUE trace_field_positions(VALUE self)
{
	int i;

	for (i = 0; i < numnodes; i++)
	{
		mark_adj_field_positions(&nodes[i]);
	}
	reset_flags();
	return Qnil;
}

static VALUE find_node_by_id(VALUE self, VALUE id)
{
	register unsigned long i;

	id = NUM2ULONG(id);
	for (i = 0; i < numnodes; i++)
	{
		if (nodes[i].id == id)
			return nodes[i].rb_obj;
	}
	return Qnil;
}


Area *find_node_by_id_c(unsigned long id)
{
	register unsigned long i;

	for (i = 0; i < numnodes; i++)
	{
		if (nodes[i].id == id)
			return &nodes[i];
	}
	rb_raise(rb_eException, "Cannot find structure for room #%ld", id);
}


static Area *find_node_by_value(VALUE self)
{
	register unsigned long i;

	for (i = 0; i < numnodes; i++)
	{
		if (nodes[i].rb_obj == self)
			return &nodes[i];
	}
	rb_raise(rb_eException, "Ruby object has not been marked with a node: `%s'", rb_id2name(self));
}


VALUE mark_adj(VALUE self, VALUE adj)
{
	Area *adjstruct, *slfstruct;

	slfstruct = find_node_by_value(self);
	adjstruct = find_node_by_value(adj);
	if (slfstruct->nadj >= MXADJNUM)
		rb_raise(rb_eNoMemError, "This area already references the maximum number of adjacent areas (%d)!", MXADJNUM);
	ptrbuf = (Area **)(REALLOC_N(slfstruct->adj, Area *, slfstruct->nadj + 1));
	slfstruct->adj = ptrbuf;
	slfstruct->adj[slfstruct->nadj] = adjstruct;
	slfstruct->nadj++;
	return Qtrue;
}


static inline void reap_area(Area *ptr)
{
	free(ptr->adj);
	ptr->adj = NULL;
	ptr->nadj = 0;
	return;
}


static VALUE clear_cache(VALUE self)
{
	VALUE ary;

	while (numnodes)
	{
		reap_area(&nodes[--numnodes]);
	}
	free(nodes);
	nodes = NULL;

	rb_funcall(rb_cv_get(lich_mPathfind, "@@list"), rb_intern("clear"), 0);
	rb_cv_set(lich_mPathfind, "@@list", rb_ary_new());
	rb_gc();
	return Qnil;
}


static VALUE clear_adj(VALUE self)
{
	register unsigned long i;

	for (i = 0; i < numnodes; i++)
	{
		if (nodes[i].rb_obj == self && nodes[i].nadj) {
			reap_area(&nodes[i]);
			return Qtrue;
		}
	}
	return Qnil;
}


VALUE mark_field_position(VALUE self, VALUE x, VALUE y)
{
	Area *ptr = find_node_by_value(self);

	ptr->x = FIX2INT(x);
	ptr->y = FIX2INT(y);
	finalize_coordinate(ptr, x, y);
	mark_adj_field_positions(ptr);
	reset_flags();
	return self;
}


static void mark_adj_field_positions(Area *origin)
{
	MXADJTYPE i;

	if (origin->searched)
		return;
	origin->searched = 1;

	for (i = 0; i < origin->nadj; i++)
	{
		switch (FIX2INT(rb_funcall(origin->rb_obj, rb_intern("get_wayto"), 1, ULONG2NUM(origin->adj[i]->id))))
		{
			case N:
				origin->adj[i]->x = origin->x;
				origin->adj[i]->y = origin->y + 1;
				break;
			case NE:
				origin->adj[i]->x = origin->x + 1;
				origin->adj[i]->y = origin->y + 1;
				break;
			case E:
				origin->adj[i]->x = origin->x + 1;
				origin->adj[i]->y = origin->y;
				break;
			case SE:
				origin->adj[i]->x = origin->x + 1;
				origin->adj[i]->y = origin->y - 1;
				break;
			case S:
				origin->adj[i]->x = origin->x;
				origin->adj[i]->y = origin->y - 1;
				break;
			case SW:
				origin->adj[i]->x = origin->x - 1;
				origin->adj[i]->y = origin->y - 1;
				break;
			case W:
				origin->adj[i]->x = origin->x - 1;
				origin->adj[i]->y = origin->y;
				break;
			case NW:
				origin->adj[i]->x = origin->x - 1;
				origin->adj[i]->y = origin->y + 1;
				break;
			default:	// No way to know, just increment the node's X- and Y-axes values
				if (!(origin->adj[i]->x || origin->adj[i]->y)) {
					origin->adj[i]->x = origin->x + 1;
					origin->adj[i]->y = origin->y + 1;
				}
				break;
		}
		finalize_coordinate(origin->adj[i], origin->adj[i]->x, origin->adj[i]->y);
	}
	for (i = 0; i < origin->nadj; i++)
	{
		mark_adj_field_positions(origin->adj[i]);
	}
	return;
}


VALUE pathfind(VALUE self, VALUE destination)
{
	VALUE path = rb_ary_new(), unpath = rb_ary_new();
	Area *ostruct, *dstruct;
	
	ostruct = find_node_by_value(self);
	dstruct = find_node_by_value(destination);
	slist = 0, ulist = 0;
#if defined(DO_SEQ_PFIND) && defined(DO_DIST_PFIND)
	if (recursive_pfind(ostruct, dstruct, &path)) {
		reset_flags();
		if (recursive_pfind_unsorted(ostruct, dstruct, &unpath)) {
			if (RARRAY(unpath)->len < RARRAY(path)->len) {
				reset_flags();
				return rb_funcall(unpath, rb_intern("reverse"), 0);
			}
			reset_flags();
			return rb_funcall(path, rb_intern("reverse"), 0);
		}
		reset_flags();
		return rb_funcall(path, rb_intern("reverse"), 0);
	}
	reset_flags();
	return Qnil;
#else
# ifdef DO_SEQ_PFIND
	if (recursive_pfind_unsorted(ostruct, dstruct, &unpath)) {
		reset_flags();
		return rb_funcall(unpath, rb_intern("reverse"), 0);
	}
	reset_flags();
	return Qnil;
# else
	if (recursive_pfind(ostruct, dstruct, &path)) {
		reset_flags();
		return rb_funcall(path, rb_intern("reverse"), 0);
	}
	reset_flags();
	return Qnil;
# endif
#endif
}


static void reset_flags()
{
	register unsigned long i;

	for (i = 0; i < numnodes; i++)
	{
		nodes[i].searched = 0;
#ifdef GUARANTEED_SHORTEST_ALGORITHM
		nodes[i].parent = NULL;
		nodes[i].realcost = -1;
#endif
	}
	return;
}


static unsigned char recursive_pfind_unsorted(Area *ostruct, const Area *dstruct, VALUE *path)
{
	MXADJTYPE i;

	if (ostruct->searched)
		return 0;
	ostruct->searched = 1;
	ulist++;
	for (i = 0; i < ostruct->nadj; i++)
	{
		if (ostruct->adj[i]->id == dstruct->id) {
			return 1;
		}
	}
	for (i = 0; i < ostruct->nadj; i++)
	{
		if (recursive_pfind_unsorted(ostruct->adj[i], dstruct, path)) {
			rb_ary_push(*path, ULONG2NUM(ostruct->adj[i]->id));
			return 1;
		}
	}
	return 0;
}


static unsigned char recursive_pfind(Area *ostruct, const Area *dstruct, VALUE *path)
{
	MXADJTYPE i, j;
	signed long buf;
	signed long distance[ostruct->nadj];
	Area *sorted[ostruct->nadj];

	if (ostruct->searched)
		return 0;
	ostruct->searched = 1;
	slist++;
	for (i = 0; i < ostruct->nadj; i++)
	{
		if (ostruct->adj[i]->id == dstruct->id)
			return 1;
		distance[i] = MAX(labs(dstruct->x - ostruct->adj[i]->x), labs(dstruct->y - ostruct->adj[i]->y));
		sorted[i] = ostruct->adj[i];
	}
	for (j = 0; j < ostruct->nadj; j++)
	{
		for (i = 1; i <= j; i++)
		{
			if (distance[i] < distance[(i - 1)]) {
				buf = distance[(i - 1)];
				ptrbuf = (Area **)sorted[(i - 1)];
				sorted[(i - 1)] = sorted[i];
				sorted[i] = (Area *)ptrbuf;
				distance[(i - 1)] = distance[i];
				distance[i] = buf;
			}
		}
	}
	for (i = 0; i < ostruct->nadj; i++)
	{
		if (recursive_pfind(sorted[i], dstruct, path)) {
			rb_ary_push(*path, ULONG2NUM(sorted[i]->id));
			return 1;
		}
	}
	return 0;
}


#ifdef GUARANTEED_SHORTEST_ALGORITHM
static inline int estimate_distance(Area *current, Area *destination)
{
	int xcost = labs(destination->x - current->x);
	int ycost = labs(destination->y - current->y);
	return MAX(xcost, ycost);
}

static void touch_node(Area *nodef)
{
	int i;
	Area *adjf;

	for (i = 0; i < nodef->nadj; i++)
	{
		adjf = nodef->adj[i];
		if (adjf->realcost < 0)  /* Node is being 'traced' for the first time */
		{
			adjf->parent = nodef;
			adjf->realcost = nodef->realcost + 1;
		}
		else if (adjf->realcost > nodef->realcost + 1)  /* Is this path's cost less than the previously found one? */
		{
			adjf->parent = nodef;
			adjf->realcost = nodef->realcost + 1;
			/* Reevaluate the cost of all nodes adjacent to this one (since the path being traced is cheaper than the previous one) */
			adjf->searched = 0;
			trace_paths_from_node(adjf);
		}
	}
}

static void trace_paths_from_node(Area *nodef)
{
	int i;

	if (nodef->searched)
		return;
	touch_node(nodef);
	glist++;
	nodef->searched = 1;
	for (i = 0; i < nodef->nadj; i++)
	{
		trace_paths_from_node(nodef->adj[i]);
	}
}

VALUE guaranteed_shortest_pathfind(VALUE self, VALUE target)
{
	Area *origin, *destination, *ptr;
	VALUE path;

	origin = find_node_by_value(self);
	destination = find_node_by_value(target);

	origin->realcost = glist = 0;
	trace_paths_from_node(origin);

	path = rb_ary_new();
	for (ptr = destination->parent; ptr != NULL && ptr != origin; ptr = ptr->parent)
	{
		rb_ary_push(path, ULONG2NUM(ptr->id));
	}
	reset_flags();
	if (!ptr)
		return Qnil;
	return rb_ary_reverse(path);
}
#endif

static VALUE nodes_traced()
{
	VALUE hash = rb_hash_new();

	rb_hash_aset(hash, rb_str_new2("distance-estimation heuristic"), ULONG2NUM(slist));
	rb_hash_aset(hash, rb_str_new2("sequential-search algorithm"), ULONG2NUM(ulist));
	rb_hash_aset(hash, rb_str_new2("global-trace algorithm"), ULONG2NUM(glist));
	return hash;
}


static VALUE rb_list_get(VALUE self)
{
	return rb_cv_get(lich_mPathfind, "@@list");
}


static VALUE dump_c_struct(VALUE self)
{
	Area *ptr = find_node_by_value(self);
	return rb_ary_new3(5, ULONG2NUM(ptr->id), INT2FIX(ptr->nadj), INT2FIX(ptr->x), INT2FIX(ptr->y), ULONG2NUM(ptr->rb_obj));
}


static VALUE x_val(VALUE self)
{
	return INT2FIX((find_node_by_value(self))->x);
}


static VALUE y_val(VALUE self)
{
	return INT2FIX((find_node_by_value(self))->y);
}


static signed short *min_max_x_y_vals()
{
	register unsigned long i = numnodes - 1;
	signed short *min;

	min = ALLOC_N(signed short, 4);
	if (!min)
		rb_raise(rb_eNoMemError, "can't allocate mem for min/max vals");
	memset(min, '\0', sizeof(short) * 4);
	while (i--)
	{
		if (nodes[i].x < min[0])
			min[0] = nodes[i].x;
		if (nodes[i].x > min[2])
			min[2] = nodes[i].x;
		if (nodes[i].y < min[1])
			min[1] = nodes[i].y;
		if (nodes[i].y > min[3])
			min[3] = nodes[i].y;
	}
	return min;
}


VALUE min_max_x_y_rb(VALUE self)
{
	signed short *val = min_max_x_y_vals();
	VALUE hash = rb_hash_new();

	rb_hash_aset(hash, rb_str_new2("min_x"), INT2FIX(val[0]));
	rb_hash_aset(hash, rb_str_new2("min_y"), INT2FIX(val[1]));
	rb_hash_aset(hash, rb_str_new2("max_x"), INT2FIX(val[2]));
	rb_hash_aset(hash, rb_str_new2("max_y"), INT2FIX(val[3]));
	free(val);
	return hash;
}


void Init_pathfind()
{
	x_tbl = st_init_numtable();

	lich_mPathfind = rb_define_module("Pathfind");
	rb_cv_set(lich_mPathfind, "@@list", rb_ary_new());

	rb_define_module_function(lich_mPathfind, "find_node", find_node_by_id, 1);
	rb_define_module_function(lich_mPathfind, "reassoc_nodes", reassoc_nodes, 0);
	rb_define_module_function(lich_mPathfind, "trace_field_positions", trace_field_positions, 0);
	rb_define_module_function(lich_mPathfind, "clear_cache", clear_cache, 0);
	rb_define_module_function(lich_mPathfind, "minmax_xy", min_max_x_y_rb, 0);
	rb_define_module_function(lich_mPathfind, "list", rb_list_get, 0);
	rb_define_virtual_variable("$NODES_TRACED", nodes_traced, 0);
	
	rb_define_const(lich_mPathfind, "N", INT2FIX(N));
	rb_define_const(lich_mPathfind, "NE", INT2FIX(NE));
	rb_define_const(lich_mPathfind, "E", INT2FIX(E));
	rb_define_const(lich_mPathfind, "SE", INT2FIX(SE));
	rb_define_const(lich_mPathfind, "S", INT2FIX(S));
	rb_define_const(lich_mPathfind, "SW", INT2FIX(SW));
	rb_define_const(lich_mPathfind, "W", INT2FIX(W));
	rb_define_const(lich_mPathfind, "NW", INT2FIX(NW));
	rb_define_const(lich_mPathfind, "UP", INT2FIX(UP));
	rb_define_const(lich_mPathfind, "DN", INT2FIX(DN));
	rb_define_const(lich_mPathfind, "NODIR", INT2FIX(NODIR));

	rb_define_attr(lich_mPathfind, "id", 1, 1);
	rb_define_attr(lich_mPathfind, "title", 1, 1);
	rb_define_attr(lich_mPathfind, "desc", 1, 1);
	rb_define_attr(lich_mPathfind, "paths", 1, 1);
	rb_define_attr(lich_mPathfind, "wayto", 1, 1);
	rb_define_attr(lich_mPathfind, "timeto", 1, 1);
	rb_define_attr(lich_mPathfind, "geo", 1, 1);
	rb_define_attr(lich_mPathfind, "maze", 1, 1);
	rb_define_attr(lich_mPathfind, "pause", 1, 1);
	
	rb_define_method(lich_mPathfind, "mknode", mknode, 0);
	rb_define_method(lich_mPathfind, "mark_adjacent", mark_adj, 1);
	rb_define_method(lich_mPathfind, "clear_adjacent", clear_adj, 0);
	rb_define_method(lich_mPathfind, "mark_field_position", mark_field_position, 2);
	rb_define_method(lich_mPathfind, "c_inspect", dump_c_struct, 0);
	rb_define_method(lich_mPathfind, "estimation_pathfind", pathfind, 1);
	rb_define_method(lich_mPathfind, "x_val", x_val, 0);
	rb_define_method(lich_mPathfind, "y_val", y_val, 0);
#ifdef GUARANTEED_SHORTEST_ALGORITHM
	rb_define_method(lich_mPathfind, "guaranteed_shortest_pathfind", guaranteed_shortest_pathfind, 1);
	rb_define_method(lich_mPathfind, "pathfind", guaranteed_shortest_pathfind, 1);
#else
	rb_define_method(lich_mPathfind, "pathfind", pathfind, 1);
#endif
}


void Init_libpathfind()
{
	Init_pathfind();
}

#ifdef __cplusplus
} // extern "C"
#endif
