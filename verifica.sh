#!/usr/bin/env bash
# verifica.sh — a suíte do p14-first-code.
#
# A tese é que quatro linguagens ensinam a MESMA progressão de conceitos, e a
# prova é que as quatro produzem o MESMO traço de tartaruga, byte a byte.
# Este script é o que torna isso verificável em vez de afirmado.
#
# Nunca `set -e`: ele aborta no primeiro `[ ]` falso e a suíte vira "para no
# primeiro erro" em vez de "relata todos".
set -uo pipefail

cd "$(dirname "$0")"

OK=0
FALHOU=0
PULADO=0

# P14_EXIGE=1 transforma todo "pulado" em FALHA, e o CI o liga.
#
# Local, pular e certo: o Logo precisa de `xvfb` e o Blockly de `npm`, e nem
# toda maquina tem. No CI, pular e PERIGOSO -- uma dependencia ausente
# passaria verde tendo verificado metade. Mesma politica do p10-query-lab.
EXIGE="${P14_EXIGE:-0}"

verde()    { printf '\033[32m%s\033[0m' "$1"; }
vermelho() { printf '\033[31m%s\033[0m' "$1"; }
cinza()    { printf '\033[90m%s\033[0m' "$1"; }

passa() { printf '  %s    %s\n' "$(verde ok)" "$1"; OK=$((OK+1)); }
falha() { printf '  %s %s\n' "$(vermelho FALHA)" "$1"; FALHOU=$((FALHOU+1)); }
pula()  {
    if [ "$EXIGE" = "1" ]; then
        printf '  %s %s\n' "$(vermelho FALHA)" "$1 (P14_EXIGE=1)"
        FALHOU=$((FALHOU+1))
    else
        printf '  %s  %s\n' "$(cinza pulado)" "$1"
        PULADO=$((PULADO+1))
    fi
}
secao() { printf '\n%s\n' "$(cinza "$1")"; }
tem()   { command -v "$1" >/dev/null 2>&1; }

# Compara a saída de um comando com o traço esperado de uma lição.
#
# O comando roda SEM cano: capturar em variável e só então comparar.
#
# Isso não é estilo. Um `| head` fecha o cano antes do fim, o produtor recebe
# EPIPE, e o sintoma é indistinguível de travamento -- aconteceu neste
# projeto com o gerador do Blockly, e já havia acontecido três vezes no resto
# do portfólio. O instrumento escondendo o sinal é a falha recorrente aqui.
compara() {  # $1 = rótulo, $2 = lição, $3.. = comando
    local rotulo="$1" licao="$2"; shift 2
    local obtido esperado ret
    esperado="$(cat "dados/esperado/licao${licao}.traco")"
    obtido="$("$@" 2>/dev/null)"; ret=$?

    if [ $ret -ne 0 ]; then
        falha "$rotulo lição $licao: o comando saiu com $ret"
        return
    fi
    if [ "$obtido" = "$esperado" ]; then
        passa "$rotulo lição $licao idêntica à referência"
    else
        falha "$rotulo lição $licao divergiu"
        diff <(printf '%s\n' "$obtido") "dados/esperado/licao${licao}.traco" \
            | head -4 | sed 's/^/        /'
    fi
}

printf '\n%s\n' '=============================================================='
printf '%s\n' 'first-code — a mesma lição, quatro linguagens, um traço'
printf '%s\n' '=============================================================='

# ---------------------------------------------------------------------------
secao 'pascal/ — a implementação de referência'

if ! tem fpc; then
    pula 'fpc ausente: sudo apt-get install fp-compiler'
else
    # `-Sewn`: aviso vira erro. A primeira versao do licoes.pas foi RECUSADA
    # por isso -- a prosa de um comentario citava diretivas entre chaves, e
    # chave dentro de comentario de chave e comentario aninhado.
    if fpc -O2 -Sewn -vw -obin_licoes pascal/licoes.pas >/dev/null 2>&1 \
       && [ -x pascal/bin_licoes ]; then
        passa 'o Pascal compila com aviso tratado como erro'
    else
        falha 'o Pascal não compila'
    fi

    if [ -x pascal/bin_licoes ]; then
        for n in 1 2 3 4 5; do
            compara Pascal "$n" ./pascal/bin_licoes "$n"
        done

        # A EQUIVALENCIA que e o conteudo da licao 2.
        if diff -q dados/esperado/licao1.traco \
                   dados/esperado/licao2.traco >/dev/null 2>&1; then
            passa 'lição 1 == lição 2: o laço é abreviação, e o diff sai vazio'
        else
            falha 'a equivalência entre sequência e repetição quebrou'
        fi

        # Lição fora de 1..5 tem de ser recusada, nao ignorada.
        if ! ./pascal/bin_licoes 9 >/dev/null 2>&1; then
            passa 'lição inválida é recusada'
        else
            falha 'lição 9 foi aceita'
        fi
    fi
fi

# ---------------------------------------------------------------------------
secao 'logo/ — a ferramenta não tem console, a linguagem tem arquivo'

if ! tem ucblogo || ! tem xvfb-run; then
    pula 'ucblogo ou xvfb ausente: sudo apt-get install ucblogo xvfb'
else
    for n in 1 2 3 4 5; do
        compara Logo "$n" bash logo/roda.sh "$n"
    done

    # `pu` e `pd` sao PRIMITIVAS do UCBLogo, e redefinir faz ele PERGUNTAR no
    # REPL em vez de abortar -- sob xvfb isso pendura ate o timeout, sem
    # mensagem nenhuma em stdout. Este teste trava o nome corrigido.
    if ! grep -qE '^to (pu|pd)$' logo/licoes.lg; then
        passa 'nenhum procedimento chamado pu/pd (são primitivas)'
    else
        falha 'to pu ou to pd voltou: o UCBLogo vai pendurar no REPL'
    fi

    # Os caminhos no programa gerado precisam de `"|...|`, porque em Logo
    # `"palavra` termina no primeiro espaco -- e o caminho deste repositorio
    # TEM espaco.
    if grep -q 'load "|' logo/roda.sh; then
        passa 'os caminhos usam "|...| (o repositório tem espaço no nome)'
    else
        falha 'caminho sem barras verticais: quebra em pasta com espaço'
    fi
fi

# ---------------------------------------------------------------------------
secao 'scratch/ — gerado aqui, e interpretado aqui'

if ! tem python3; then
    pula 'python3 ausente'
else
    if python3 scratch/gera.py >/dev/null 2>&1; then
        passa 'os cinco .sb3 são gerados, com integridade de blocos conferida'
    else
        falha 'a geração dos .sb3 falhou'
    fi

    for n in 1 2 3 4 5; do
        compara Scratch "$n" python3 scratch/simula.py "scratch/licao$n.sb3"
    done

    # DETERMINISMO: gerar duas vezes tem de dar o MESMO byte.
    #
    # Sem isto, cada execucao da suite sujaria o diff do git. As duas fontes
    # de variacao sao compressao e carimbo de tempo do ZIP, e as duas estao
    # fixadas no gera.py.
    antes=$(md5sum scratch/licao3.sb3 | cut -d' ' -f1)
    python3 scratch/gera.py >/dev/null 2>&1
    depois=$(md5sum scratch/licao3.sb3 | cut -d' ' -f1)
    if [ "$antes" = "$depois" ]; then
        passa 'o .sb3 é byte a byte igual a cada geração'
    else
        falha 'o .sb3 muda entre gerações: o diff do git ficaria sujo'
    fi

    # O simulador RECUSA opcode que nao conhece.
    #
    # Um simulador que ignora o desconhecido aprovaria um projeto que o
    # Scratch de verdade recusa -- e o traco bateria, dando impressao de
    # verificacao onde nao ha nenhuma.
    tmp=$(mktemp -d)
    python3 - "$tmp" <<'PY' >/dev/null 2>&1
import json, sys, zipfile, os
d = sys.argv[1]
proj = {"targets": [
    {"isStage": True, "name": "Stage", "blocks": {}},
    {"isStage": False, "name": "T", "blocks": {
        "b1": {"opcode": "motion_gotoxy", "next": None, "parent": None,
               "inputs": {}, "fields": {}, "shadow": False, "topLevel": True}}},
], "monitors": [], "extensions": [], "meta": {"semver": "3.0.0"}}
with zipfile.ZipFile(os.path.join(d, "ruim.sb3"), "w") as z:
    z.writestr("project.json", json.dumps(proj))
PY
    if ! python3 scratch/simula.py "$tmp/ruim.sb3" >/dev/null 2>&1; then
        passa 'o simulador recusa opcode desconhecido, em vez de ignorar'
    else
        falha 'o simulador ACEITOU motion_gotoxy, que ele não implementa'
    fi
    rm -rf "$tmp"
fi

# ---------------------------------------------------------------------------
secao 'blockly/ — construir o editor, não só usá-lo'

if ! tem node || ! tem npm; then
    pula 'node ou npm ausente: sudo apt-get install nodejs npm'
else
    if python3 blockly/monta_licoes.py >/dev/null 2>&1; then
        passa 'os XML de blocos são gerados'
    else
        falha 'a geração dos XML falhou'
    fi

    for n in 1 2 3 4 5; do
        compara Blockly "$n" bash blockly/roda.sh "$n"
    done

    # A contagem de blocos E o conteudo da licao 2: 8 blocos viram 3.
    n1=$(bash blockly/roda.sh 1 --blocos 2>/dev/null)
    n2=$(bash blockly/roda.sh 2 --blocos 2>/dev/null)
    if [ "$n1" = "8" ] && [ "$n2" = "3" ]; then
        passa "a lição 2 faz o mesmo com 3 blocos onde a 1 usa 8"
    else
        falha "contagem de blocos inesperada: lição 1=$n1, lição 2=$n2"
    fi

    # O gerador de codigo `forge` -- a ponte com o p02-forge-lang.
    saida=$(bash blockly/roda.sh 2 --forge 2>/dev/null)
    if printf '%s' "$saida" | grep -q 'repete 4'; then
        passa 'o gerador forge emite o laço como `repete`'
    else
        falha "o gerador forge não produziu o esperado: $saida"
    fi

    # `scrub_` e OBRIGATORIO e a sua ausencia nao da erro: sem ele o gerador
    # emite SO O PRIMEIRO bloco de cada pilha. Aconteceu, e este teste trava.
    if grep -q 'traco.scrub_' blockly/blocos.js; then
        passa 'o gerador do traço define scrub_ (sem ele, só o 1º bloco sai)'
    else
        falha 'traco.scrub_ desapareceu: o gerador vai emitir 1 bloco por pilha'
    fi
fi

printf '\n%s\n' '=============================================================='
if [ "$PULADO" -gt 0 ]; then
    printf '  %s passaram, %s falharam, %s pulado(s)\n' \
        "$(verde "$OK")" "$FALHOU" "$(cinza "$PULADO")"
else
    printf '  %s passaram, %s falharam\n' "$(verde "$OK")" "$FALHOU"
fi
printf '%s\n\n' '=============================================================='

[ "$FALHOU" -eq 0 ]
