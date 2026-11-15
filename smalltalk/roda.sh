#!/usr/bin/env bash
# roda.sh — executa uma lição em Smalltalk, sem interface.
#
#     ./smalltalk/roda.sh 3
#
# ## O Pharo, e por que não o GNU Smalltalk
#
# O caminho óbvio seria `gnu-smalltalk`, que é CLI e simples. Ele **não existe
# mais** no Ubuntu 26.04 — saiu do Debian por falta de manutenção.
#
# As alternativas no apt foram testadas e não servem: `squeak-vm` instala e a
# VM sobe (`squeakvm -version` responde), mas a imagem do `etoys` ignora o
# arquivo `.st` passado como argumento e nada é avaliado.
#
# O **Pharo** é o descendente vivo do Smalltalk-80, é livre (MIT), e tem modo
# de linha de comando de primeira classe. Ele não está empacotado no Ubuntu,
# então é instalado por download — ver `AMBIENTE.md` no índice do portfólio,
# que registra isso junto com os comandos de remoção.
#
# ## Duas descobertas sobre o CLI do Pharo
#
# **`eval` é só para uma linha.** A descrição do próprio subcomando diz:
# *"Directly evaluates passed in one line scripts"*. Um programa de várias
# linhas passado para `eval` dá erro de parse apontando para a última linha,
# o que sugere problema no código e não na ferramenta. O subcomando certo é
# `st`, descrito como *"Loads and executes .st source files"*.
#
# **`FileStream` não existe mais.** A API clássica de Smalltalk-80 para
# stdout — `FileStream stdout` — foi removida no Pharo 9. O erro é
# `#FileStream is missing, and does not understand #stdout`, e a substituta é
# `Stdio stdout`. É o tipo de mudança que faz todo tutorial antigo de
# Smalltalk falhar na primeira linha.

set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"

# A instalação do Pharo é configurável porque ele não tem pacote: cada máquina
# o coloca em outro lugar. O padrão é onde `AMBIENTE.md` diz que ele está.
PHARO_DIR="${PHARO_DIR:-$HOME/pharo}"

if [ $# -lt 1 ]; then
    echo "uso: roda.sh <1..5>" >&2
    exit 64
fi

case "$1" in
    [1-5]) LICAO="$1" ;;
    *) echo "lição fora de 1..5: $1" >&2; exit 64 ;;
esac

VM="$PHARO_DIR/vm/pharo"
if [ ! -x "$VM" ]; then
    echo "Pharo não encontrado em $PHARO_DIR." >&2
    echo "Instale (livre, MIT) com:" >&2
    echo "  mkdir -p ~/pharo/vm ~/pharo/img && cd ~/pharo" >&2
    echo "  curl -L -o vm.zip https://files.pharo.org/vm/pharo-spur64-headless/Linux-x86_64/stable.zip" >&2
    echo "  curl -L -o img.zip https://files.pharo.org/image/110/latest-64.zip" >&2
    echo "  unzip -q vm.zip -d vm && unzip -q img.zip -d img" >&2
    exit 69
fi

IMG="$(find "$PHARO_DIR/img" -maxdepth 2 -name '*.image' 2>/dev/null | head -1)"
if [ -z "$IMG" ]; then
    echo "nenhuma .image em $PHARO_DIR/img" >&2
    exit 69
fi

TMP="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMP'" EXIT

SAIDA="$TMP/traco.txt"

# O programa executado: carrega as licoes e escreve o traco num arquivo.
#
# Por arquivo, e nao por stdout, pelo mesmo motivo do Logo deste projeto: a
# saida de uma VM de imagem vem misturada com avisos de carga, e separar
# "o traco" de "o barulho da VM" por filtro de texto e fragil. Um arquivo
# contem exatamente o que o programa escreveu.
#
# `asFileReference writeStreamDo:` e a API do Pharo 11. `FileStream` -- a
# classica do Smalltalk-80 -- foi REMOVIDA no Pharo 9.
# As licoes e o programa viram UM arquivo.
#
# O subcomando `st` aceita um `<FILE>` so -- passar dois faz o segundo ser
# ignorado em silencio. Concatenar e o que permite a classe definida nas
# licoes estar disponivel para o programa, sem precisar salvar a imagem com a
# classe dentro (o que tornaria o repositorio dono de um binario de 23 MB).
#
# O separador de chunk entre os dois e obrigatorio: sem ele o programa seria
# compilado junto com a definicao da classe, e `Tartaruga` ainda nao
# existiria -- e o sintoma e vinte avisos de 'Tartaruga is Undeclared'.
{
    cat "$AQUI/licoes.st"
    printf '\n'
    cat <<ST
| t |
t := Tartaruga new.
t licaoNumero: $LICAO.
'$SAIDA' asFileReference writeStreamDo: [ :s | s nextPutAll: t traco ]!
ST
} > "$TMP/completo.st"

# `--quit` e OBRIGATORIO, e a documentacao do proprio subcomando avisa:
# "The ST command line handler runs Pharo code stored in a file WITHOUT
# QUITING". Sem a flag, o arquivo e avaliado, nada falha, e o processo fica
# vivo para sempre -- com stdout VAZIO, que e indistinguivel de travamento.
#
# Foi o terceiro timeout desta integracao, e o unico cuja causa estava escrita
# na ajuda da ferramenta.
if ! (cd "$TMP" && "$VM" "$IMG" st --quit "$TMP/completo.st") \
        </dev/null >"$TMP/vm.out" 2>"$TMP/vm.err"; then
    echo "o Pharo falhou:" >&2
    head -8 "$TMP/vm.out" "$TMP/vm.err" >&2
    exit 1
fi

# Falha ALTO se o traco nao apareceu.
#
# Sem isto, um erro de Smalltalk (que o Pharo reporta em stdout junto com a
# pilha) viraria "traco vazio", e a suite acusaria DIVERGENCIA em vez de "o
# programa nao rodou".
if [ ! -s "$SAIDA" ]; then
    echo "o Smalltalk não produziu traço para a lição $LICAO." >&2
    echo "--- saída da VM ---" >&2
    head -10 "$TMP/vm.out" >&2
    exit 1
fi

cat "$SAIDA"
