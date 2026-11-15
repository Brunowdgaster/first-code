# O traço de tartaruga: como quatro linguagens provam que ensinam o mesmo

Este projeto é um **currículo de programação visual** — cinco lições com uma
progressão de conceitos — implementado em Pascal, Logo, Scratch e Blockly.

O problema de um projeto assim é que ele é fácil de fingir. Qualquer um escreve
cinco arquivos em cinco linguagens e afirma que "ensinam a mesma coisa". Para
isso ser verificável, as implementações precisam produzir algo comparável.

Produzem: **o traço da tartaruga**.

## O formato

Uma linha por comando, em maiúsculas, com o argumento inteiro separado por um
espaço:

```
F 100
R 90
F 100
```

| comando | significado |
|---|---|
| `F n` | andar `n` passos para a frente |
| `B n` | andar `n` passos para trás |
| `R g` | girar `g` graus à direita |
| `L g` | girar `g` graus à esquerda |
| `PU` | levantar a caneta (move sem desenhar) |
| `PD` | abaixar a caneta |

Decisões do formato, e o motivo de cada uma:

* **inteiros, nunca fração.** Ponto flutuante formatado por quatro linguagens
  diferentes é quatro arredondamentos diferentes, e a comparação byte a byte
  acusaria divergência onde há só formatação. As lições foram desenhadas com
  ângulos e distâncias inteiros;

* **sem comando de cor ou de posição absoluta.** Scratch e Blockly têm;
  Logo tem outros; Pascal não tem nenhum. O formato é a INTERSEÇÃO, porque
  comparar só é possível no que todas expressam;

* **uma linha por comando, sem agrupar.** `repeat 4 [F 100 R 90]` emite oito
  linhas, não uma. É isso que permite a lição 2 provar algo — ver abaixo.

## Por que a lição 1 e a lição 2 têm o MESMO traço

| lição | conceito | o que o aluno escreve |
|---|---|---|
| 1 | **sequência** | oito comandos, um por um |
| 2 | **repetição** | `repita 4 [ ... ]` |

As duas desenham o mesmo quadrado, e os traços são **byte a byte idênticos**.

Isso não é redundância do projeto: é o conteúdo da lição. A pergunta que todo
iniciante faz ao ver um laço pela primeira vez é *"isso faz a mesma coisa?"* —
e aqui a resposta é um `diff` que sai vazio, não a palavra de um professor.

E vale como teste: se alguém "melhorar" a lição 2 e mudar o resultado, a suíte
falha apontando que a equivalência quebrou.

## As cinco lições

| nº | conceito | o que a lição introduz |
|---|---|---|
| 1 | sequência | comandos em ordem; a tartaruga tem estado |
| 2 | repetição | o laço como abreviação de uma sequência |
| 3 | procedimento com parâmetro | dar nome a uma ideia, e variá-la |
| 4 | recursão com parada | um procedimento que se chama, e por que para |
| 5 | recursão que ramifica | duas chamadas recursivas: a árvore |

A progressão não é arbitrária. Cada lição só usa o que a anterior introduziu,
e a 5 é onde o Logo foi historicamente inventado para brilhar: uma árvore em
nove linhas, que em linguagem imperativa exige pensar na pilha.

## A verificação

```
dados/esperado/licao1.traco     <- gravado pela implementação de referência
dados/esperado/licao2.traco
...
```

Cada implementação roda cada lição e o traço é comparado **byte a byte** contra
o esperado. O `verifica.sh` faz isso para as quatro linguagens.

A referência é o **Pascal**, pela mesma razão que o Python é a referência no
`p10-query-lab` e o C no `p01-metal-vm`: é a implementação mais direta, sem
ambiente, sem motor de blocos, sem interpretador — se estiver errada, está
errada de um jeito que se lê.

## O que cada linguagem precisou para ser verificável

| linguagem | como o traço sai |
|---|---|
| **Pascal** | `writeln` em stdout, e ponto |
| **Logo** | `openwrite`/`setwrite` para um ARQUIVO — ver abaixo |
| **Scratch** | o `.sb3` é **interpretado** por um simulador deste repositório |
| **Blockly** | o gerador de código emite o traço direto |

### Logo: a ferramenta não tem console, mas a linguagem tem arquivo

O `ucblogo` do Ubuntu é compilado contra wxWidgets/GTK3/X11: é build **só
gráfico**. Sem display ele não escreve nada em stdout — **nem `--help`** — e
sai com código 0. Medido:

```
$ ucblogo programa.lg < /dev/null
$ echo $?
0
$ wc -c < saida   # 0 bytes em stdout E em stderr
0
```

A saída não existe porque ela vai para a janela de texto do wx, que não há.

A solução não está na linha de comando: está **na linguagem**. Logo tem
`openwrite` e `setwrite`, que redirecionam a saída do programa para um
arquivo — e isso funciona independentemente de onde a janela estaria:

```logo
openwrite "traco.txt
setwrite "traco.txt
print [F 100]
setwrite []
close "traco.txt
```

Rodando sob `xvfb-run` (display virtual, pacote `xvfb` do apt), o UCBLogo real
executa o programa real e o traço aparece no arquivo.

É um resultado que vale registrar: **a capacidade estava na linguagem, não na
ferramenta.** Procurar uma opção de linha de comando que não existe custou
mais que ler o que o Logo sabe fazer desde 1967.

### Scratch: o `.sb3` é gerado E interpretado aqui

Scratch não tem linha de comando. Um projeto `.sb3` é um ZIP com um
`project.json` que descreve os blocos, e rodá-lo exige o editor ou a VM em
JavaScript.

Este repositório faz as duas pontas:

* **`scratch/gera.py`** monta o `project.json` com os opcodes reais do
  Scratch 3 (`control_repeat`, `motion_movesteps`, `procedures_definition`...)
  e empacota o `.sb3`;

* **`scratch/simula.py`** abre o `.sb3`, percorre os blocos pela mesma
  semântica do Scratch VM e emite o traço.

O simulador é o que torna o Scratch verificável sem GUI, e ele é honesto sobre
o escopo: implementa os opcodes que as lições usam, e **falha alto** em
qualquer outro, em vez de ignorar. Um simulador que ignora o que não conhece
aprovaria um projeto que o Scratch de verdade recusa.
