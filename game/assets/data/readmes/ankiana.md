<p align="center">
  <img src="assets/images/AnaAppLogo.png" alt="AnaApp Logo" width="120" />
</p>

<h1 align="center">AnaApp</h1>

<p align="center">
  <b>Flashcards inteligentes com IA — estude de forma eficiente e bonita.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/OpenAI-GPT--4o--mini-412991?logo=openai" alt="OpenAI" />
  <img src="https://img.shields.io/badge/Material%20You-3-6750A4" alt="Material 3" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## O que e o AnkiAna?

O AnkiAna e um app de flashcards com **inteligencia artificial integrada** que transforma qualquer conteudo em cards de estudo. Inspirado no AnkiDroid, mas com uma interface moderna, fofa e acessivel, o AnkiAna usa **repeticao espacada (SM-2)** para garantir que voce revise na hora certa, memorize mais e esqueca menos.

Seja para idiomas, vestibular, concursos, faculdade ou qualquer outra coisa — basta descrever o assunto, colar um texto ou enviar um PDF, e a IA cria dezenas de flashcards prontos para estudo.

---

## Funcionalidades

### Geracao de Flashcards com IA

- **Por tema**: descreva o assunto (ex: "verbos irregulares em ingles") e a IA cria ate 30 cards instantaneamente
- **Por texto**: cole qualquer texto e a IA extrai perguntas e respostas automaticamente
- **Por documento**: importe arquivos **PDF** ou **PPTX** com dois modos:
  - *Pares prontos* — ideal para listas bilingues (ingles-portugues, etc.)
  - *IA interpreta* — a IA le o conteudo e gera perguntas livremente
- **Instrucoes personalizadas**: refine a geracao com instrucoes adicionais (ex: "foco em vocabulario de viagem")
- **Imagens com DALL-E**: gere ilustracoes educativas automaticamente para cada card
- **Multi-topico**: selecione varios assuntos de uma vez e a IA atribui tags automaticamente a cada card
- **15 topicos predefinidos**: Ingles, Espanhol, Frances, Matematica, Fisica, Biologia, Historia, Quimica, Geografia, Calculo, Programacao, Concursos, Direito, Filosofia, Medicina
- **Deteccao inteligente de idiomas**: a IA reconhece pares bilingues (frente em ingles, verso em portugues) e classifica como card de idioma automaticamente

### Criacao Manual

- Campos de frente e verso com suporte a texto livre
- Upload de **imagens da galeria** para frente e/ou verso do card
- Seletor de tags com as mesmas opcoes do modo IA
- Criacao de tags personalizadas com nome e cor

### Sistema de Revisao Espacada (SM-2)

- Algoritmo **Anki-style** completo com 4 filas: Novo, Aprendendo, Revisao, Reaprendendo
- **4 botoes de avaliacao**: Errei, Dificil, Bom, Facil — cada um mostrando o proximo intervalo previsto
- Steps de aprendizado configuraveis (padrao: 1min, 10min)
- Fuzz de intervalo (±5%) para evitar acumulo de revisoes no mesmo dia
- Timer de espera integrado para cards em steps de aprendizado
- Sessoes limitadas a 20 cards para manter o foco
- Tela de resultado com porcentagem de acertos

### Flip 3D dos Cards

- Animacao de giro 3D suave (rotacao no eixo Y)
- Gradiente de fundo com a cor da tag do card
- Exibicao de imagens no card (frente e/ou verso)
- Badge de tag colorido no card
- Dica visual "Toque para revelar" na frente
- Transicao instantanea ao avancar para o proximo card (sem flash da resposta)

### Sistema de Tags Inteligente

- Tags no **nivel do card** (nao do deck) — cada card pode ter sua propria classificacao
- **Auto-tagging com IA**: classifica todos os cards sem tag automaticamente
- **15 topicos predefinidos** com cores associadas
- **Tags personalizadas** ilimitadas com picker de 12 cores
- Filtro por tag na tela de cards do deck (chips horizontais coloridos)
- Visualizacao agrupada por tag com headers colapsaveis e borda lateral colorida
- Seletor de tag no modo manual com mesma UI do modo IA

### Organizacao de Baralhos (Decks)

- Criacao com nome, descricao opcional e **8 cores pastel** exclusivas
- **Favoritos** com icone de coracao (toggle rapido)
- Busca em tempo real por nome do deck
- Filtro por tags e favoritos
- Gradiente colorido do deck na listagem e na tela de detalhes
- Contagem de cards totais e cards pendentes
- Animacoes de entrada escalonadas na lista

### Estatisticas Detalhadas

- **Visao geral (2x2)**: revisoes do dia, dias de streak, total 30 dias, precisao media
- **Grafico de atividade**: barras com historico de revisoes dos ultimos 30 dias
- **Distribuicao de maestria**: pizza com categorias Novo / Aprendendo / Jovem / Maduro
- **Breakdown de avaliacoes**: barras horizontais com % de cada nota (Errei/Dificil/Bom/Facil)
- **Previsao semanal**: grafico de barras com cards previstos para os proximos 7 dias

### Temas e Design

- **Material 3 / Material You** com cores dinamicas do wallpaper do dispositivo
- **3 modos de tema**: Claro, Escuro e Automatico (segue o sistema)
- Design acolhedor com cantos arredondados (20-28px), cores pastel e emojis
- Cor semente: rosa-lavanda (`#D4A0B9`)
- Contraste inteligente: cores pastel sao escurecidas automaticamente em fundo claro para garantir legibilidade
- Navegacao inferior com labels sempre visiveis e indicadores arredondados
- Transicoes de tela com slide + fade

### Backup e Restauracao

- **Exportar** todos os decks e cards como arquivo `.anaapp.json`
- **Importar** backup com geracao de novos IDs (seguro para duplicatas)
- Compartilhamento via qualquer app (WhatsApp, email, Drive, etc.)
- Compatibilidade retroativa com formatos antigos de backup

### Configuracoes

- Perfil do usuario com avatar (letra inicial) e edicao de nome
- Campo seguro para chave de API OpenAI com validacao automatica
- Alternador de tema visual com animacao de selecao
- Informacoes da versao do app

---

## Arquitetura

```
lib/
├── core/
│   ├── constants/       # Constantes do app e da OpenAI
│   ├── errors/          # Classes de erro/falha
│   ├── theme/           # Tema Material 3, cores
│   └── utils/           # SM-2 scheduler, PDF parser, image helper
├── data/
│   ├── datasources/
│   │   ├── local/       # SQLite DAOs (deck, flashcard, review, user, tag)
│   │   └── remote/      # OpenAI client (chat, image, tag assignment)
│   ├── models/          # Modelos de dados (mapeamento DB <-> entidade)
│   └── repositories/    # Implementacoes dos repositorios
├── domain/
│   ├── entities/        # Entidades puras (Deck, Flashcard, ReviewLog, etc.)
│   ├── repositories/    # Interfaces dos repositorios
│   └── usecases/        # Casos de uso (gerar cards, revisar, exportar, etc.)
└── presentation/
    ├── providers/       # Riverpod providers e notifiers
    ├── screens/         # Telas do app (home, decks, review, stats, etc.)
    └── widgets/         # Widgets reutilizaveis (flip card, rating buttons, etc.)
```

| Conceito | Escolha |
|---|---|
| Padrao | Clean Architecture + MVVM |
| State Management | Riverpod 2 |
| Banco de Dados | SQLite (sqflite) |
| IA - Texto | OpenAI GPT-4o-mini |
| IA - Imagens | OpenAI DALL-E 2 |
| Design System | Material 3 / Material You |
| Graficos | fl_chart |
| PDF | Syncfusion Flutter PDF |
| Armazenamento Seguro | flutter_secure_storage |
| Cores Dinamicas | dynamic_color |

---

## Como Usar

### Pre-requisitos

- Flutter SDK 3.41+
- Dart SDK 3.11+
- Chave de API da OpenAI (opcional — o app funciona sem ela, apenas a geracao com IA fica desabilitada)

### Instalacao

```bash
# Clone o repositorio
git clone https://github.com/seu-usuario/AnaApp.git
cd AnaApp

# Instale as dependencias
flutter pub get

# Execute o app
flutter run
```

### Configurando a IA

1. Abra o app e va em **Ajustes**
2. Cole sua chave de API da OpenAI no campo indicado
3. O app valida a chave automaticamente
4. Pronto! Agora voce pode gerar flashcards com IA

> A chave e armazenada localmente no dispositivo com criptografia (flutter_secure_storage). Nenhum dado e enviado para servidores proprios — a comunicacao e direta com a API da OpenAI.

---

## Licenca

Este projeto esta licenciado sob a [MIT License](LICENSE).

---

<p align="center">
  Feito com 💜 e muita repeticao espacada.
</p>
