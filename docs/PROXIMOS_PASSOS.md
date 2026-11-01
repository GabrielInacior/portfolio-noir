# Próximos passos (priorizado)

A base entregue: cidade noir jogável em primeira pessoa (desktop + mobile), neons com halo e
reflexo no asfalto, vitrines com a capa do projeto, skyline, outdoor com a foto, minimapa,
contador de visitados, entrada cinematográfica, OST com ducking e liga/desliga, dossiês custom de
todos os projetos + Sobre + Contato, modo lista, e uma tela de diálogo no nível do RUMOR com
personagem riggado 3D e expressões por fala. Dados de `data/*.json` e `github_snapshot.json`.

O que o usuário ainda pediu, em ordem de prioridade:

## 1. Personagens bespoke (supera o porte direto do RUMOR)
Usar o RUMOR só como **pipeline de referência** (rig Mixamo, Blender headless, atlas de expressão),
criando modelos NOVOS e mais sérios:
- Proporções adultas alongadas (~8 cabeças), ombros largos, mãos com dedos.
- Rostos angulosos: maxilar marcado, maçãs do rosto, nariz definido, olhos menores, sobrancelhas
  pesadas. Cabelo com mechas, barba por fazer. Roupas com caimento e dobras (sobretudo de gola
  alta, colete, gravata, couro).
- **Atlas de expressão NOVO**, contido e adulto: sério, desconfiado, pensativo, sorriso de canto,
  cansado, intrigado (traço fino, nada infantil).
- 3 a 4 NPCs distintos: homem de sobretudo, mulher de jaqueta de couro, bartender, hacker.
- Validar em close contra a régua (`docs/referencias_visuais_fortresschaos`) antes de seguir.
- Arquivos: novo `tools/blender/char_*.py` (modelagem por script), `scripts/scene3d/character.gd`
  evoluído (hoje porta o do RUMOR como ponte funcional), atlas em `assets/characters/`.

## 2. Bairro não-linear com interiores entráveis
- Trocar a rua reta por um pequeno bairro com **esquinas** (cruzamento, beco, praça ou escadaria),
  quarteirões que dobram e vistas que se abrem ao virar a esquina.
- **Lojas entráveis** com interiores detalhados por projeto: bar, loja de eletrônicos/discos,
  galeria, escritório de detetive, fliperama. Carregar o interior por **zona/porta** (instanciar ao
  entrar, liberar ao sair) para manter a performance.
- Um lugar dedicado a **habilidades** (laboratório/bar de hackers) com telões de skills e um NPC que
  fala delas (game dev/Godot/Blender, IA e agentes, APIs/integrações, arquitetura/tempo real).

## 3. GitHub ao vivo + READMEs em telas 3D
- No navegador, `HTTPRequest` para a API pública do GitHub (sem token, 60 req/h/IP): perfil, repos,
  estrelas, linguagens, último commit e o README (`Accept: application/vnd.github.html` ou raw +
  render simples de markdown). Cache em `localStorage` com validade; **fallback** para
  `github_snapshot.json` (já gerado no build) quando estourar o limite ou estiver offline.
- Telões/monitores 3D na cidade e nos interiores exibindo README/imagens, roláveis; tocar abre
  leitor em tela cheia com `TouchScroll` (do RUMOR) e links clicáveis.
- Extras: ticker de LED com "atividade recente", gráfico de linguagens, contador de estrelas em
  neon, botão "ver no GitHub".

## 4. Vitrines como colagem
- Em vez de uma capa, uma **colagem** por projeto (prints do README, telas, logo) tipo mural de
  cortiça / polaroides com fita, levemente rotacionadas e sobrepostas, com uma imagem destaque.
  Gerar a textura no build (Python/PIL) a partir das imagens dos READMEs/snapshot, boa resolução
  com mipmaps. Opcional: alternar devagar entre 2-3 colagens ou telinha rodando imagens.

## 5. Projeto sem imagem: cartão GitHub/terminal noir
- Gerar no build uma visualização própria: nome, descrição, barra de linguagens, estrutura de
  pastas, trechos do README (títulos, listas, badges de stack), estatísticas (commits, arquivos,
  data). Serve também como colagem da vitrine. Repos **privados** aparecem com dados do build (via
  `gh` local), sem código nem segredos, e botão "repositório privado" no lugar do link.

## 6. Conteúdo pessoal (currículo e LinkedIn)
- Ler os PDFs `C:\Users\gabri\Downloads\Gabriel_Inacio_Resume_EN (1).pdf` e `Profile (1).pdf` para
  experiência, cargos, formação e conquistas, alimentando "Sobre mim" e as falas dos NPCs.
  **Não** publicar telefone/endereço pessoal; e-mail e links profissionais ok.

## 7. Acabamento
- Minimapa mais legível (ruas, ícones dos lugares com rótulo, seta do jogador).
- Riqueza da rua: portas, toldos, escadas de incêndio, placas, lixeiras, fios, calçada detalhada.
- Animações Mixamo variadas (idle, conversar, apontar) e gesto por fala.


## Depois da rodada 4A (prioridade, pedidos do usuário ainda abertos)
1. **Identidade própria de cada loja** (hoje parecem o mesmo molde): RUMOR madeira escura + âmbar + persiana
   com faixas de luz; Lábia tijolo + neon rosa/roxo + balcão iluminado por baixo + garrafas retroiluminadas;
   FormataAI espuma acústica + luz fria/LED; InacioCyber escuro, luz de monitor verde/vermelha, cabos no chão.
   Salas menores (~6x8 m, hoje 10x12), ilhas de exposição e vitrines de vidro no meio, spots nos objetos.
2. **Interação 3D com painéis variados**: contorno colorido no objeto mirado + retícula; prompt "[E] examinar /
   abrir / ligar / atender" (PC) e botão grande no celular; painéis por tipo (inspeção 3D girando, leitor de
   documento, tela de monitor com README rolando, galeria de prints, linha do tempo, placa de stack, cartão
   de contato). Interações: gaveta abre, telefone toca, máquina de escrever digita, interruptor.
3. **GitHub no jogo**: telão por loja com o README (render simples de markdown) via
   `scripts/data/github_live.gd`, estrelas/último commit em LED, barra de linguagens, ticker de atividade na rua.
4. **LAB / Sobre mim como ponto alto das skills**: galeria de tecnologias (de `data/profile.json` e currículo)
   ligadas aos projetos, linha do tempo profissional, botões LinkedIn/GitHub/contato; lojas dos projetos de
   software tão caprichadas quanto as dos jogos (diagramas de arquitetura, placas de stack, terminal, métricas).
5. **Performance**: 897 mil primitivas por quadro na rua (draws ok: 422 PC / 266 celular). Suspeitos: personagens
   (12k tris cada, sombra) e skyline; medir com e sem pedestres, LOD/impostor nos pedestres distantes,
   sombra só perto. Testar no navegador do celular real.
6. Acabamento da rua: fachadas modulares por Blender (portas, marquises, letreiros 3D), banca/caixas com textura.


## Depois da rodada 5 (abertos)
1. **Performance**: rua ~1,4 milhão de primitivas por quadro (meta < 300 mil). A maior parte vem dos
   MultiMesh e dos pedestres (cada personagem ~10 mil tris, sem LOD aplicado na rua). Próximo: LOD dos
   personagens na rua (ou menos figurantes no celular), impostores no skyline, medir no celular real.
2. **Barra de cima no celular** não apareceu nas capturas 405x720 (no PC aparece com som, idioma, retrô e
   projetos); no celular o idioma se escolhe na tela de entrada. Investigar.
3. **Confirmar com o usuário** os nomes "imp" e "SysGuide" na carreira.
4. Meio da sala da CARREIRA ainda pouco preenchido; LAB e CARREIRA podem ganhar mais objetos.
5. Imagens do README no painel terminal (extração pronta em `gh_screen.readme_images`, falta exibir).
