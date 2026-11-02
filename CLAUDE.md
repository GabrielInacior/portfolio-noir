# Portfólio Noir (pasta `portfolio-noir`)

Portfólio web do Gabriel Inácio como **jogo 3D em primeira pessoa**: uma cidade noir noturna
(estilo Vampire: The Masquerade Bloodlines, porém pincelado como o RUMOR) por onde o visitante
anda, conhece os projetos em vitrines de neon, conversa com NPCs guia e abre dossiês. Godot 4.7.1
(renderizador Compatibility), exportado para web, leve, bom no celular e no desktop.

Mesmo autor do RUMOR (`C:\Project\detetive`) e do FortressChaos (`C:\Project\game`). Tudo que foi
aprendido lá em arte, Blender, Godot e web foi trazido para cá:

- `.claude/skills/game-modelagem-3d`, `game-arte-2d-ia`, `game-godot-workflow` (invocar antes de
  mexer em modelo 3D, arte 2D ou código/cena/validação).
- `tools/blender`, `tools/ai_art`, `tools/art` (texturas e céu pincelados por código/PIL).
- `docs/APRENDIZADOS_WEB.md`: lições concretas de performance e web herdadas do RUMOR.
- Personagem riggado + atlas de rosto + animações Mixamo reaproveitados do RUMOR
  (`scripts/scene3d/character.gd`, `assets/characters/student.glb`).

**Leia primeiro `docs/CONTEXTO_E_DECISOES.md`**: tudo que o usuário pediu e decidiu (visão, estilo dos personagens, lojas-museu, ferramentas liberadas, SD local, Mixamo).

## Regras de base (herdadas do RUMOR)
- Nenhum asset pronto de terceiro; gerado por código ou por IA é permitido.
- Teste nunca faz som (`--audio-driver Dummy`). Commits regulares com push estão autorizados pelo usuário (sempre com as linhas de atribuição da sessão; `git pull --rebase` antes; `git add` só com caminhos exatos).
- Texto ao jogador sem travessão "—" e sem termo de dev.
- Confirmar UX ambígua antes de implementar. Uma frente por vez; economia de tokens.
- **Segredos nunca entram no repositório nem no build**: a chave OpenAI em
  `C:/Users/gabri/.openai_key` jamais é impressa ou commitada; o `.wav` original da trilha fica
  fora do repo (só o `.mp3` entra). Nenhum token do GitHub vai para o cliente: dados do GitHub são
  gerados no build com `gh` (login local) e viram `data/github_snapshot.json`.

## Como rodar
- Abrir o jogo: Godot 4.7.1 (Compatibility), pasta `game/`.
- Validar sem editor: `godot --headless --audio-driver Dummy --path game --import`.
- Capturas mudas: `RUMOR_SHOT=<pasta> godot --audio-driver Dummy --path game --resolution 1920x1080 res://tools_dev/shot.tscn`.
- Snapshot do GitHub: `node tools/dev/github_snapshot.js`.
- Export web: Godot preset "Web" para `build/web/` (não publicar sem autorização).
