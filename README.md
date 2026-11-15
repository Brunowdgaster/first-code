# first-code — a mesma lição, quatro linguagens, um traço

Um currículo de programação visual: **cinco lições** com uma progressão de
conceitos, implementadas em **Pascal, Logo, Scratch e Blockly** — que têm de
produzir **o mesmo traço de tartaruga**, byte a byte, verificado por script.

> **Status:** **as 5 linguagens previstas**, com **39 testes**. Pascal, Logo,
> Scratch, Blockly e Smalltalk estão completos e produzem traço idêntico.

## Por que isto não é enchimento de portfólio

Um projeto de "linguagens educacionais" é fácil de fingir: cinco arquivos em
cinco linguagens e a afirmação de que ensinam a mesma coisa. Normalmente a
prova são capturas de tela.

Aqui a prova é um `diff`. As quatro implementações emitem um **traço de
tartaruga** — `F 100`, `R 90`, `PU` — e a suíte compara os quatro contra a
mesma referência. Se uma lição divergir, o teste aponta a linha.

O formato e as decisões dele estão em **[TRACO.md](TRACO.md)**.

## As cinco lições

| nº | conceito | o que introduz |
|---|---|---|
| 1 | sequência | comandos em ordem; a tartaruga tem estado |
| 2 | repetição | o laço como **abreviação** de uma sequência |
| 3 | procedimento com parâmetro | dar nome a uma ideia, e variá-la |
| 4 | recursão com parada | um procedimento que se chama, e por que para |
| 5 | recursão que ramifica | **duas** chamadas recursivas: a árvore |

### A lição 2 prova algo, e é o melhor momento do currículo

As lições 1 e 2 desenham o mesmo quadrado: a primeira com oito comandos
escritos um a um, a segunda com `repita 4`. Os traços são **byte a byte
idênticos**.

A pergunta que todo iniciante faz ao ver um laço — *"isso faz a mesma
coisa?"* — é respondida por um `diff` que sai vazio, não pela palavra do
professor. E em Blockly a economia é visível na contagem:

```
  ok    a lição 2 faz o mesmo com 3 blocos onde a 1 usa 8
```

## O que cada linguagem precisou para ser verificável

| linguagem | como o traço sai | custo |
|---|---|---|
| **Pascal** | `writeln` em stdout | nenhum: é a referência |
| **Smalltalk** | a classe escreve num `FileReference` | o Pharo não está no apt |
| **Logo** | `openwrite`/`setwrite` para arquivo, sob `xvfb` | o build do Ubuntu é só gráfico |
| **Scratch** | o `.sb3` é **gerado e interpretado** aqui | Scratch não tem linha de comando |
| **Blockly** | o gerador de código emite o traço | `node_modules` tem de sair de `/mnt/c` |

### Logo: a capacidade estava na linguagem, não na ferramenta

O `ucblogo` do Ubuntu é compilado contra wxWidgets/GTK3/X11 — build **só
gráfico**. Sem display ele não escreve nada em stdout, **nem `--help`**, e sai
com código 0:

```
$ ucblogo programa.lg < /dev/null ; echo $?
0
$ # zero bytes em stdout E em stderr
```

Não há opção de linha de comando para mudar isso. Mas Logo tem `openwrite` e
`setwrite` **desde 1967**: comandos da própria linguagem que redirecionam a
saída do programa para um arquivo, independentemente de onde a janela estaria.

Sob `xvfb-run`, o UCBLogo real executa o programa real e o traço aparece no
arquivo. Procurar a opção que não existe custou mais que ler o que a
linguagem sabe fazer.

### Scratch: gerado e interpretado neste repositório

Um `.sb3` é um ZIP com um `project.json` que descreve os blocos como um grafo
de ids. Rodá-lo exige o editor ou a VM em JavaScript — e é por isso que
material didático em Scratch quase nunca é verificado.

* **`scratch/gera.py`** monta o `project.json` com os opcodes reais do Scratch
  3 (`control_repeat`, `motion_movesteps`, `pen_penUp`) e empacota o `.sb3`.
  Os arquivos abrem no editor e funcionam;
* **`scratch/simula.py`** abre o `.sb3`, percorre os blocos pela semântica do
  Scratch VM, e emite o traço.

O simulador implementa os opcodes que as lições usam e **falha alto em
qualquer outro**. Um simulador que ignora o desconhecido aprovaria um projeto
que o Scratch de verdade recusa — e o traço bateria, dando impressão de
verificação onde não há nenhuma. A suíte testa isso com um `.sb3` que usa
`motion_gotoxy` de propósito.

E a geração é **determinística**: `ZIP_STORED` e carimbo de tempo fixo, porque
senão cada execução da suíte sujaria o diff do git.

### Blockly: construir o editor, não só usá-lo

Scratch é um produto; Blockly é a **biblioteca** com que o Scratch 3, o App
Inventor e o Code.org foram construídos. A diferença aparece em
`blockly/blocos.js`: eu defino os blocos e defino o que cada um gera.

E há **dois geradores** para a mesma árvore de blocos:

```
$ ./blockly/roda.sh 2
F 100
R 90
...

$ ./blockly/roda.sh 2 --forge
(repete 4 [Frente 100] ++ [Direita 90])
```

O segundo emite código na linguagem **`forge`**, a linguagem com inferência
Hindley-Milner do [p02-forge-lang](https://github.com/Brunowdgaster/forge-lang).
Um aluno arrasta blocos e o resultado é código funcional — `repita` vira
`repete` porque `forge` não tem laço imperativo, e a pilha de blocos vira
concatenação de listas.

Ver a mesma árvore produzir código imperativo e funcional é difícil de
ensinar com palavras.

### Smalltalk: o único em que o programa é um objeto vivo

As outras quatro têm a mesma forma — escreve-se um arquivo, roda-se, vê-se a
saída. Em Smalltalk a tartaruga é uma **classe**, e as lições são **métodos**
dela.

A diferença aparece na lição 5: a árvore recursiva precisa que a tartaruga
volte ao ponto de divisão. Em Pascal isso é um procedimento mexendo em estado
global; aqui é `self tras: tamanho`, e o estado pertence ao objeto. **Duas
tartarugas poderiam desenhar ao mesmo tempo**, o que nas outras
implementações exigiria reescrever tudo.

E `4 timesRepeat: [ ... ]` é uma **mensagem enviada ao número 4**, não sintaxe
de laço. `timesRepeat:` é um método de `Integer` escrito em Smalltalk, que o
aluno pode abrir e ler — em Pascal, `for` é palavra reservada e não tem
dentro.

#### Quatro paredes, e três delas estavam na documentação

**`gnu-smalltalk` não existe mais** no Ubuntu 26.04. E `squeak-vm` + `etoys`
instalam, a VM sobe (`-version` responde), mas a imagem do Etoys **ignora** o
`.st` passado. O motor usado é o **Pharo 11** — descendente vivo do
Smalltalk-80, livre (MIT), instalado por download.

**`eval` é só para uma linha.** A descrição do subcomando diz exatamente isso:
*"Directly evaluates passed in one line scripts"*. Um programa de várias
linhas dá erro de parse apontando para a última linha, o que parece defeito do
código. O subcomando certo é `st`.

**`methodsFor:` foi removido.** Era o mecanismo clássico do formato *chunk*, e
o Pharo 11 responde `doesNotUnderstand`. Perguntei à própria imagem em vez de
supor:

```
(Object respondsTo: #methodsFor:)          false
(Object respondsTo: #compile:classified:)  true
```

**E `st` não sai sozinho.** A ajuda do subcomando avisa: *"runs Pharo code
stored in a file **without quiting**"*. Sem `--quit`, o arquivo é avaliado,
nada falha, e o processo fica vivo com stdout vazio — indistinguível de
travamento. Foi o terceiro *timeout* desta integração, e o único cuja causa
estava escrita na ajuda da ferramenta.

#### E duas que foram culpa minha, do mesmo tipo

No formato *chunk*, o separador é cortado **antes** de o código ser analisado.
Então uma exclamação dentro de um **comentário** parte o comentário no meio — e
o erro sai como `Unknown character` apontando para uma linha de prosa.

Eu caí nisso **escrevendo um exemplo do formato dentro do comentário que
explica o formato**. E depois caí de novo com aspas: aspas duplas delimitam
comentário, então uma expressão entre aspas no meio da prosa fecha o
comentário.

Depois, tirei **todos** os separadores por segurança. Resultado: o arquivo
virou **um chunk**, e como um chunk é compilado inteiro antes de executar, a
classe `Tartaruga` ainda não existia quando o compilador leu a linha seguinte
— vinte avisos de `Tartaruga is Undeclared`, e então travamento.

> O separador não é decoração de formato antigo: ele significa *"compile e
> execute até aqui antes de ler o resto"*. Um arquivo que define uma classe e
> logo a usa **precisa** dele.

## Três armadilhas que custaram tempo, e o que cada uma ensinou

### 1. `pu` e `pd` são primitivas, e o Logo PERGUNTA em vez de abortar

Chamei dois procedimentos de `pu` e `pd` — que são abreviações de `penup` e
`pendown`. O UCBLogo recusa a redefinição com:

```
pu is already defined
?
```

O `?` é o prompt do REPL: ele **não aborta, ele pergunta**. Sob `xvfb-run`,
sem ninguém para digitar, o processo fica parado até o timeout — e o sintoma
visível é "traço vazio depois de 90 segundos", que não menciona nome de
procedimento em lugar nenhum. A mensagem ia para a janela de texto do wx.

É a mesma família da caixa de diálogo do AutoHotkey no
[p12-toolbelt](https://github.com/Brunowdgaster/toolbelt): **ferramenta que
pergunta em vez de falhar é veneno em automação.**

Medido, para não supor: `to f`, `to b`, `to r` e `to l` **não** colidem — as
primitivas são `fd`, `bk`, `rt` e `lt`. Só `pu` e `pd` colidem.

### 2. O nome da pasta tem espaço, e só o Logo se importa

Este portfólio vive em `.../para se gabar/...`. Em Logo, `"palavra` é um
literal que **termina no primeiro espaço**, então

```logo
load "/mnt/c/.../para se gabar/licoes.lg
```

é lido como `load "/mnt/c/.../para`, seguido das palavras soltas `se` e
`gabar/licoes.lg`. O arquivo nunca carrega.

E o detalhe que faz disso uma lição: **as aspas do shell não resolvem.** Elas
protegem o caminho até ele chegar ao script — e o caminho é escrito *dentro de
um programa Logo*, onde quem manda é a sintaxe do Logo. Toda outra linguagem
deste portfólio tolerou os espaços porque recebe o caminho como **argumento**;
esta recebe como **código**.

A correção é o escape da própria linguagem. Medido:

```
load "caminho com espaco     -> falhou (traço vazio)
load "|caminho com espaco|   -> funcionou
```

### 3. 98 segundos medidos para gerar 8 linhas, e a conclusão errada que isso gerou

O Blockly traz **2302 arquivos** em `node_modules`. Com o repositório em
`/mnt/c` — o sistema de arquivos do Windows visto pelo WSL2 — o custo medido
foi:

| onde | tempo | CPU |
|---|---|---|
| `node_modules` em `/mnt/c` | **1m38s** | user 2,8s, sys 6,2s |
| o mesmo, cache quente | 1m21s | |
| `node_modules` no ext4 | **1,7s** | |

Noventa segundos de **espera de I/O** para 2,8 segundos de CPU — 60x, e o
mesmo fenômeno que no `p03-otp-mesh` custou 5,5x numa build de .NET.

**E a armadilha vale mais que o número.** O primeiro teste do gerador passou,
e os seguintes "penduraram", sem nada ter mudado no código. O primeiro rodou
logo após o `npm install`, com o cache do Windows quente; os seguintes
levaram ~90s e o `timeout 60` do meu teste os matou com 124 — que eu li como
"travou". A conclusão errada era plausível, porque eu tinha acabado de mexer
no gerador.

> **Um teste que falha por timeout não distingue "o programa travou" de "o
> programa é mais lento que o meu limite".**

`blockly/roda.sh` instala as dependências num cache fora de `/mnt/c` e aponta
o `NODE_PATH` para lá. E há um detalhe necessário: o Node procura
`node_modules` subindo a árvore **do script** antes de consultar `NODE_PATH`,
então o `node_modules` do lado lento precisa **não existir**.

## O que o projeto mede sobre linguagens de blocos

A lição 5 — recursão que ramifica — é onde as quatro linguagens deixam de ser
equivalentes:

| linguagem | a árvore é | tamanho |
|---|---|---|
| **Logo** | recursão com duas chamadas | **9 linhas** |
| **Smalltalk** | idem, com mensagem para si mesma | 9 linhas |
| **Pascal** | idem, com tipos | 12 linhas |
| **Scratch** | a expansão **plana** do traço | **75 blocos** |
| **Blockly** | idem | 75 blocos |

Scratch e Blockly **não têm versão natural** dessa lição. Duas chamadas
recursivas com posição compartilhada é exatamente o que o modelo de execução
de blocos não favorece: não há pilha visível, e "voltar ao ponto de divisão"
exige salvar e restaurar posição à mão, por nível.

E no Blockly isso é especialmente instrutivo, porque **eu construí a
linguagem de blocos**: mesmo escolhendo quais blocos existem, recursão que
ramifica não fica natural sem reintroduzir procedimento com parâmetro — isto
é, sem reinventar o que o texto já tem.

> A conclusão pedagógica: há conceitos que blocos ensinam **melhor** que texto
> (evento, iteração, paralelismo) e conceitos que não ensinam bem (recursão
> que ramifica). O currículo tem várias linguagens porque nenhuma cobre tudo,
> e a lição 5 é onde isso fica **medido** em vez de opinado.

## Rodando

```bash
sudo apt-get install -y fp-compiler ucblogo xvfb nodejs npm

# Pharo (Smalltalk): livre, MIT, e não tem pacote no Ubuntu
mkdir -p ~/pharo/vm ~/pharo/img && cd ~/pharo
curl -L -o vm.zip  https://files.pharo.org/vm/pharo-spur64-headless/Linux-x86_64/stable.zip
curl -L -o img.zip https://files.pharo.org/image/110/latest-64.zip
unzip -q vm.zip -d vm && unzip -q img.zip -d img

./verifica.sh
```

O Pharo é **autocontido**: nada vai para `/usr`, nada se registra no sistema.
O registro de tudo o que o portfólio instalou, com os comandos de remoção,
está em
[AMBIENTE.md](https://github.com/Brunowdgaster/poliglota/blob/main/AMBIENTE.md).

A suíte **pula** o que não está instalado em vez de falhar, e `P14_EXIGE=1`
transforma todo "pulado" em falha — que é o que o CI liga, porque lá uma
dependência ausente é defeito do ambiente, não resultado.

```
  ok    lição 1 == lição 2: o laço é abreviação, e o diff sai vazio
  ok    Logo lição 5 idêntica à referência
  ok    o .sb3 é byte a byte igual a cada geração
  ok    o simulador recusa opcode desconhecido, em vez de ignorar
  ok    a lição 2 faz o mesmo com 3 blocos onde a 1 usa 8
  ok    o gerador do traço define scrub_ (sem ele, só o 1º bloco sai)
  32 passaram, 0 falharam
```

## Licença

MIT, em `LICENSE`.
