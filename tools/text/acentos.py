"""Corretor de acentos pt-BR para os textos do portfólio (dados do museu, perfil, projetos, falas).

Uso: python tools/text/acentos.py [--fix]   (sem --fix só lista o que mudaria)
Aplica um dicionário de palavras comuns escritas sem acento e algumas regras de contexto seguras
(ex.: "<Nome> e um/uma" -> "é um/uma"). Só mexe em campos de texto em português (chaves pt, titulo,
texto, loja, ambiente, title, text, desc..., nunca em chaves *_en, en, ids, links).
"""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORDS = {
 "voce": "você", "voces": "vocês", "codigo": "código", "codigos": "códigos", "unico": "único", "unica": "única",
 "orcamento": "orçamento", "orcamentos": "orçamentos", "conclusao": "conclusão", "cobranca": "cobrança",
 "curriculo": "currículo", "curriculos": "currículos", "tambem": "também", "nao": "não", "sao": "são", "ate": "até",
 "ja": "já", "so": "só", "integracao": "integração", "integracoes": "integrações", "aplicacao": "aplicação",
 "aplicacoes": "aplicações", "autenticacao": "autenticação", "configuracao": "configuração",
 "informacao": "informação", "informacoes": "informações", "sessao": "sessão", "sessoes": "sessões",
 "versao": "versão", "area": "área", "areas": "áreas", "pagina": "página", "paginas": "páginas",
 "usuario": "usuário", "usuarios": "usuários", "numero": "número", "numeros": "números", "historico": "histórico",
 "tecnico": "técnico", "tecnica": "técnica", "basico": "básico", "logica": "lógica", "grafico": "gráfico",
 "graficos": "gráficos", "publico": "público", "publica": "pública", "rapido": "rápido", "rapida": "rápida",
 "facil": "fácil", "faceis": "fáceis", "necessario": "necessário", "possivel": "possível", "disponivel": "disponível",
 "automatico": "automático", "automatica": "automática", "referencia": "referência", "experiencia": "experiência",
 "inteligencia": "inteligência", "tecnologia": "tecnologia", "clinicas": "clínicas", "clinica": "clínica",
 "estudios": "estúdios", "estudio": "estúdio", "pos-venda": "pós-venda", "metrica": "métrica", "metricas": "métricas",
 "analise": "análise", "analises": "análises", "licitacao": "licitação", "licitacoes": "licitações",
 "telefonica": "telefônica", "paineis": "painéis", "painel": "painel", "funcao": "função", "funcoes": "funções",
 "solucao": "solução", "solucoes": "soluções", "gestao": "gestão", "comunicacao": "comunicação",
 "producao": "produção", "conteudo": "conteúdo", "conteudos": "conteúdos", "negocio": "negócio", "negocios": "negócios",
 "servico": "serviço", "servicos": "serviços", "midia": "mídia", "video": "vídeo", "videos": "vídeos",
 "audio": "áudio", "audios": "áudios", "musica": "música", "musicas": "músicas", "inicio": "início",
 "proximo": "próximo", "proxima": "próxima", "ultimo": "último", "ultima": "última", "rapidez": "rapidez",
 "seguranca": "segurança", "financas": "finanças", "relatorio": "relatório", "relatorios": "relatórios",
 "diagnostico": "diagnóstico", "mecanica": "mecânica", "mecanicas": "mecânicas", "fisica": "física",
 "unicos": "únicos", "minimo": "mínimo", "maximo": "máximo", "otimo": "ótimo", "util": "útil", "uteis": "úteis",
 "codificacao": "codificação", "construcao": "construção", "atencao": "atenção", "exibicao": "exibição",
 "transcricao": "transcrição", "traducao": "tradução", "navegacao": "navegação", "interacao": "interação",
 "interacoes": "interações", "decisao": "decisão", "decisoes": "decisões", "visao": "visão", "missao": "missão",
 "camera": "câmera", "cameras": "câmeras", "agencia": "agência", "familia": "família", "historia": "história",
 "historias": "histórias", "memoria": "memória", "estrategia": "estratégia", "academico": "acadêmico",
 "pratico": "prático", "pratica": "prática", "classico": "clássico", "dinamico": "dinâmico", "dinamica": "dinâmica",
 "voz": "voz", "porem": "porém", "alem": "além", "atraves": "através", "tres": "três", "mes": "mês", "meses": "meses",
 "facilmente": "facilmente", "codigo-fonte": "código-fonte", "aniversario": "aniversário", "calendario": "calendário",
 "horario": "horário", "horarios": "horários", "agendamento": "agendamento", "comissoes": "comissões",
 "reposicao": "reposição", "assinatura": "assinatura", "notificacao": "notificação", "notificacoes": "notificações",
 "multiplos": "múltiplos", "multiplas": "múltiplas", "proprio": "próprio", "propria": "própria", "proprios": "próprios",
 "espaco": "espaço", "comeco": "começo", "preco": "preço", "precos": "preços", "duvida": "dúvida", "duvidas": "dúvidas",
 "repeticao": "repetição", "espacada": "espaçada", "metodo": "método", "metodos": "métodos", "cartao": "cartão",
 "cartoes": "cartões", "fluencia": "fluência", "saida": "saída", "saidas": "saídas", "cenario": "cenário",
 "cenarios": "cenários", "exportacao": "exportação", "distribuicao": "distribuição", "organizacao": "organização",
 "automacao": "automação", "orquestracao": "orquestração", "validacao": "validação", "operacao": "operação",
 "atualizacao": "atualização", "manutencao": "manutenção", "conexao": "conexão", "conexoes": "conexões",
 "padrao": "padrão", "padroes": "padrões", "botao": "botão", "botoes": "botões", "regiao": "região",
 "opcao": "opção", "opcoes": "opções", "permissao": "permissão", "permissoes": "permissões", "colecao": "coleção",
 "codigos-fonte": "códigos-fonte", "dialogo": "diálogo", "dialogos": "diálogos", "personagem": "personagem",
 "veiculo": "veículo", "veiculos": "veículos", "graficos3d": "gráficos 3D", "fase": "fase", "nivel": "nível",
 "niveis": "níveis", "previa": "prévia", "rascunho": "rascunho", "conteudista": "conteudista", "acessivel": "acessível", "acessiveis": "acessíveis", "ha": "há",
 "possiveis": "possíveis", "visivel": "visível", "invisivel": "invisível", "movel": "móvel", "moveis": "móveis",
 "provavel": "provável", "responsavel": "responsável", "responsaveis": "responsáveis", "incrivel": "incrível",
 "agil": "ágil", "ageis": "ágeis", "facilidade": "facilidade", "possibilidade": "possibilidade",
}
SKIP_KEYS = re.compile(r"(^|_)(en|id|ids|url|link|links|site|github|slug|img|image|images|file|icon|color|neon|source|license)$", re.I)


def fix_text(s):
    def rep(m):
        w = m.group(0)
        low = w.lower()
        if low not in WORDS or WORDS[low] == low:
            return w
        r = WORDS[low]
        if w.isupper():
            return r.upper()
        if w[0].isupper():
            return r[0].upper() + r[1:]
        return r
    out = re.sub(r"[A-Za-zÀ-ÿ\-]+", rep, s)
    # "<Nome> e um/uma/o/a" (verbo ser) logo depois de nome próprio no começo da frase
    out = re.sub(r"(^|[.!?]\s+)([A-ZÀ-Ý][\wÀ-ÿ0-9]+(?:\s[A-ZÀ-Ý0-9][\wÀ-ÿ0-9]*)?)\s+e\s+(um|uma|o|a|feito|feita)\b",
                 lambda m: m.group(1) + m.group(2) + " é " + m.group(3), out)
    out = re.sub(r"([Ee])sta (no|na|nos|nas|em|sempre|pronto|pronta|aqui|ali|tudo|ligado|ligada)",
                 lambda m: ("E" if m.group(1) == "E" else "e") + "stá " + m.group(2), out)
    return out


def walk(o, key=""):
    changes = []
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(v, str) and not SKIP_KEYS.search(k):
                n = fix_text(v)
                if n != v:
                    changes.append((v, n))
                    o[k] = n
            else:
                changes += walk(v, k)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            if isinstance(v, str) and not SKIP_KEYS.search(key):
                n = fix_text(v)
                if n != v:
                    changes.append((v, n))
                    o[i] = n
            else:
                changes += walk(v, key)
    return changes


def targets():
    out = []
    for d in ("data/museum", "game/assets/data/museum"):
        p = os.path.join(ROOT, d)
        if os.path.isdir(p):
            out += [os.path.join(p, f) for f in os.listdir(p) if f.endswith(".json")]
    for f in ("data/profile.json", "data/projects.json", "game/assets/data/profile.json", "game/assets/data/projects.json"):
        if os.path.exists(os.path.join(ROOT, f)):
            out.append(os.path.join(ROOT, f))
    p = os.path.join(ROOT, "game", "assets", "museum", "_items")
    if os.path.isdir(p):
        out += [os.path.join(p, f) for f in os.listdir(p) if f.endswith(".json")]
    return out


if __name__ == "__main__":
    fix = "--fix" in sys.argv
    total = 0
    for f in targets():
        data = json.load(open(f, encoding="utf8"))
        ch = walk(data)
        if ch:
            total += len(ch)
            print("==", os.path.relpath(f, ROOT), len(ch))
            for a, b in ch[:6]:
                print("  -", a[:90]); print("  +", b[:90])
            if fix:
                json.dump(data, open(f, "w", encoding="utf8"), ensure_ascii=False, indent=2)
    print("total", total)
