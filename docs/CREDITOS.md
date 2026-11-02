# Créditos e licenças de terceiros

| Material | Onde | Fonte | Licença |
|---|---|---|---|
| Logos de tecnologias (Godot, Node, Vue, React, Flutter, Docker, PostgreSQL etc.) | `game/assets/tech_icons/` (gerados por `tools/icons/build_icons.mjs`) | [Simple Icons](https://simpleicons.org) | CC0 1.0 |
| Logo da AWS | `game/assets/tech_icons/aws_*.png` | [Devicon](https://devicon.dev) | MIT |
| Sedã e viatura de polícia (base de `car_sedan_*`, `car_taxi_yellow`, `car_police`) | `game/assets/vehicles/` (via `tools/blender/car_import.py`) | Quaternius, [Car](https://poly.pizza/m/Cz6yDaUcM9) e [Police Car](https://poly.pizza/m/BwwnUrWGmV) | CC0 1.0 |
| Muscle car (base de `car_muscle_*`) | `game/assets/vehicles/` | David Sirera, [Dodge Charger](https://poly.pizza/m/4b80hRVxqvv) | CC-BY 3.0 |
| Perua clássica (base de `car_wagon_*`) | `game/assets/vehicles/` | Mark Joseph Sabaco, [Retro car](https://poly.pizza/m/coSYdjhglCZ) | CC-BY 3.0 |
| Van (base de `car_van_*`) | `game/assets/vehicles/` | PuKkBuMXDD, [Generic Van](https://poly.pizza/m/BbRojf2v3H) | CC-BY 3.0 |
| Fontes Bebas Neue, Special Elite, Permanent Marker, Nunito | `game/assets/fonts/` | Google Fonts | SIL OFL 1.1 |

As marcas pertencem aos respectivos donos; os logos aparecem só para identificar as tecnologias que o
Gabriel usa. A moldura, o fundo e o brilho em volta de cada logo são nossos. O índice com cor e fonte
de cada ícone fica em `data/tech_icons.json`.

Carros: os modelos originais ficam em `tools/blender/car_sources/`. O `car_import.py` gira, escala,
reduz polígonos, troca as cores para a paleta noir (cor por vértice) e acrescenta faróis/lanternas
emissivos, o luminoso e a faixa xadrez do táxi. Modelos CC-BY: crédito aos autores acima.
