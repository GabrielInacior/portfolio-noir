"""Conceitos 2D dos props (SDXL-Turbo local) para o Meshy image-to-3D.
Uso: C:/Project/tools-ai/sd/Scripts/python tools/props/concepts_sd.py [nome ...]
Gera tools/props/concepts/<nome>_<i>.png (4 variações por prop)."""
import os, sys, json, torch
from diffusers import AutoPipelineForText2Image
HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = json.load(open(os.path.join(HERE, "props_list.json"), encoding="utf8"))
STYLE = ("stylized 3D game prop of a {p}, Fortnite style, chunky simplified shapes, hand-painted textures, "
         "soft clean shading, isolated single object, centered, three-quarter view from slightly above, entire object in frame, "
         "plain flat light grey background, no shadows on background, no text")
NEG = "photo, photorealistic, text, watermark, people, cropped, multiple objects, background scene, buildings, street, room"
want = sys.argv[1:] or list(PROPS.keys())
pipe = AutoPipelineForText2Image.from_pretrained("stabilityai/sdxl-turbo", torch_dtype=torch.float16, variant="fp16").to("cuda")
pipe.set_progress_bar_config(disable=True)
for name in want:
    p = PROPS[name]["prompt"]
    g = torch.Generator("cuda").manual_seed(7)
    ims = pipe(prompt=[STYLE.format(p=p)] * 4, negative_prompt=[NEG] * 4, num_inference_steps=4, guidance_scale=0.0,
               width=768, height=768, generator=g).images
    for i, im in enumerate(ims):
        im.save(os.path.join(HERE, "concepts", f"{name}_{i}.png"))
    print("ok", name, flush=True)
