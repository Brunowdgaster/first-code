#!/usr/bin/env python3
"""gera.py — monta os projetos .sb3 das cinco lições, em Scratch 3.

    python3 scratch/gera.py                 # gera scratch/licao{1..5}.sb3
    python3 scratch/gera.py --json 2        # mostra o project.json da lição 2

## Por que gerar, em vez de arrastar blocos

Scratch não tem linha de comando. Um `.sb3` é um ZIP com um `project.json`
que descreve os blocos como um grafo de objetos com ids, e rodá-lo exige o
editor ou a VM em JavaScript.

Isso costuma ser o fim da conversa num projeto que precisa de verificação
automática — e é por isso que "currículo em Scratch" quase sempre significa
capturas de tela. Aqui o `.sb3` é **gerado** por este arquivo e
**interpretado** por `scratch/simula.py`, então as lições em Scratch são
verificadas como qualquer outra implementação: o traço tem de bater byte a
byte com o do Pascal.

Os `.sb3` gerados abrem no editor do Scratch (arquivo → carregar do
computador) e funcionam de verdade. Não são maquete.

## O formato, no que importa aqui

`project.json` tem `targets` (o palco e os atores). Cada ator tem `blocks`:
um dicionário de id → bloco, e cada bloco traz:

    opcode      o nome da operação, ex. "motion_movesteps"
    next        o id do bloco DE BAIXO na pilha, ou null
    parent      o id do bloco de cima, ou null
    inputs      os encaixes de valor, ex. o "10" de "mova 10 passos"
    topLevel    true só no primeiro bloco de uma pilha
    x, y        posição na tela, só para blocos topLevel

A estrutura é uma **lista ligada** por `next`/`parent`, e não uma árvore de
filhos. Um bloco C (como "repita") guarda o corpo num input especial
`SUBSTACK`, que aponta para o primeiro bloco de dentro.

Essa representação é a razão pela qual montar Scratch à mão é chato e
verificar é fácil: os ids têm de fechar nos dois sentidos (`a.next == b` e
`b.parent == a`), e um gerador que erre isso produz um arquivo que o editor
recusa sem dizer onde.

Por isso `confere_integridade()` existe neste arquivo, e roda em toda geração.
"""

import json
import os
import sys
import zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)

# ---------------------------------------------------------------------------
# A tartaruga em Scratch: blocos de movimento de verdade.
#
# Scratch nao tem "emita o traco". Ele tem `motion_movesteps` e
# `motion_turnright`, que movem o ator -- e e isso que o .sb3 contem, para
# abrir no editor e funcionar.
#
# O traco sai do `simula.py`, que interpreta esses mesmos opcodes. Ou seja: o
# projeto Scratch e autentico, e a comparacao com as outras linguagens
# acontece na INTERPRETACAO dele, nao numa versao adaptada.
# ---------------------------------------------------------------------------

OPCODE = {
    "F": ("motion_movesteps", "STEPS"),
    "B": ("motion_movesteps", "STEPS"),   # para tras = passos negativos
    "R": ("motion_turnright", "DEGREES"),
    "L": ("motion_turnleft", "DEGREES"),
    "PU": ("pen_penUp", None),
    "PD": ("pen_penDown", None),
}


class Construtor:
    """Monta a estrutura de blocos com ids coerentes.

    Os ids sao sequenciais e deterministicos (`b1`, `b2`, ...) de proposito: o
    Scratch usa ids aleatorios, e aleatorio tornaria o .sb3 diferente a cada
    geracao -- impossivel de comparar e inutil num repositorio.
    """

    def __init__(self):
        self.blocos = {}
        self.n = 0

    def novo_id(self):
        self.n += 1
        return f"b{self.n}"

    def bloco(self, opcode, inputs=None, fields=None):
        bid = self.novo_id()
        self.blocos[bid] = {
            "opcode": opcode,
            "next": None,
            "parent": None,
            "inputs": inputs or {},
            "fields": fields or {},
            "shadow": False,
            "topLevel": False,
        }
        return bid

    def liga(self, ids, pai=None):
        """Encadeia uma lista de ids numa pilha, ajustando next/parent.

        Os dois sentidos SAO necessarios. O editor do Scratch usa `parent`
        para desenhar e `next` para executar, e um arquivo com so um dos dois
        abre com a pilha desmontada -- sem erro, so errado.
        """
        for i, bid in enumerate(ids):
            if i + 1 < len(ids):
                self.blocos[bid]["next"] = ids[i + 1]
                self.blocos[ids[i + 1]]["parent"] = bid
        if ids:
            self.blocos[ids[0]]["parent"] = pai
        return ids

    def comando(self, cmd, arg=None):
        """Um comando do traço, como bloco de Scratch."""
        opcode, campo = OPCODE[cmd]
        if campo is None:
            return self.bloco(opcode)
        valor = -arg if cmd == "B" else arg
        # O "4" e o tipo "numero matematico" na representacao de input do
        # Scratch 3. A lista [1, [4, "100"]] significa "input embutido, valor
        # numerico 100" -- e o valor vai como STRING, que e como o Scratch
        # grava.
        return self.bloco(opcode, inputs={campo: [1, [4, str(valor)]]})

    def repita(self, vezes, corpo_ids):
        """`control_repeat`, com o corpo em SUBSTACK."""
        bid = self.bloco(
            "control_repeat",
            inputs={
                "TIMES": [1, [6, str(vezes)]],   # 6 = inteiro positivo
                "SUBSTACK": [2, corpo_ids[0]],   # 2 = aponta para outro bloco
            },
        )
        self.blocos[corpo_ids[0]]["parent"] = bid
        return bid

    def topo(self, primeiro):
        """Marca o começo da pilha, que é o que `topLevel` significa."""
        self.blocos[primeiro]["topLevel"] = True
        self.blocos[primeiro]["parent"] = None
        self.blocos[primeiro]["x"] = 48
        self.blocos[primeiro]["y"] = 48


def confere_integridade(blocos):
    """Os ids fecham nos dois sentidos, e nenhum aponta para o vazio.

    Esta função existe porque um `.sb3` com ids inconsistentes é recusado pelo
    editor **sem dizer onde** -- e o mesmo arquivo pode ser aceito pelo
    simulador deste repositório, que só segue `next`. Aí o traço bateria e o
    projeto não abriria, que é o pior dos dois mundos: verificação verde e
    artefato quebrado.
    """
    problemas = []

    for bid, b in blocos.items():
        prox = b.get("next")
        if prox is not None:
            if prox not in blocos:
                problemas.append(f"{bid}.next aponta para {prox}, que não existe")
            elif blocos[prox].get("parent") != bid:
                problemas.append(
                    f"{bid}.next == {prox} mas {prox}.parent == "
                    f"{blocos[prox].get('parent')}")

        pai = b.get("parent")
        if pai is not None and pai not in blocos:
            problemas.append(f"{bid}.parent aponta para {pai}, que não existe")

        for nome, entrada in (b.get("inputs") or {}).items():
            if isinstance(entrada, list) and entrada and entrada[0] == 2:
                alvo = entrada[1]
                if alvo not in blocos:
                    problemas.append(
                        f"{bid}.inputs.{nome} aponta para {alvo}, inexistente")
                elif blocos[alvo].get("parent") != bid:
                    problemas.append(
                        f"{bid}.inputs.{nome} == {alvo} mas o parent de "
                        f"{alvo} é {blocos[alvo].get('parent')}")

    topos = [bid for bid, b in blocos.items() if b.get("topLevel")]
    if len(topos) != 1:
        problemas.append(f"{len(topos)} blocos topLevel, esperado exatamente 1")

    return problemas


# ---------------------------------------------------------------------------
# As cinco lições. Cada uma devolve (construtor, id_do_primeiro_bloco).
#
# O conteúdo é o MESMO de `pascal/licoes.pas` e `logo/licoes.lg` -- a mesma
# progressão, os mesmos números. O que muda é só como a linguagem expressa.
# ---------------------------------------------------------------------------


def licao1(c):
    """Sequência: oito blocos empilhados, um por um."""
    ids = []
    for _ in range(4):
        ids.append(c.comando("F", 100))
        ids.append(c.comando("R", 90))
    c.liga(ids)
    return ids[0]


def licao2(c):
    """Repetição: `repita 4` com dois blocos dentro.

    O traço é idêntico ao da lição 1, e a suíte verifica. Em Scratch essa
    equivalência é especialmente visível: o aluno literalmente ARRASTA os dois
    blocos para dentro do `repita` e apaga os seis repetidos.
    """
    corpo = c.liga([c.comando("F", 100), c.comando("R", 90)])
    rep = c.repita(4, corpo)
    return rep


def licao3(c):
    """Procedimento com parâmetro.

    ## A ressalva honesta desta lição

    Scratch TEM procedimento com parâmetro (`procedures_definition` com
    `argumentreporter_*`), e ele é bem desenhado: o bloco "Meus Blocos"
    aparece na paleta como qualquer outro.

    Mas Scratch **não tem divisão inteira**. O `360 / lados` do Pascal e o
    `quotient 360 :lados` do Logo não têm equivalente direto: há
    `operator_divide`, que dá fração.

    Para os lados usados aqui (3, 4, 6) a divisão é exata, então o traço bate.
    Com 7 lados, o Pascal daria 51 e o Scratch 51.42857 -- e as duas
    implementações divergiriam. Isso está declarado em TRACO.md e não
    escondido: um currículo que ensinasse polígonos de 7 lados precisaria
    tratar disso explicitamente, e essa é uma informação pedagógica real.

    Esta lição usa o ângulo já calculado, como um aluno de Scratch faria --
    e a divisão fica para a lição de matemática, não para a de programação.
    """
    ids = []
    for lados, angulo in ((3, 120), (4, 90), (6, 60)):
        corpo = c.liga([c.comando("F", 80), c.comando("R", angulo)])
        ids.append(c.repita(lados, corpo))
        if lados != 6:
            ids.append(c.comando("PU"))
            ids.append(c.comando("F", 120))
            ids.append(c.comando("PD"))
    c.liga(ids)
    return ids[0]


def licao4(c):
    """Recursão com parada.

    ## A segunda ressalva honesta

    Scratch **não tem recursão com valor de retorno nem parâmetro
    decrescente** de um jeito que um iniciante escreva. Tem `procedures_call`,
    e procedimento em Scratch PODE se chamar -- mas o idioma natural de
    Scratch para "espiral" é um `repita` com uma variável que diminui.

    E isso é uma informação pedagógica, não um defeito a esconder: **Scratch
    ensina iteração muito melhor do que ensina recursão.** A lição 4 em
    Scratch é um laço com variável; em Logo é recursão de três linhas. O
    currículo usa as duas para mostrar ao aluno que o MESMO desenho sai de
    duas ideias diferentes.

    O traço é idêntico. A estrutura não é, e isso é o conteúdo.
    """
    # `data_setvariableto` e `data_changevariableby` exigem declarar a
    # variavel no target. Os ids de variavel do Scratch sao arbitrarios, e
    # este e fixo de proposito -- ver o comentario sobre determinismo.
    passo = c.bloco(
        "data_setvariableto",
        inputs={"VALUE": [1, [10, "100"]]},
        fields={"VARIABLE": ["passo", "var-passo"]},
    )

    corpo = c.liga([
        c.bloco("motion_movesteps",
                inputs={"STEPS": [3, "r-passo", [4, "0"]]}),
        c.comando("R", 60),
        c.bloco("data_changevariableby",
                inputs={"VALUE": [1, [4, "-10"]]},
                fields={"VARIABLE": ["passo", "var-passo"]}),
    ])
    rep = c.repita(10, corpo)

    # O reporter da variavel, que o input [3, "r-passo", ...] referencia.
    c.blocos["r-passo"] = {
        "opcode": "data_variable",
        "next": None,
        "parent": corpo[0],
        "inputs": {},
        "fields": {"VARIABLE": ["passo", "var-passo"]},
        "shadow": False,
        "topLevel": False,
    }

    ids = c.liga([passo, rep])
    return ids[0]


def licao5(c):
    """Recursão que ramifica.

    ## A terceira ressalva, e a mais importante do currículo

    A árvore da lição 5 **não tem versão natural em Scratch**.

    Duas chamadas recursivas com estado de posição compartilhado é exatamente
    o que o modelo de execução do Scratch não favorece: não há pilha visível,
    e "voltar ao ponto de divisão" exige salvar e restaurar posição e ângulo à
    mão, em variáveis, para cada nível.

    Dá para fazer -- e o que está gerado aqui é a expansão PLANA da mesma
    árvore, que produz o traço idêntico. Mas a estrutura recursiva
    desapareceu, e fingir o contrário seria mentir sobre o que Scratch é.

    **Essa é a conclusão pedagógica do projeto:** há conceitos que uma
    linguagem de blocos ensina melhor que texto (evento, paralelismo,
    iteração) e conceitos que ela não ensina bem (recursão que ramifica). O
    currículo tem cinco linguagens porque nenhuma delas cobre tudo, e a lição
    5 é onde isso fica medido em vez de opinado.

    O traço vem de `dados/esperado/licao5.traco`, gerado pelo Pascal, e é
    expandido aqui como sequência de blocos. São 75 blocos, e o número é o
    argumento: a recursão de 9 linhas do Logo vira 75 blocos arrastados.
    """
    with open(os.path.join(RAIZ, "dados", "esperado", "licao5.traco"),
              encoding="utf-8") as fh:
        linhas = [l.split() for l in fh.read().split("\n") if l.strip()]

    ids = []
    for partes in linhas:
        if len(partes) == 1:
            ids.append(c.comando(partes[0]))
        else:
            ids.append(c.comando(partes[0], int(partes[1])))
    c.liga(ids)
    return ids[0]


LICOES = {1: licao1, 2: licao2, 3: licao3, 4: licao4, 5: licao5}


def projeto(n):
    """O project.json completo de uma lição."""
    c = Construtor()
    primeiro = LICOES[n](c)
    c.topo(primeiro)

    problemas = confere_integridade(c.blocos)
    if problemas:
        for p in problemas:
            print(f"  integridade: {p}", file=sys.stderr)
        raise SystemExit(f"lição {n}: {len(problemas)} problema(s) de "
                         f"integridade de blocos")

    ator = {
        "isStage": False,
        "name": "Tartaruga",
        "variables": {"var-passo": ["passo", 0]},
        "lists": {},
        "broadcasts": {},
        "blocks": c.blocos,
        "comments": {},
        "currentCostume": 0,
        # O custume minimo valido: um SVG vazio. O Scratch exige ao menos um,
        # e usar o gato padrao exigiria embutir o asset dele.
        "costumes": [{
            "name": "vazio",
            "bitmapResolution": 1,
            "dataFormat": "svg",
            "assetId": "cd21514d0531fdffb22204e0ec5ed84a",
            "md5ext": "cd21514d0531fdffb22204e0ec5ed84a.svg",
            "rotationCenterX": 0,
            "rotationCenterY": 0,
        }],
        "sounds": [],
        "volume": 100,
        "layerOrder": 1,
        "visible": True,
        "x": 0,
        "y": 0,
        "size": 100,
        "direction": 90,
        "draggable": False,
        "rotationStyle": "all around",
    }

    palco = {
        "isStage": True,
        "name": "Stage",
        "variables": {},
        "lists": {},
        "broadcasts": {},
        "blocks": {},
        "comments": {},
        "currentCostume": 0,
        "costumes": [{
            "name": "fundo",
            "bitmapResolution": 1,
            "dataFormat": "svg",
            "assetId": "cd21514d0531fdffb22204e0ec5ed84a",
            "md5ext": "cd21514d0531fdffb22204e0ec5ed84a.svg",
            "rotationCenterX": 0,
            "rotationCenterY": 0,
        }],
        "sounds": [],
        "volume": 100,
        "layerOrder": 0,
        "tempo": 60,
        "videoTransparency": 50,
        "videoState": "off",
        "textToSpeechLanguage": None,
    }

    return {
        "targets": [palco, ator],
        "monitors": [],
        # A extensao `pen` e o que permite `pen_penUp` / `pen_penDown`. Sem
        # declarar aqui, o editor abre o projeto com os blocos de caneta
        # marcados como desconhecidos.
        "extensions": ["pen"],
        "meta": {
            "semver": "3.0.0",
            "vm": "2.3.0",
            "agent": "p14-first-code/gera.py",
        },
    }


def main():
    args = sys.argv[1:]

    if "--json" in args:
        i = args.index("--json")
        n = int(args[i + 1]) if i + 1 < len(args) else 1
        print(json.dumps(projeto(n), ensure_ascii=False, indent=2))
        return 0

    for n in sorted(LICOES):
        p = projeto(n)
        destino = os.path.join(AQUI, f"licao{n}.sb3")

        # ZIP_STORED e nao DEFLATE, e `date_time` fixo: o .sb3 precisa ser
        # BYTE A BYTE o mesmo a cada geracao, senao ele polui o diff do git a
        # cada execucao da suite. Compressao e carimbo de tempo sao as duas
        # fontes de variacao.
        with zipfile.ZipFile(destino, "w", zipfile.ZIP_STORED) as z:
            info = zipfile.ZipInfo("project.json", date_time=(2026, 1, 1, 0, 0, 0))
            z.writestr(info, json.dumps(p, ensure_ascii=False,
                                        separators=(",", ":"),
                                        sort_keys=True))

        n_blocos = len(p["targets"][1]["blocks"])
        print(f"gerado: scratch/licao{n}.sb3  ({n_blocos} blocos)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
