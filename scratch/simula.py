#!/usr/bin/env python3
"""simula.py — interpreta um .sb3 e emite o traço da tartaruga.

    python3 scratch/simula.py scratch/licao2.sb3

## Por que um simulador, e qual é o seu escopo

Scratch não tem linha de comando. Sem isto, "o currículo tem uma versão em
Scratch" seria uma afirmação sem prova — a situação em que quase todo material
didático em Scratch se encontra.

Este simulador percorre os blocos do `.sb3` pela mesma semântica do Scratch
VM e emite os comandos do traço, que então é comparado byte a byte com o do
Pascal. É o que torna o Scratch verificável.

## A regra que mantém o simulador honesto

Ele implementa os opcodes que as lições usam e **falha alto em qualquer
outro**.

Isso não é rigor decorativo. Um simulador que ignora o que não conhece
aprovaria um projeto que o Scratch de verdade recusa — e o traço bateria,
dando a impressão de verificação onde não há nenhuma. Já aconteceu neste
portfólio o equivalente: no `p10-query-lab`, uma consulta Cypher COMPILOU e
devolveu zero linhas, e uma sonda que só perguntasse "compila?" teria
aprovado.

Então: opcode desconhecido é erro, com nome e id do bloco.

## O que ele NÃO é

Não é uma reimplementação do Scratch. Não há palco, nem clones, nem eventos,
nem paralelismo, nem a semântica de "um quadro por iteração de laço" — que é
real e importa para animação, e não afeta o traço.

A honestidade aqui é a mesma do `TRACO.md`: o que se compara é a interseção
do que as quatro linguagens expressam.
"""

import json
import os
import sys
import zipfile

# Os opcodes que as licoes usam. Qualquer outro e erro.
#
# O mapa e explicito, e nao um `if opcode.startswith("motion_")`, porque a
# familia nao determina a semantica: `motion_movesteps` move e
# `motion_gotoxy` teleporta, e tratar os dois pelo prefixo produziria traco
# errado em silencio.
CONHECIDOS = {
    "motion_movesteps",
    "motion_turnright",
    "motion_turnleft",
    "pen_penUp",
    "pen_penDown",
    "control_repeat",
    "data_setvariableto",
    "data_changevariableby",
    "data_variable",
}


def carrega(caminho):
    with zipfile.ZipFile(caminho) as z:
        return json.loads(z.read("project.json"))


def ator_de(projeto):
    for t in projeto["targets"]:
        if not t.get("isStage"):
            return t
    raise SystemExit("o projeto não tem ator (todos os targets são palco)")


class Simulador:
    def __init__(self, blocos):
        self.blocos = blocos
        self.vars = {}
        self.traco = []

    # -- avaliação de inputs ------------------------------------------------

    def valor(self, entrada, bid, nome):
        """Resolve um input para um número.

        A representação do Scratch 3 é uma lista cujo primeiro elemento diz
        o que vem depois:

            [1, [4, "100"]]            valor embutido, número
            [1, [6, "4"]]              valor embutido, inteiro positivo
            [1, [10, "100"]]           valor embutido, texto
            [2, "b7"]                  aponta para outro BLOCO (substack)
            [3, "r-passo", [4, "0"]]   bloco reporter, com valor de reserva

        O caso [3] é o que torna a lição 4 possível: o input é um bloco que
        REPORTA um valor (aqui, uma variável), e o `[4, "0"]` é o que o
        editor mostra se o reporter for arrancado.
        """
        if not isinstance(entrada, list) or not entrada:
            raise SystemExit(f"input {nome} de {bid} tem forma inesperada: "
                             f"{entrada!r}")

        tipo = entrada[0]

        if tipo == 1:
            interno = entrada[1]
            if isinstance(interno, list) and len(interno) >= 2:
                return float(interno[1])
            raise SystemExit(f"input {nome} de {bid}: {entrada!r}")

        if tipo == 3:
            # Avalia o bloco reporter.
            return self.reporter(entrada[1])

        raise SystemExit(f"input {nome} de {bid} tem tipo {tipo}, "
                         f"que este simulador não interpreta como valor")

    def reporter(self, bid):
        b = self.blocos.get(bid)
        if b is None:
            raise SystemExit(f"reporter {bid} não existe no projeto")

        op = b["opcode"]
        if op not in CONHECIDOS:
            raise SystemExit(f"opcode desconhecido em {bid}: {op}")

        if op == "data_variable":
            nome = b["fields"]["VARIABLE"][0]
            if nome not in self.vars:
                raise SystemExit(f"variável {nome!r} lida antes de ser "
                                 f"definida (bloco {bid})")
            return self.vars[nome]

        raise SystemExit(f"{op} usado como reporter em {bid}, e não é um")

    # -- execução -----------------------------------------------------------

    def emite(self, cmd, arg=None):
        if arg is None:
            self.traco.append(cmd)
            return
        # Inteiro no traco, sempre. O Scratch guarda numeros como texto e
        # calcula em ponto flutuante, e `100.0` quebraria a comparacao byte a
        # byte com o Pascal. Um valor nao inteiro aqui e ERRO, nao
        # arredondamento: ele significaria que a licao saiu do formato
        # combinado, e arredondar esconderia isso.
        if abs(arg - round(arg)) > 1e-9:
            raise SystemExit(f"{cmd} com argumento não inteiro: {arg!r} -- "
                             f"o traço só admite inteiros, ver TRACO.md")
        self.traco.append(f"{cmd} {int(round(arg))}")

    def pilha(self, bid):
        """Executa uma pilha de blocos seguindo `next`."""
        while bid is not None:
            b = self.blocos.get(bid)
            if b is None:
                raise SystemExit(f"bloco {bid} referenciado e inexistente")

            op = b["opcode"]
            if op not in CONHECIDOS:
                raise SystemExit(
                    f"opcode desconhecido em {bid}: {op}\n"
                    f"este simulador implementa só o que as lições usam, e "
                    f"falha de propósito em vez de ignorar -- ver a docstring")

            self.executa(bid, b, op)
            bid = b.get("next")

    def executa(self, bid, b, op):
        if op == "motion_movesteps":
            passos = self.valor(b["inputs"]["STEPS"], bid, "STEPS")
            # Passos NEGATIVOS sao "para tras" no traco. O Scratch nao tem
            # bloco "ande para tras": o idioma e `mova -100 passos`, e a
            # traducao para `B 100` e o que alinha com o Pascal e o Logo.
            if passos < 0:
                self.emite("B", -passos)
            else:
                self.emite("F", passos)

        elif op == "motion_turnright":
            self.emite("R", self.valor(b["inputs"]["DEGREES"], bid, "DEGREES"))

        elif op == "motion_turnleft":
            self.emite("L", self.valor(b["inputs"]["DEGREES"], bid, "DEGREES"))

        elif op == "pen_penUp":
            self.emite("PU")

        elif op == "pen_penDown":
            self.emite("PD")

        elif op == "control_repeat":
            vezes = self.valor(b["inputs"]["TIMES"], bid, "TIMES")
            if abs(vezes - round(vezes)) > 1e-9 or vezes < 0:
                raise SystemExit(f"control_repeat em {bid} com TIMES={vezes!r}")
            sub = b["inputs"].get("SUBSTACK")
            if sub is None:
                # Laco sem corpo e valido em Scratch e nao emite nada. Tratar
                # como erro recusaria um projeto legitimo.
                return
            for _ in range(int(round(vezes))):
                self.pilha(sub[1])

        elif op == "data_setvariableto":
            nome = b["fields"]["VARIABLE"][0]
            self.vars[nome] = self.valor(b["inputs"]["VALUE"], bid, "VALUE")

        elif op == "data_changevariableby":
            nome = b["fields"]["VARIABLE"][0]
            if nome not in self.vars:
                raise SystemExit(f"variável {nome!r} alterada antes de ser "
                                 f"definida (bloco {bid})")
            self.vars[nome] += self.valor(b["inputs"]["VALUE"], bid, "VALUE")

        else:
            raise SystemExit(f"{op} está em CONHECIDOS mas não tem execução")


def main():
    if len(sys.argv) != 2:
        print("uso: simula.py <arquivo.sb3>", file=sys.stderr)
        return 64

    caminho = sys.argv[1]
    if not os.path.exists(caminho):
        print(f"não achei {caminho} -- rode scratch/gera.py primeiro",
              file=sys.stderr)
        return 66

    ator = ator_de(carrega(caminho))
    blocos = ator["blocks"]

    topos = [bid for bid, b in blocos.items() if b.get("topLevel")]
    if len(topos) != 1:
        print(f"{len(topos)} blocos topLevel, esperado 1", file=sys.stderr)
        return 1

    sim = Simulador(blocos)
    sim.pilha(topos[0])

    for linha in sim.traco:
        print(linha)
    return 0


if __name__ == "__main__":
    sys.exit(main())
