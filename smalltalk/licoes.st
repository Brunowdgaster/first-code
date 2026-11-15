"licoes.st — as cinco licoes do curriculo, em Smalltalk (Pharo 11).

 ## Por que o Smalltalk esta num curriculo de programacao visual

 Porque ele e o unico aqui em que o PROGRAMA e um objeto vivo, e nao um texto
 que se compila.

 As outras quatro linguagens deste projeto tem a mesma forma: escreve-se um
 arquivo, roda-se, ve-se a saida. Em Smalltalk a tartaruga e um OBJETO que
 existe, responde a mensagens, e pode ser inspecionado enquanto trabalha. Kay
 e Ingalls projetaram o Smalltalk-80 no Xerox PARC com crianca em mente -- o
 mesmo laboratorio e a mesma epoca do Logo de Papert -- e a ideia era que
 programar fosse CONVERSAR com objetos.

 E e o berco do OO. Ler Smalltalk muda como se escreve OO em qualquer
 linguagem, porque aqui nao existe funcao solta: so objeto recebendo mensagem.
 A expressao 3 + 4 e o objeto 3 recebendo a mensagem + com o argumento 4, e
 isso nao e curiosidade sintatica -- e o modelo inteiro.

 ## O que a versao Smalltalk mostra que as outras nao

 Nas outras quatro, a tartaruga e um conjunto de procedimentos que escrevem
 numa saida global. Aqui ela e uma CLASSE com estado proprio, e as licoes sao
 METODOS dessa classe.

 A diferenca aparece na licao 5: a arvore recursiva precisa que a tartaruga
 volte ao ponto de divisao, e em Pascal isso e um procedimento mexendo em
 estado global. Aqui e `self tras: tamanho` -- uma mensagem para si mesma, e o
 estado pertence ao objeto. Duas tartarugas poderiam desenhar ao mesmo tempo,
 o que nas outras implementacoes exigiria reescrever tudo.

 ## Como os metodos sao definidos, e por que nao e o jeito classico

 O jeito classico de um arquivo .st definir metodos e o formato chunk, em que
 uma linha com o separador, o nome da classe e `methodsFor:` abre um bloco de
 metodos, e dois separadores o fecham.

 Esse foi o primeiro desenho deste arquivo, e ele falhou DUAS VEZES.

 Primeiro porque o separador de chunk e cortado ANTES de o codigo ser
 analisado -- entao escrever um exemplo do formato DENTRO deste comentario
 partia o comentario no meio, e o erro saia como 'Unknown character' apontando
 para uma linha de prosa. E por isso que o exemplo acima esta descrito em
 palavras em vez de mostrado.

 ## E por que CADA declaracao termina com o separador

 A versao seguinte tirou todos os separadores, por seguranca. Resultado: o
 arquivo inteiro virou UM chunk, e o Pharo reclamou vinte vezes de

     NewUndeclaredWarning: UndefinedObject>>DoIt (Tartaruga is Undeclared)

 antes de pendurar.

 A razao e boa: um chunk e compilado INTEIRO antes de ser executado. A classe
 Tartaruga passa a existir quando o `Object subclass:` RODA -- e no momento em
 que o compilador le a linha seguinte, que menciona Tartaruga, ela ainda nao
 existe. O compilador trata o nome como variavel indefinida.

 Entao o separador nao e decoracao de formato antigo: ele e o que diz
 'compile e execute ate aqui antes de ler o resto'. E um arquivo que define
 uma classe e logo a usa PRECISA dele.

 Essa e a mesma ideia que em Lisp se chama `eval-when-compile` e em C e a
 ordem das unidades de traducao: a diferenca e que em Smalltalk o limite e
 explicito no texto.

 E depois porque, no Pharo 11:

     Instance of Tartaruga class did not understand #methodsFor:

 O `methodsFor:` foi removido. Perguntado a propria imagem, para nao supor:

     (Object respondsTo: #methodsFor:)        false
     (Object respondsTo: #compile:classified:) true

 Entao os metodos vao por `compile:classified:`, com o corpo numa string.

 E isso cria um problema de legibilidade que a escolha abaixo resolve: aspas
 simples dentro de uma string de aspas simples precisam ser DOBRADAS, e um
 metodo que emita a letra F escreveria `''F ''`, que e ilegivel num material
 didatico.

 A saida e usar SYMBOL em vez de string -- `#F asString` -- e um unico metodo
 privado que monta a linha. Nenhuma aspa aninhada em todo o arquivo, e de
 passagem o codigo fica melhor: a letra do traco vira um nome, nao um
 literal repetido seis vezes.
"

Object subclass: #Tartaruga
    instanceVariableNames: 'traco'
    classVariableNames: ''
    package: 'FirstCode'!

"--------------------------------------------------------------------------
 A tartaruga: ela NAO desenha, acumula o traco.

 WriteStream e nao concatenacao de String: concatenar cria uma String nova a
 cada comando, e a licao 5 emite 75 deles.
 -------------------------------------------------------------------------"

Tartaruga compile: 'initialize
    super initialize.
    traco := WriteStream on: String new' classified: 'inicializacao'!

Tartaruga compile: 'traco
    ^ traco contents' classified: 'acesso'!

"O unico metodo que conhece o FORMATO do traco. Os seis comandos abaixo so
 dizem QUAL letra e QUAL argumento -- que e o que um formato deve permitir."
Tartaruga compile: 'emite: letra com: n
    traco nextPutAll: letra asString; nextPut: Character space;
          nextPutAll: n printString; lf' classified: 'privado'!

Tartaruga compile: 'emite: letra
    traco nextPutAll: letra asString; lf' classified: 'privado'!

Tartaruga compile: 'frente: n
    self emite: #F com: n' classified: 'movimento'!

Tartaruga compile: 'tras: n
    self emite: #B com: n' classified: 'movimento'!

Tartaruga compile: 'direita: g
    self emite: #R com: g' classified: 'movimento'!

Tartaruga compile: 'esquerda: g
    self emite: #L com: g' classified: 'movimento'!

Tartaruga compile: 'canetaCima
    self emite: #PU' classified: 'movimento'!

Tartaruga compile: 'canetaBaixo
    self emite: #PD' classified: 'movimento'!

"--------------------------------------------------------------------------
 LICAO 1 — sequencia

 Oito mensagens, uma por uma. O aluno sente a repeticao no dedo antes de
 receber o laco.

 E aqui aparece a CASCATA do Smalltalk -- o ponto e virgula -- que nao tem
 equivalente nas outras quatro: `self frente: 100; direita: 90` envia duas
 mensagens ao MESMO receptor. E a forma mais economica de dizer faca isto e
 aquilo com a mesma coisa que qualquer linguagem deste portfolio oferece.
 -------------------------------------------------------------------------"

Tartaruga compile: 'licao1
    self frente: 100; direita: 90.
    self frente: 100; direita: 90.
    self frente: 100; direita: 90.
    self frente: 100; direita: 90' classified: 'licoes'!

"--------------------------------------------------------------------------
 LICAO 2 — repeticao

 `4 timesRepeat: [ ... ]` e, em Smalltalk, uma MENSAGEM enviada ao numero 4,
 com um bloco como argumento. Nao e sintaxe de laco: timesRepeat: e um metodo
 de Integer, escrito em Smalltalk, que se pode abrir e ler.

 Isso e dificil de exagerar como fato pedagogico: num curriculo em Smalltalk,
 o aluno pode INSPECIONAR a implementacao do proprio laco. Em Pascal, `for` e
 palavra reservada do compilador e nao tem dentro.

 O traco e identico ao da licao 1, e a suite verifica.
 -------------------------------------------------------------------------"

Tartaruga compile: 'licao2
    4 timesRepeat: [ self frente: 100; direita: 90 ]' classified: 'licoes'!

"--------------------------------------------------------------------------
 LICAO 3 — metodo com parametro

 O nome do metodo e `poligonoDeLados:tamanho:`, com as palavras-chave JUNTO
 dos argumentos. Compare com `Poligono(3, 80)` do Pascal, em que a ordem dos
 argumentos e a unica pista do que cada um significa.

 `//` e divisao INTEIRA, e nao `/`, que em Smalltalk devolve uma Fraction
 exata -- 360/7 seria a fracao 360/7, nao 51. O traco so admite inteiros, e
 `//` e o que mantem esta implementacao alinhada com o div do Pascal e o
 quotient do Logo.
 -------------------------------------------------------------------------"

Tartaruga compile: 'poligonoDeLados: lados tamanho: tamanho
    lados timesRepeat: [ self frente: tamanho; direita: 360 // lados ]'
    classified: 'licoes'!

Tartaruga compile: 'licao3
    self poligonoDeLados: 3 tamanho: 80.
    self canetaCima; frente: 120; canetaBaixo.
    self poligonoDeLados: 4 tamanho: 80.
    self canetaCima; frente: 120; canetaBaixo.
    self poligonoDeLados: 6 tamanho: 80' classified: 'licoes'!

"--------------------------------------------------------------------------
 LICAO 4 — recursao com parada

 `ifTrue: [ ^ self ]` e a guarda, e o acento circunflexo retorna. Note que
 ifTrue: tambem e uma MENSAGEM -- enviada a um Boolean, com um bloco -- e nao
 sintaxe de condicional.
 -------------------------------------------------------------------------"

Tartaruga compile: 'espiral: passo
    passo < 10 ifTrue: [ ^ self ].
    self frente: passo; direita: 60.
    self espiral: passo - 10' classified: 'licoes'!

Tartaruga compile: 'licao4
    self espiral: 100' classified: 'licoes'!

"--------------------------------------------------------------------------
 LICAO 5 — recursao que ramifica

 A arvore. Em Smalltalk ela tem nove linhas, como em Logo -- e nao 75 blocos,
 como em Scratch e Blockly.

 E o `self tras: tamanho` do fim e a parte que torna esta versao diferente de
 todas as outras: a tartaruga envia a mensagem PARA SI MESMA, e o estado que
 ela ajusta e dela. Em Pascal o equivalente mexe em estado global; aqui duas
 tartarugas poderiam desenhar ao mesmo tempo sem se atropelar, e isso sai de
 graca do modelo de objetos.
 -------------------------------------------------------------------------"

Tartaruga compile: 'arvore: tamanho
    tamanho < 20 ifTrue: [ ^ self ].
    self frente: tamanho.
    self esquerda: 30.
    self arvore: tamanho - 20.
    self direita: 60.
    self arvore: tamanho - 20.
    self esquerda: 30.
    self tras: tamanho' classified: 'licoes'!

Tartaruga compile: 'licao5
    self arvore: 80' classified: 'licoes'!

"Despacho por numero. `perform:` envia uma mensagem cujo nome e CALCULADO em
 tempo de execucao -- o que em Pascal exigiria um case e em C um ponteiro de
 funcao. Aqui o nome do metodo e so um Symbol montado por concatenacao."
Tartaruga compile: 'licaoNumero: n
    ^ self perform: (#licao , n printString) asSymbol' classified: 'licoes'!
