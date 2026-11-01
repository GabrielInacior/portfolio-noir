"""Texturas contínuas (tile) pintadas, estilo jogo estilizado limpo, via SDXL-Turbo local.
Uso: C:/Project/tools-ai/sd/Scripts/python tools/art/sd_textures.py [nome ...]
Saída: tools/art/sd_tex/<nome>_<i>.png (escolha a melhor e copie para game/assets/tex/)."""
import os, sys, torch
from diffusers import AutoPipelineForText2Image
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "sd_tex")
T = {
 "asfalto": "smooth dark charcoal asphalt with fine grain, uniform, no stones",
 "calcada": "large square grey concrete sidewalk slabs with thin seams, uniform grid",
 "tijolo": "dark red brick wall, clean mortar lines",
 "concreto": "smooth grey plaster concrete wall, subtle mottling, no cracks",
 "papel_parede": "dark green and gold damask wallpaper pattern, 1940s",
 "painel_madeira": "dark walnut vertical wood wall paneling",
 "madeira": "long straight dark oak wooden floor planks running vertically, parallel boards",
 "carpete": "burgundy woven carpet fabric, small repeating diamond pattern, soft fibers",
 "ladrilho": "regular black and white square checkerboard floor tiles, straight grid, glossy",
 "metal": "brushed dark steel sheet metal with small rivets, straight panels",
 "azulejo": "dark teal rectangular subway tiles in straight brick bond rows, white grout",
 "acustico": "dark grey pyramid acoustic foam panels, regular grid",
 "fachada": "smooth rectangular limestone facade blocks in straight rows, grey",
}
STYLE = "seamless tileable albedo texture, stylized game material, clean, subtle detail, uniform flat lighting, orthographic top view, {t}"
NEG = "text, perspective, objects, people, shadows, 3d render, photo, blurry"
want = sys.argv[1:] or list(T)
pipe = AutoPipelineForText2Image.from_pretrained("stabilityai/sdxl-turbo", torch_dtype=torch.float16, variant="fp16").to("cuda")
pipe.set_progress_bar_config(disable=True)
for m in list(pipe.unet.modules()) + list(pipe.vae.modules()):
    if isinstance(m, torch.nn.Conv2d):
        m.padding_mode = "circular"
for n in want:
    g = torch.Generator("cuda").manual_seed(3)
    ims = pipe(prompt=[STYLE.format(t=T[n])] * 3, negative_prompt=[NEG] * 3, num_inference_steps=4, guidance_scale=0.0,
               width=512, height=512, generator=g).images
    for i, im in enumerate(ims):
        im.save(os.path.join(OUT, f"{n}_{i}.png"))
    print("ok", n, flush=True)
