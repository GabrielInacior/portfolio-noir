shader_type spatial;
// mundo noir: add (ver noir_inc.gdshaderinc)
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
#define NOIR_ALPHA
#include "res://shaders/noir/noir_inc.gdshaderinc"
