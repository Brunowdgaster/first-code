#!/usr/bin/env node
// gera.js — carrega uma lição em blocos e roda um gerador.
//
//     node blockly/gera.js 2                 # o traço da lição 2
//     node blockly/gera.js 2 --forge         # a mesma lição em código forge
//     node blockly/gera.js 2 --blocos        # quantos blocos a lição tem
//
// ## As lições são DADOS, não código
//
// Cada lição é um XML de blocos em `blockly/licoes/`. Esse é o formato que o
// editor do Blockly salva e carrega, então os arquivos deste diretório são
// exatamente o que sairia de alguém montando as lições arrastando blocos.
//
// Escrever as lições como chamadas de API em JavaScript seria mais curto e
// mentiria sobre o que elas são: o conteúdo de um currículo de programação
// visual tem de ser um artefato visual.

const fs = require('fs');
const path = require('path');
const { Blockly, traco, forge } = require('./blocos.js');

const AQUI = __dirname;

function uso(codigo) {
  console.error('uso: gera.js <1..5> [--forge|--blocos]');
  process.exit(codigo);
}

const args = process.argv.slice(2);
const licao = args.find((a) => /^[1-5]$/.test(a));
if (!licao) uso(64);

const arquivo = path.join(AQUI, 'licoes', `licao${licao}.xml`);
if (!fs.existsSync(arquivo)) {
  console.error(`não achei ${arquivo}`);
  process.exit(66);
}

// Workspace SEM renderizador: e isto que faz o Blockly rodar em Node.
//
// A documentacao do Blockly e toda sobre `Blockly.inject(div, opcoes)`, que
// exige DOM. `new Blockly.Workspace()` cria a estrutura de dados sem
// interface, e os geradores percorrem essa estrutura -- que e tudo o que eles
// precisam.
const workspace = new Blockly.Workspace();

const xml = Blockly.utils.xml.textToDom(fs.readFileSync(arquivo, 'utf8'));
Blockly.Xml.domToWorkspace(xml, workspace);

// Falha ALTO se o XML nao produziu bloco nenhum.
//
// Sem isto, um XML com nome de bloco errado carregaria VAZIO e o gerador
// emitiria string vazia -- e a suite acusaria "traco divergente" em vez de
// "a licao nao carregou". Distinguir os dois e a diferenca entre um log que
// aponta a causa e um que manda procurar.
const topo = workspace.getTopBlocks(true);
if (topo.length === 0) {
  console.error(`a lição ${licao} carregou ZERO blocos.`);
  console.error('provável causa: nome de bloco no XML que blocos.js não define.');
  process.exit(1);
}
if (topo.length > 1) {
  console.error(`a lição ${licao} tem ${topo.length} pilhas soltas, esperado 1.`);
  process.exit(1);
}

if (args.includes('--blocos')) {
  console.log(workspace.getAllBlocks(false).length);
  process.exit(0);
}

const gerador = args.includes('--forge') ? forge : traco;
const codigo = gerador.workspaceToCode(workspace);

// `trimEnd` e `\n` final: `workspaceToCode` pode deixar linha em branco no
// fim, e a comparacao byte a byte com os outros tracos nao tolera isso.
process.stdout.write(`${codigo.trimEnd()}\n`);
