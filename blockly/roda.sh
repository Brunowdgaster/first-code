#!/usr/bin/env bash
# roda.sh — executa o gerador de blocos, com as dependências no lugar certo.
#
#     ./blockly/roda.sh 2            # o traço da lição 2
#     ./blockly/roda.sh 2 --forge    # a mesma lição em código forge
#     ./blockly/roda.sh 2 --blocos
#
# ## O problema: 98 segundos para gerar 8 linhas
#
# O Blockly traz **2302 arquivos** em `node_modules`. Quando o repositório
# está num caminho `/mnt/c` -- ou seja, no sistema de arquivos do Windows
# visto pelo WSL2 -- cada `require` atravessa a camada de tradução, e o custo
# medido nesta máquina foi:
#
#     node blockly/gera.js 1   em /mnt/c   ->  1m38s   (user 2,8s, sys 6,2s)
#     o mesmo, cache quente    em /mnt/c   ->  1m21s
#     o mesmo, node_modules no ext4        ->  0m1,6s
#
# Noventa segundos de **espera de I/O** para 2,8 segundos de CPU. A conta é
# 2302 arquivos pequenos: é exatamente o caso em que a DrvFs é mais lenta, e
# o mesmo fenômeno que no `p03-otp-mesh` custou 5,5x numa build autocontida
# de .NET -- aqui chega a 60x.
#
# ## A armadilha que isso criou, e que vale mais que o número
#
# O primeiro teste deste gerador PASSOU, e os seguintes "penduraram". Nada
# havia mudado no código.
#
# O primeiro rodou logo depois do `npm install`, com o cache de arquivos do
# Windows quente. Os seguintes rodaram frios, levaram ~90s, e o `timeout 60`
# do meu teste os matou -- reportando 124, que eu leio como "pendurou".
#
# Então um teste que falha por timeout não distingue "o programa travou" de
# "o programa é mais lento que o meu limite". E a conclusão errada era
# plausível: eu tinha acabado de mexer no gerador.
#
# ## A solução
#
# As dependências ficam num diretório do sistema de arquivos do Linux, fora
# de `/mnt/c`, e o Node é apontado para lá via `NODE_PATH`. O
# `package.json`/`package-lock.json` continuam no repositório, com versão
# fixa; o que sai de `/mnt/c` é só a árvore instalada, que é gerada.
#
# Em CI isto é inofensivo: o runner do GitHub é Linux nativo, não há `/mnt/c`,
# e o diretório de cache é só mais um caminho.

set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"

# O cache fica fora do repositorio de proposito: `node_modules` e ARTEFATO,
# reconstruivel a partir do package-lock.json, e um diretorio de 2302
# arquivos dentro do repositorio e um convite para commitar por acidente.
CACHE="${P14_CACHE:-$HOME/.cache/p14-first-code}"

if ! command -v node >/dev/null 2>&1; then
    echo "node ausente: sudo apt-get install nodejs" >&2
    exit 69
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "npm ausente: sudo apt-get install npm" >&2
    exit 69
fi

# Reinstala quando o lock muda. Comparar o lock, e nao so testar se o
# diretorio existe, e o que impede o cache de ficar velho em silencio depois
# de uma atualizacao de dependencia.
LOCK_ATUAL="$AQUI/package-lock.json"
LOCK_CACHE="$CACHE/package-lock.json"

precisa_instalar=0
if [ ! -d "$CACHE/node_modules/blockly" ]; then
    precisa_instalar=1
elif [ ! -f "$LOCK_CACHE" ] || ! cmp -s "$LOCK_ATUAL" "$LOCK_CACHE"; then
    precisa_instalar=1
fi

if [ "$precisa_instalar" = "1" ]; then
    echo "instalando as dependências em $CACHE (fora de /mnt/c)..." >&2
    mkdir -p "$CACHE"
    cp "$AQUI/package.json" "$AQUI/package-lock.json" "$CACHE/" || exit 1
    # `npm ci` e nao `npm install`: ele instala EXATAMENTE o que o lock diz e
    # falha se o package.json divergir, em vez de resolver de novo.
    if ! (cd "$CACHE" && npm ci --silent --no-audit --no-fund >&2); then
        echo "npm ci falhou em $CACHE" >&2
        exit 1
    fi
fi

# `NODE_PATH` e o que faz o `require` achar o blockly instalado fora da arvore
# do script. O gera.js em si nao sabe nada disso -- ele so faz
# `require('blockly/core')`, como qualquer codigo Node.
export NODE_PATH="$CACHE/node_modules"

exec node "$AQUI/gera.js" "$@"
