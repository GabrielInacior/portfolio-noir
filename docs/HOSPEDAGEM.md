# Hospedagem (recomendação para aprovação)

O jogo exporta como site estático (`index.html` + `.wasm`/`.pck` + assets). Export web **sem
threads**, então **não precisa** dos cabeçalhos COOP/COEP (`Cross-Origin-Opener-Policy` /
`Cross-Origin-Embedder-Policy`) nem de SharedArrayBuffer. Isso simplifica muito a hospedagem.

## Opção recomendada: Cloudflare Pages
- Gratuito, CDN global, HTTPS automático, ótimo para arquivos estáticos grandes.
- Servir `build/web/` como diretório de saída.
- Ligar **Brotli/gzip** (o Pages já comprime; manter os `.gz` do build como fallback).
- Domínio `inaciodev.online` apontado por CNAME. (DNS fica a cargo do usuário; não mexido aqui.)
- Cabeçalho de cache longo para `*.wasm`, `*.pck`, imagens e fontes; `index.html` sem cache.

## Alternativas
- **Netlify**: mesma simplicidade; `netlify.toml` com headers de cache e `publish = "build/web"`.
- **GitHub Pages**: funciona, mas pior para `.wasm` grande e sem Brotli nativo.
- **Vercel** (onde o portfólio atual está): serve estático bem; usar `vercel.json` para cache.

## Checklist antes de publicar
- [ ] Testar com rede e **sem rede** (o GitHub ao vivo deve cair no `github_snapshot.json`).
- [ ] Confirmar que nenhum segredo entrou no build (sem token, sem `.key`, sem `.wav`).
- [ ] Medir no celular médio (alvo 60 fps; a resolução adaptativa segura quedas).
- [ ] `index.html` servido com `Content-Type` certo e `.gz` negociado por `Accept-Encoding`.

Nada de DNS, repositório remoto de hospedagem ou deploy é feito sem a autorização do usuário.
