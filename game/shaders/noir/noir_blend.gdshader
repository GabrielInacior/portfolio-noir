shader_type spatial;
// mundo noir: blend (ver noir_inc.gdshaderinc)
render_mode unshaded, cull_disabled, depth_draw_opaque;
#define NOIR_ALPHA
#include "res://shaders/noir/noir_inc.gdshaderinc"
