"""Atlas 4x4 de interiores de janela (vistos de fora, à noite), via SDXL-Turbo local.
Saída game/assets/tex/janelas_atlas.png (1024x1024, cada célula 256)."""
import os, torch
from PIL import Image, ImageDraw, ImageFilter
from diffusers import AutoPipelineForText2Image
R = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
pipe = AutoPipelineForText2Image.from_pretrained("stabilityai/sdxl-turbo", torch_dtype=torch.float16, variant="fp16").to("cuda")
pipe.set_progress_bar_config(disable=True)
kinds = [
 "cozy apartment room at night seen through a window, warm yellow lamp light, curtains half open, silhouette of furniture",
 "dark apartment room lit only by a blue television glow, seen through a window at night",
 "small kitchen at night seen through a window, warm light, hanging pendant lamp, shelves",
 "bedroom at night seen through a window with pink neon light coming in, blinds, moody",
]
atlas = Image.new("RGB", (1024, 1024))
i = 0
for k, p in enumerate(kinds):
    g = torch.Generator("cuda").manual_seed(11 + k)
    ims = pipe(prompt=["stylized game art, flat frontal view, " + p] * 4, negative_prompt=["people, text, frame, outdoor"] * 4,
               num_inference_steps=4, guidance_scale=0.0, width=512, height=512, generator=g).images
    for im in ims:
        im = im.resize((256, 256), Image.LANCZOS)
        atlas.paste(im, ((i % 4) * 256, (i // 4) * 256))
        i += 1
atlas.save(os.path.join(R, "game", "assets", "tex", "janelas_atlas.png"))
print("ok")
