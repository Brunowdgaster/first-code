{ licoes.pas — as cinco lições do currículo, em Free Pascal.

  Compilar e rodar:

      fpc -O2 pascal/licoes.pas
      ./pascal/licoes 1

  ## Por que o Pascal é a implementação de referência

  Pelo mesmo motivo que o C é a referência no p01-metal-vm e o Python no
  p10-query-lab: é a implementação mais direta. Não há ambiente vivo, motor de
  blocos, display virtual nem interpretador no caminho. `writeln` escreve em
  stdout, e ponto.

  Se esta implementação estiver errada, está errada de um jeito que se lê.

  ## E por que o Pascal está num currículo de programação visual

  Porque ele é o contraponto, e o currículo precisa de um.

  Logo, Scratch e Blockly ensinam a IDEIA sem cobrar a sintaxe: o aluno
  arrasta um bloco de repetição e ele repete. O Pascal cobra tudo --
  declaração antes do uso, tipo em cada variável, `begin`/`end` em cada bloco,
  ponto e vírgula entre comandos -- e em troca dá a primeira experiência de
  **o compilador recusando um programa errado antes de ele rodar**.

  As duas experiências são necessárias, e em ordem: quem nunca viu a ideia
  funcionar desiste na primeira mensagem de erro; quem só viu blocos nunca
  descobre que existe uma máquina checando.

  Wirth projetou o Pascal exatamente para isso -- ensinar programação
  estruturada em 1970 -- e o fato de ele continuar sendo bom nisso 56 anos
  depois é o argumento contra a ideia de que linguagem educacional é
  brinquedo.

  ## A nota de rigor que o Pascal traz de graça

  As cinco lições deste arquivo são verificadas por tipo em tempo de
  compilação. As diretivas MODE OBJFPC e H+ no topo ligam o modo mais estrito
  do Free Pascal, e os avisos tratados como erro (-Sewn) garantem que nada
  passa por descuido -- a mesma política do TreatWarningsAsErrors no porte em
  F# do p02-forge-lang.

  E a primeira compilação deste arquivo FALHOU por essa política, de um jeito
  que vale registrar: a prosa acima citava as diretivas entre chaves, e chave
  dentro de comentário de chave é comentário ANINHADO -- "Comment level 2
  found". Com aviso virando erro, o compilador recusou o programa por causa de
  um comentário. É exatamente o rigor que o Pascal traz ao currículo, aplicado
  contra quem o escreveu.
}

{$MODE OBJFPC}
{$H+}

program Licoes;

uses
  SysUtils;

{ ---------------------------------------------------------------------------
  A tartaruga.

  Ela NÃO desenha: ela emite o traço. Essa é a decisão de projeto que torna as
  quatro implementações comparáveis -- ver TRACO.md.

  Um `write` por comando, e o argumento como inteiro. Inteiro e não real
  porque quatro linguagens formatam ponto flutuante de quatro maneiras, e a
  comparação byte a byte acusaria divergência onde há só arredondamento.
  --------------------------------------------------------------------------- }

procedure Frente(Passos: Integer);
begin
  WriteLn('F ', Passos);
end;

procedure Tras(Passos: Integer);
begin
  WriteLn('B ', Passos);
end;

procedure Direita(Graus: Integer);
begin
  WriteLn('R ', Graus);
end;

procedure Esquerda(Graus: Integer);
begin
  WriteLn('L ', Graus);
end;

procedure CanetaCima;
begin
  WriteLn('PU');
end;

procedure CanetaBaixo;
begin
  WriteLn('PD');
end;

{ ---------------------------------------------------------------------------
  LIÇÃO 1 — sequência

  Conceito: comandos acontecem EM ORDEM, e a tartaruga guarda estado entre
  eles. O `R 90` só faz sentido porque o `F 100` anterior deixou a tartaruga
  em algum lugar, virada para algum lado.

  O quadrado é escrito à mão, oito comandos, de propósito. O aluno tem de
  sentir a repetição no DEDO antes de receber o laço -- senão o laço é uma
  palavra mágica em vez de uma abreviação de algo que ele já fez.
  --------------------------------------------------------------------------- }

procedure Licao1;
begin
  Frente(100);
  Direita(90);
  Frente(100);
  Direita(90);
  Frente(100);
  Direita(90);
  Frente(100);
  Direita(90);
end;

{ ---------------------------------------------------------------------------
  LIÇÃO 2 — repetição

  Conceito: o laço é uma ABREVIAÇÃO, não uma coisa nova.

  E o currículo prova isso: o traço desta lição é **byte a byte idêntico** ao
  da lição 1. A pergunta que todo iniciante faz ao ver um laço -- "isso faz a
  mesma coisa?" -- é respondida por um `diff` vazio, não pela palavra do
  professor.

  A suíte compara os dois traços. Se alguém mudar uma das lições e quebrar a
  equivalência, o teste falha dizendo exatamente isso.
  --------------------------------------------------------------------------- }

procedure Licao2;
var
  I: Integer;
begin
  for I := 1 to 4 do
  begin
    Frente(100);
    Direita(90);
  end;
end;

{ ---------------------------------------------------------------------------
  LIÇÃO 3 — procedimento com parâmetro

  Conceito: dar NOME a uma ideia, e depois variá-la.

  `Poligono(3)`, `Poligono(4)`, `Poligono(6)`: o mesmo nome, três desenhos. E
  o `360 div Lados` é onde a geometria entra -- o aluno descobre que a soma
  dos giros de uma volta fechada é sempre 360, que é um teorema disfarçado de
  brincadeira.

  `div` e não `/`: divisão inteira, porque o traço só tem inteiros. E os lados
  escolhidos (3, 4, 6) são justamente os que dividem 360 exatamente -- 5 daria
  72 (exato), mas 7 daria 51,43 e o desenho não fecharia. Essa é a primeira
  vez que o currículo encosta em "o computador trunca", e o comentário existe
  para o professor saber que é deliberado.
  --------------------------------------------------------------------------- }

procedure Poligono(Lados: Integer; Tamanho: Integer);
var
  I: Integer;
begin
  for I := 1 to Lados do
  begin
    Frente(Tamanho);
    Direita(360 div Lados);
  end;
end;

procedure Licao3;
begin
  Poligono(3, 80);
  CanetaCima;
  Frente(120);
  CanetaBaixo;
  Poligono(4, 80);
  CanetaCima;
  Frente(120);
  CanetaBaixo;
  Poligono(6, 80);
end;

{ ---------------------------------------------------------------------------
  LIÇÃO 4 — recursão com parada

  Conceito: um procedimento que CHAMA A SI MESMO, e a condição que o faz
  parar.

  A espiral é o exemplo canônico porque a parada é visível: cada chamada
  encurta o passo, e quando o passo fica pequeno demais a figura acaba. O
  aluno vê a recursão terminar, em vez de ouvir que ela termina.

  E o `if Passo < 10 then Exit` vem ANTES da primeira ação, de propósito: é a
  forma que não executa nada no caso base. Pôr a condição no fim é o erro
  clássico, e produz um desenho com um traço a mais -- que o traço esperado
  pegaria.
  --------------------------------------------------------------------------- }

procedure Espiral(Passo: Integer);
begin
  if Passo < 10 then
    Exit;
  Frente(Passo);
  Direita(60);
  Espiral(Passo - 10);
end;

procedure Licao4;
begin
  Espiral(100);
end;

{ ---------------------------------------------------------------------------
  LIÇÃO 5 — recursão que ramifica

  Conceito: DUAS chamadas recursivas. É onde a recursão deixa de ser um laço
  disfarçado.

  A árvore é o exemplo pelo qual o Logo foi inventado: o galho se divide em
  dois, cada um se divide em dois, e o desenho que sai não tem como ser
  escrito com repetição simples. Em linguagem imperativa, fazer isso sem
  recursão exige administrar uma pilha à mão.

  O `Tras(Tamanho)` no fim de cada ramo é a parte que ninguém acerta de
  primeira: a tartaruga precisa VOLTAR ao ponto de divisão antes do segundo
  galho, senão a árvore sai torta. É estado mutável global mordendo, e a lição
  é melhor justamente por isso.
  --------------------------------------------------------------------------- }

procedure Arvore(Tamanho: Integer);
begin
  if Tamanho < 20 then
    Exit;

  Frente(Tamanho);

  Esquerda(30);
  Arvore(Tamanho - 20);
  Direita(60);
  Arvore(Tamanho - 20);
  Esquerda(30);

  { Volta ao ponto de divisão. Sem isto, cada galho desloca a origem do
    seguinte e a árvore sai torta -- e o traço esperado pega. }
  Tras(Tamanho);
end;

procedure Licao5;
begin
  Arvore(80);
end;

{ --------------------------------------------------------------------------- }

var
  Qual: Integer;
begin
  if ParamCount <> 1 then
  begin
    WriteLn(StdErr, 'uso: licoes <1..5>');
    Halt(64);
  end;

  if not TryStrToInt(ParamStr(1), Qual) then
  begin
    WriteLn(StdErr, 'lição inválida: ', ParamStr(1));
    Halt(64);
  end;

  case Qual of
    1: Licao1;
    2: Licao2;
    3: Licao3;
    4: Licao4;
    5: Licao5;
  else
    WriteLn(StdErr, 'lição fora de 1..5: ', Qual);
    Halt(64);
  end;
end.
