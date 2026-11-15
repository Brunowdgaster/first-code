#!/usr/bin/env python3
"""monta_licoes.py — escreve os XML de blocos das cinco lições.

    python3 blockly/monta_licoes.py

## Por que um gerador, se os XML são o artefato

Porque a lição 5 tem **75 blocos**, e um XML de 75 blocos aninhados por
`<next>` é ilegível e impossível de manter à mão. A lição 1 tem 8 e seria
viável; as duas últimas não.

Os XML gerados ficam no repositório e são o que `blockly/gera.js` carrega.
Eles abrem no editor do Blockly e são exatamente o que sairia de alguém
montando as lições arrastando blocos — ver `blockly/README.md`.

## A descrição das lições vive aqui, e é curta de propósito

Cada lição é uma lista de tuplas. É a mesma progressão de
`pascal/licoes.pas`, `logo/licoes.lg` e `scratch/gera.py`, com os mesmos
números.
"""

import os
import sys
from xml.sax.saxutils import escape

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
DESTINO = os.path.join(AQUI, "licoes")

NS = "https://developers.google.com/blockly/xml"

# comando do traço -> (tipo de bloco, nome do campo)
BLOCO = {
    "F": ("tartaruga_frente", "N"),
    "B": ("tartaruga_tras", "N"),
    "R": ("tartaruga_direita", "G"),
    "L": ("tartaruga_esquerda", "G"),
}


class No:
    """Um bloco na pilha, com corpo opcional (para o `repita`)."""

    def __init__(self, tipo, campos=None, corpo=None):
        self.tipo = tipo
        self.campos = campos or {}
        self.corpo = corpo or []


def cmd(texto):
    """'F 100' -> No; 'PU' -> No do bloco de caneta."""
    partes = texto.split()
    if partes[0] in ("PU", "PD"):
        return No("tartaruga_caneta", {"ESTADO": partes[0]})
    tipo, campo = BLOCO[partes[0]]
    return No(tipo, {campo: partes[1]})


def repita(vezes, corpo):
    return No("tartaruga_repita", {"VEZES": str(vezes)}, corpo)


def do_traco(nome):
    """Lê um traço gravado e devolve a pilha PLANA equivalente.

    Usado nas lições 4 e 5, e a razão está no README deste diretório: o
    conjunto de blocos deste currículo não tem variável nem procedimento com
    parâmetro, então espiral e árvore entram expandidas.

    Isso é escolha, não limitação do Blockly -- e é o achado: mesmo
    CONSTRUINDO a linguagem de blocos, recursão que ramifica não fica natural
    sem reintroduzir o que o texto já tem.
    """
    with open(os.path.join(RAIZ, "dados", "esperado", nome),
              encoding="utf-8") as fh:
        return [cmd(l) for l in fh.read().split("\n") if l.strip()]


def licoes():
    quadrado = [cmd("F 100"), cmd("R 90")]

    l1 = []
    for _ in range(4):
        l1 += [cmd("F 100"), cmd("R 90")]

    l2 = [repita(4, quadrado)]

    l3 = []
    for lados, angulo in ((3, 120), (4, 90), (6, 60)):
        l3.append(repita(lados, [cmd("F 80"), cmd(f"R {angulo}")]))
        if lados != 6:
            l3 += [cmd("PU"), cmd("F 120"), cmd("PD")]

    return {
        1: l1,
        2: l2,
        3: l3,
        4: do_traco("licao4.traco"),
        5: do_traco("licao5.traco"),
    }


def serializa(pilha, nivel=1):
    """Uma pilha de blocos como XML aninhado por `<next>`.

    O aninhamento é o que o formato do Blockly exige: a pilha não é uma lista
    de irmãos, é uma cadeia em que cada bloco contém o seguinte. Com 75
    blocos isso dá 75 níveis de profundidade, o que é feio e é o formato.
    """
    if not pilha:
        return ""

    ind = "  " * nivel
    no = pilha[0]
    partes = [f'{ind}<block type="{escape(no.tipo)}">']

    for campo, valor in no.campos.items():
        partes.append(
            f'{ind}  <field name="{escape(campo)}">{escape(valor)}</field>')

    if no.corpo:
        partes.append(f'{ind}  <statement name="CORPO">')
        partes.append(serializa(no.corpo, nivel + 2))
        partes.append(f'{ind}  </statement>')

    resto = pilha[1:]
    if resto:
        partes.append(f'{ind}  <next>')
        partes.append(serializa(resto, nivel + 2))
        partes.append(f'{ind}  </next>')

    partes.append(f'{ind}</block>')
    return "\n".join(p for p in partes if p)


def conta(pilha):
    return sum(1 + conta(n.corpo) for n in pilha)


def main():
    os.makedirs(DESTINO, exist_ok=True)

    for n, pilha in sorted(licoes().items()):
        xml = (f'<xml xmlns="{NS}">\n'
               f'{serializa(pilha)}\n'
               f'</xml>\n')
        caminho = os.path.join(DESTINO, f"licao{n}.xml")
        with open(caminho, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(xml)
        print(f"gerado: blockly/licoes/licao{n}.xml  ({conta(pilha)} blocos)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
