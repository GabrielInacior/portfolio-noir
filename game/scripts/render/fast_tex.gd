class_name FastTex
## Imagens grandes da cidade (páginas de anúncio, outdoors, colagens, panfletos) decodificadas pelo NAVEGADOR.
## No celular, decodificar o WebP dentro do jogo custava ~0,4 s por página 2048 na thread principal (3,5 s da
## montagem da cidade). O build (tools/deploy/pck_split.py) tira esses .ctex do pacote e grava os MESMOS WebP de
## cada nível de mipmap num arquivo próprio (jogo/img/); o carregador (make_boot.py) baixa e decodifica tudo com
## createImageBitmap em paralelo com o boot, fora da thread do jogo. Aqui a textura nasce do tamanho certo com uma
## imagem mínima (2048x1 com a mesma contagem de mipmaps) e o navegador envia cada nível direto para a textura GL.
## Mesmos pixels (mesmos WebP decodificados, sem conversão de cor). Fora da web, ou com ?fasttex=0, é o load() de sempre.

static var _cache := {}
static var _on := -1


static func enabled() -> bool:
	if _on < 0:
		_on = 0
		if OS.has_feature("web"):
			_on = 1 if int(str(JavaScriptBridge.eval("(window.pfImg&&window.pfImg.ok())?1:0", true)).to_float()) == 1 else 0
	return _on == 1


static func has(path: String) -> bool:
	return enabled() and int(str(JavaScriptBridge.eval("window.pfImg.has(%s)?1:0" % JSON.stringify(path), true)).to_float()) == 1


static func exists(path: String) -> bool:
	return _cache.has(path) or has(path) or ResourceLoader.exists(path)


## 0 baixando, 1 pronta, 2 só os bytes (o navegador não decodificou), -1 falhou, -2 não pedida
static func state(path: String) -> int:
	return int(str(JavaScriptBridge.eval("window.pfImg.state(%s)" % JSON.stringify(path), true)).to_float())


## pede as imagens de um idioma (e as comuns) e espera chegarem (com limite de tempo)
static func wait_lang(tree: SceneTree, lang: String, limit_s := 60.0) -> void:
	if not enabled():
		return
	JavaScriptBridge.eval("window.pfImg.want(%s)" % JSON.stringify(lang), true)
	var t0 := Time.get_ticks_msec()
	while int(str(JavaScriptBridge.eval("window.pfImg.pending(%s)" % JSON.stringify(lang), true)).to_float()) > 0:
		if Time.get_ticks_msec() - t0 > int(limit_s * 1000.0):
			push_warning("imagens do navegador demoraram; seguindo")
			break
		await tree.process_frame


## textura pronta (ou null se a imagem ainda não chegou: quem chama decide esperar com wait_lang)
static func get_tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if not has(path):
		return load(path) if ResourceLoader.exists(path) else null
	var st := state(path)
	var t: Texture2D = null
	if st == 1:
		t = _from_browser(path)
	if t == null and (st == 1 or st == 2):
		t = _from_bytes(path)
	if t:
		_cache[path] = t
	return t


static func _meta(path: String) -> PackedInt32Array:
	var v := str(JavaScriptBridge.eval("window.pfImg.meta(%s)" % JSON.stringify(path), true)).split(",")
	var out := PackedInt32Array()
	for x in v:
		out.append(int(x.to_float()))
	return out


static func _from_browser(path: String) -> Texture2D:
	var md := _meta(path)   # w, h, níveis
	if md.size() < 3:
		return null
	var w := md[0]
	var h := md[1]
	var lv := md[2]
	var img: Image
	if lv > 1:
		img = Image.create_empty(w if w >= h else 1, 1 if w >= h else h, true, Image.FORMAT_RGBA8)
		if img.get_mipmap_count() + 1 != lv:
			return null
	else:
		img = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(w, h))
	var gl_id := RenderingServer.texture_get_native_handle(t.get_rid())
	var ok := int(str(JavaScriptBridge.eval("window.pfImg.upload(%s,%d)?1:0" % [JSON.stringify(path), gl_id], true)).to_float())
	if ok != 1:
		return null
	t.resource_path = path
	return t


## reserva: o navegador baixou mas não decodificou; decodifica aqui (mesmos WebP, nível a nível)
static func _from_bytes(path: String) -> Texture2D:
	var md := _meta(path)
	if md.size() < 3:
		return null
	var levels: Array = []
	var data := PackedByteArray()
	for i in md[2]:
		var buf: Variant = JavaScriptBridge.eval("window.pfImg.bytes(%s,%d)" % [JSON.stringify(path), i])
		if buf == null:
			return null
		var bytes: PackedByteArray = buf if buf is PackedByteArray else JavaScriptBridge.js_buffer_to_packed_byte_array(buf)
		var im := Image.new()
		if im.load_webp_from_buffer(bytes) != OK:
			return null
		im.convert(Image.FORMAT_RGBA8)
		data.append_array(im.get_data())
		levels.append(im)
	var full := Image.create_from_data(md[0], md[1], md[2] > 1, Image.FORMAT_RGBA8, data)
	var t := ImageTexture.create_from_image(full)
	t.resource_path = path
	return t
