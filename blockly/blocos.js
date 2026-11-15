// blocos.js — os blocos da tartaruga e os geradores de código.
//
// ## O que o Blockly é, e por que ele não é "o Scratch de novo"
//
// Scratch é um produto: um editor fechado, com uma paleta fixa, que salva
// `.sb3`. Blockly é uma **biblioteca** para construir editores de blocos — é
// o que está por baixo do Scratch 3, do App Inventor, do Code.org.
//
// A diferença prática aparece aqui: no Blockly eu DEFINO os blocos e DEFINO
// o que cada um gera. Scratch tem `motion_movesteps` porque a equipe do
// Scratch decidiu; este arquivo tem `tartaruga_frente` porque este currículo
// decidiu.
//
// E é por isso que o Blockly entra num portfólio de linguagens: ele mostra o
// outro lado da programação visual — não "usei uma ferramenta de blocos", mas
// **"construí uma"**.
//
// ## Dois geradores, de propósito
//
// 1. `traco` — emite o formato comum do projeto, que é comparado byte a byte
//    com Pascal, Logo e Scratch. É o que torna esta implementação verificada
//    e não ilustrativa.
//
// 2. `forge` — emite código na linguagem `forge`, que é a linguagem com
//    sistema de tipos Hindley-Milner do `p02-forge-lang`, outro projeto deste
//    portfólio. O código gerado é então **compilado e verificado por tipo**
//    pelo compilador de lá.
//
// O segundo é o ponto alto: um aluno arrasta blocos, e o resultado passa por
// um verificador de tipos de verdade. Blocos deixam de ser brinquedo e viram
// a interface de um compilador.
//
// ## Blockly roda sem navegador, e isso não é óbvio
//
// Blockly é uma biblioteca de interface, e a documentação é toda sobre
// injetar um editor numa página. Mas `blockly/core` funciona em Node com um
// `new Blockly.Workspace()` sem renderizador: os blocos existem como estrutura
// de dados, e os geradores percorrem essa estrutura.
//
// É isso que permite ao CI verificar os blocos sem navegador nem display
// virtual — diferente do Logo deste mesmo projeto, que precisa de `xvfb`.

const Blockly = require('blockly/core');

// ---------------------------------------------------------------------------
// Os blocos.
//
// `message0` com `%1` é como o Blockly declara onde o campo entra no texto do
// bloco. `args0` descreve os campos: `field_number` é uma caixa de número
// editável, e `input_statement` é o encaixe de corpo de um bloco C.
// ---------------------------------------------------------------------------

Blockly.defineBlocksWithJsonArray([
  {
    type: 'tartaruga_frente',
    message0: 'ande %1 passos',
    args0: [{ type: 'field_number', name: 'N', value: 100, precision: 1 }],
    previousStatement: null,
    nextStatement: null,
    colour: 160,
    tooltip: 'Move a tartaruga para a frente, desenhando.',
  },
  {
    type: 'tartaruga_tras',
    message0: 'volte %1 passos',
    args0: [{ type: 'field_number', name: 'N', value: 100, precision: 1 }],
    previousStatement: null,
    nextStatement: null,
    colour: 160,
  },
  {
    type: 'tartaruga_direita',
    message0: 'gire %1 graus à direita',
    args0: [{ type: 'field_number', name: 'G', value: 90, precision: 1 }],
    previousStatement: null,
    nextStatement: null,
    colour: 210,
  },
  {
    type: 'tartaruga_esquerda',
    message0: 'gire %1 graus à esquerda',
    args0: [{ type: 'field_number', name: 'G', value: 90, precision: 1 }],
    previousStatement: null,
    nextStatement: null,
    colour: 210,
  },
  {
    type: 'tartaruga_caneta',
    // `field_dropdown` em vez de dois blocos separados: menos blocos na
    // paleta, e o aluno vê que "levantar" e "abaixar" são o mesmo conceito
    // com dois valores. Scratch usa dois blocos; a escolha aqui é diferente
    // de propósito, e é o tipo de decisão que só existe para quem CONSTRÓI o
    // editor.
    message0: 'caneta %1',
    args0: [{
      type: 'field_dropdown',
      name: 'ESTADO',
      options: [['abaixada', 'PD'], ['levantada', 'PU']],
    }],
    previousStatement: null,
    nextStatement: null,
    colour: 20,
  },
  {
    type: 'tartaruga_repita',
    message0: 'repita %1 vezes',
    args0: [{ type: 'field_number', name: 'VEZES', value: 4, min: 0,
              precision: 1 }],
    message1: '%1',
    args1: [{ type: 'input_statement', name: 'CORPO' }],
    previousStatement: null,
    nextStatement: null,
    colour: 120,
  },
]);

// ---------------------------------------------------------------------------
// Gerador 1: o traço.
//
// Um gerador do Blockly é um objeto `CodeGenerator` com uma função por tipo
// de bloco. `blockToCode` chama a função do bloco e, para blocos de comando,
// concatena com o próximo da pilha.
// ---------------------------------------------------------------------------

const traco = new Blockly.CodeGenerator('TRACO');

// `INDENT` vazio: o traço não tem indentação, e o padrão do Blockly são dois
// espaços. Sem isto, os comandos dentro de um `repita` sairiam indentados e a
// comparação byte a byte com o Pascal falharia -- por formatação, não por
// semântica.
traco.INDENT = '';

traco.forBlock['tartaruga_frente'] = (b) =>
  `F ${b.getFieldValue('N')}\n`;

traco.forBlock['tartaruga_tras'] = (b) =>
  `B ${b.getFieldValue('N')}\n`;

traco.forBlock['tartaruga_direita'] = (b) =>
  `R ${b.getFieldValue('G')}\n`;

traco.forBlock['tartaruga_esquerda'] = (b) =>
  `L ${b.getFieldValue('G')}\n`;

traco.forBlock['tartaruga_caneta'] = (b) =>
  `${b.getFieldValue('ESTADO')}\n`;

// `scrub_` e OBRIGATORIO, e a sua ausencia nao da erro.
//
// O `CodeGenerator` do Blockly NAO encadeia blocos por padrao: `blockToCode`
// chama a funcao do bloco e passa o resultado por `scrub_`, cuja
// implementacao base devolve o codigo SEM olhar o proximo bloco da pilha.
//
// A primeira versao deste arquivo definia `scrub_` so no gerador `forge`, e o
// gerador do traco emitia **apenas o primeiro bloco de cada pilha** -- oito
// blocos viravam uma linha. Nenhum erro, nenhum aviso: codigo curto e errado.
//
// Todo gerador de linguagem do Blockly (JavaScript, Python, Lua, Dart)
// implementa `scrub_`, e e por isso que o esqueleto nunca aparece na
// documentacao: quem usa um gerador pronto nunca ve essa peca.
traco.scrub_ = function (block, code, thisOnly) {
  const proximo = block.getNextBlock();
  if (proximo && !thisOnly) {
    return code + traco.blockToCode(proximo);
  }
  return code;
};

traco.forBlock['tartaruga_repita'] = function (b) {
  // `statementToCode` gera o corpo. E o laço é DESENROLADO aqui: o traço é um
  // registro do que a tartaruga fez, não um programa -- então `repita 4`
  // precisa emitir o corpo quatro vezes.
  //
  // É a mesma razão pela qual a lição 1 e a lição 2 têm traços idênticos: o
  // traço não sabe se houve laço, e esse é exatamente o conteúdo da lição.
  const corpo = traco.statementToCode(b, 'CORPO');
  const vezes = parseInt(b.getFieldValue('VEZES'), 10);
  return corpo.repeat(vezes);
};

// ---------------------------------------------------------------------------
// Gerador 2: código `forge`, a linguagem do p02-forge-lang.
//
// O que sai daqui é compilado e VERIFICADO POR TIPO pelo compilador em
// Haskell daquele projeto. O aluno arrasta blocos e o resultado passa por
// inferência Hindley-Milner.
//
// `forge` é funcional e não tem efeito colateral nem laço imperativo, então a
// tradução não é mecânica -- e é aí que fica interessante:
//
//   * cada comando devolve uma LISTA de comandos, e a pilha de blocos vira
//     concatenação;
//   * `repita n` vira `concatMap` sobre uma lista de n elementos, porque não
//     há `for`.
//
// Um aluno que olhe os dois geradores lado a lado vê a mesma árvore de blocos
// produzir código imperativo e código funcional. Isso é difícil de ensinar com
// palavras.
// ---------------------------------------------------------------------------

const forge = new Blockly.CodeGenerator('FORGE');
forge.INDENT = '  ';

forge.forBlock['tartaruga_frente'] = (b) =>
  `[Frente ${b.getFieldValue('N')}]`;

forge.forBlock['tartaruga_tras'] = (b) =>
  `[Tras ${b.getFieldValue('N')}]`;

forge.forBlock['tartaruga_direita'] = (b) =>
  `[Direita ${b.getFieldValue('G')}]`;

forge.forBlock['tartaruga_esquerda'] = (b) =>
  `[Esquerda ${b.getFieldValue('G')}]`;

forge.forBlock['tartaruga_caneta'] = (b) =>
  b.getFieldValue('ESTADO') === 'PU' ? '[CanetaCima]' : '[CanetaBaixo]';

forge.forBlock['tartaruga_repita'] = function (b) {
  const corpo = forge.statementToCode(b, 'CORPO').trim() || '[]';
  const vezes = b.getFieldValue('VEZES');
  return `(repete ${vezes} ${corpo})`;
};

// No `forge`, blocos em sequencia viram CONCATENACAO de listas, e nao linhas
// uma embaixo da outra. Este hook e o que o Blockly chama para juntar um
// bloco com o proximo da pilha.
forge.scrub_ = function (block, code, thisOnly) {
  const proximo = block.getNextBlock();
  if (proximo && !thisOnly) {
    return `${code} ++ ${forge.blockToCode(proximo)}`;
  }
  return code;
};

module.exports = { Blockly, traco, forge };
