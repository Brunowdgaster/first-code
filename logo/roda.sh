#!/usr/bin/env bash
# roda.sh — executa uma lição do currículo em Logo, sem interface.
#
#     ./logo/roda.sh 3        # imprime o traço da lição 3 em stdout
#
# ## O problema que este script resolve
#
# O `ucblogo` do Ubuntu é compilado contra wxWidgets/GTK3/X11: é build **só
# gráfico**. Sem display ele não escreve nada em stdout -- nem `--help` -- e
# sai com código 0. Medido:
#
#     $ ucblogo programa.lg < /dev/null ; echo $?
#     0
#     $ # zero bytes em stdout E em stderr
#
# A saída não desaparece: ela vai para a janela de texto do wx, que não
# existe. E não há opção de linha de comando para mudar isso -- o binário não
# tem modo console.
#
# ## A solução está na LINGUAGEM, não na ferramenta
#
# Logo tem `openwrite` e `setwrite` desde sempre: comandos da própria
# linguagem que redirecionam a saída do programa para um arquivo. Eles
# funcionam independentemente de onde a janela estaria.
#
# Então:
#
#   1. `xvfb-run` dá um display virtual, e o UCBLogo real sobe;
#   2. um programa gerado carrega `licoes.lg`, abre o arquivo de saída,
#      redireciona, chama a lição, fecha e sai;
#   3. este script lê o arquivo e escreve em stdout.
#
# Procurar a opção de linha de comando que não existe custou mais que ler o
# que o Logo sabe fazer desde 1967.
#
# ## Por que o programa é gerado, e `licoes.lg` fica limpo
#
# `logo/licoes.lg` é Logo puro: cinco lições e a tartaruga, sem uma linha de
# encanamento. Misturar `openwrite` ali tornaria o arquivo ilegível para quem
# quer LER o currículo -- que é o público deste projeto.

set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"

if [ $# -ne 1 ]; then
    echo "uso: roda.sh <1..5>" >&2
    exit 64
fi

LICAO="$1"
case "$LICAO" in
    [1-5]) ;;
    *) echo "lição fora de 1..5: $LICAO" >&2; exit 64 ;;
esac

for cmd in ucblogo xvfb-run; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd ausente: sudo apt-get install ucblogo xvfb" >&2
        exit 69
    fi
done

TMP="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMP'" EXIT

SAIDA="$TMP/traco.txt"

# O programa gerado. `bye` no fim e OBRIGATORIO: sem ele o UCBLogo fica no
# REPL esperando entrada, e sob xvfb-run isso pendura ate o timeout sem
# mensagem nenhuma -- o mesmo tipo de armadilha da caixa de dialogo do
# AutoHotkey no p12-toolbelt.
# ## As barras verticais em `"|...|` sao OBRIGATORIAS, e nao estilo
#
# Em Logo, `"palavra` e um literal que TERMINA NO PRIMEIRO ESPACO. Se o
# caminho do repositorio tiver espaco -- e o deste portfolio tem, a pasta se
# chama "para se gabar" -- entao
#
#     load "/mnt/c/.../para se gabar/licoes.lg
#
# e lido como `load "/mnt/c/.../para`, seguido das palavras soltas `se` e
# `gabar/licoes.lg`. O arquivo nunca carrega, as licoes nao existem, e o
# UCBLogo reporta o erro na janela que nao ha -- entao o sintoma e um traco
# VAZIO, sem mensagem nenhuma.
#
# As barras verticais sao o escape da propria linguagem Logo. Medido:
#
#     load "caminho com espaco     -> falhou (traco vazio)
#     load "|caminho com espaco|   -> funcionou
#
# E o detalhe que faz disso uma licao: as aspas do SHELL nao resolvem. Elas
# protegem o caminho ate ele chegar aqui -- e o caminho e escrito DENTRO de um
# programa Logo, onde quem manda e a sintaxe do Logo. Toda outra linguagem
# deste portfolio tolerou os espacos porque recebe o caminho como argumento;
# esta recebe como codigo.
cat > "$TMP/roda.lg" <<LOGO
load "|$AQUI/licoes.lg|
openwrite "|$SAIDA|
setwrite "|$SAIDA|
licao$LICAO
setwrite []
close "|$SAIDA|
bye
LOGO

# stdin em /dev/null pelo mesmo motivo do `bye`: duas defesas contra o REPL,
# porque uma falha silenciosa aqui custa um timeout em vez de um erro.
if ! xvfb-run -a ucblogo "$TMP/roda.lg" </dev/null >"$TMP/stdout.txt" 2>"$TMP/stderr.txt"; then
    echo "o ucblogo falhou:" >&2
    head -5 "$TMP/stderr.txt" >&2
    exit 1
fi

# Falha ALTO se o arquivo nao apareceu.
#
# Sem esta checagem, um erro de Logo (que o UCBLogo reporta na janela que nao
# existe) viraria "traco vazio", e a suite acusaria DIVERGENCIA de traco em
# vez de "o programa nao rodou". Distinguir os dois e a diferenca entre um log
# que aponta a causa e um que manda procurar.
if [ ! -s "$SAIDA" ]; then
    echo "o Logo não produziu traço para a lição $LICAO." >&2
    echo "stdout e stderr do ucblogo (devem estar vazios -- ele é build gráfico):" >&2
    head -3 "$TMP/stdout.txt" "$TMP/stderr.txt" >&2
    exit 1
fi

cat "$SAIDA"
