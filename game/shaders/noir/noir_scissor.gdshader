shader_type spatial;
// mundo noir: scissor (ver noir_inc.gdshaderinc)
render_mode unshaded, cull_disabled;
#define NOIR_ALPHA
#define NOIR_SCISSOR
#include "res://shaders/noir/noir_inc.gdshaderinc"
