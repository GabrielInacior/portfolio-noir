extends Node
## Pacotes de recursos baixados em segundo plano (música, lojas-museu). O carregador da página
## (tools/deploy/make_boot.py) baixa cada pacote em paralelo e o entrega ao sistema de arquivos virtual do
## motor; aqui ele é montado com load_resource_pack quando chega. Fora da web (ou sem carregador) tudo já
## está no pacote principal e `ready` responde verdadeiro.

var _ok := {}


func ready_pack(id: String) -> bool:
	if _ok.has(id) or not OS.has_feature("web"):
		return true
	var p: Variant = JavaScriptBridge.eval("(typeof window.pfPackPath==='function')?(window.pfPackPath('%s')||''):'inline'" % id, true)
	var path := str(p)
	if path == "inline":
		_ok[id] = true
		return true
	if path == "":
		return false
	if ProjectSettings.load_resource_pack(path):
		_ok[id] = true
		print("PFT pacote montado: ", id)
		return true
	push_error("pacote falhou: " + id)
	_ok[id] = true  # não trava o jogo; o recurso que faltar já cai nos caminhos de erro de sempre
	return true


## coroutine: espera o pacote chegar (poucos décimos de segundo quando a rede é boa)
func need(id: String) -> void:
	while not ready_pack(id):
		await get_tree().create_timer(0.15).timeout
