extends SkeletonModifier3D
## Proporções ADULTAS sobre o rig Mixamo herdado: cabeça menor e mais longa, pescoço, pernas e
## ombros mais compridos. Roda depois da animação (as animações trazem trilhas de escala, então a
## escala precisa ser aplicada aqui, a cada quadro). Escala de osso é herdada pelos filhos, por isso
## alguns ossos compensam a do pai.

## sufixo do osso -> escala local
var scales := {
	"UpLeg": Vector3(1.0, 1.12, 1.0),
	"Leg": Vector3(1.0, 1.04, 1.0),
	"Spine": Vector3(1.0, 1.05, 1.0),
	"Shoulder": Vector3(1.0, 1.18, 1.0),
	"Arm": Vector3(1.0, 1.0 / 1.18 * 1.06, 1.0),
	"Neck": Vector3(1.08, 1.3, 1.08),
	"Head": Vector3(0.68 / 1.08, 0.78 / 1.3, 0.72 / 1.08),
}
var _idx := []   # [[bone, Vector3]]


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		var base := n.substr(n.rfind("_") + 1) if n.contains("_") else n
		base = base.trim_prefix("Left").trim_prefix("Right")
		if scales.has(base):
			_idx.append([i, scales[base]])


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for e in _idx:
		sk.set_bone_pose_scale(e[0], e[1])
