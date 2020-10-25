<div align="center">

  <h1><code>Elixir Queue</code></h1>
</div>

## 🗺 Translations
- [🇺🇸 English](./README.en_US.md)

## 🤔 Motivação
O motivo principal pelo qual resolvi desenvolver essa fila de processos foi o aprendizado das estruturas e APIs do Erlang/OTP utilizando o Elixir. Provalvemente existem muitas outras filas de processamento de serviços em segundo plano espalhadas por ai bem mais eficientes do que esta que se encontra aqui. No entanto acredito que para quem está começando é demasiado interessante ter acesso a estruturas mais simples, tanto do ponto de vista de lógica de programação quanto da perspectiva operacional do OTP. Por isso optei por fazer desde a base um software para execução de processos de forma a conseguir explicar as tomadas de decisão e, eventualmente, ir corrigindo esse caminho conforme a comunidade demonstre que uma ou outra opção é melhor, através de _pull requests_ ou mesmo _issues_ abertas. Tenho certeza que será de grande ajuda para iniciantes e para mim o que for tratado aqui.

## 📘 Estrutura
### Fluxo/Diagrama da aplicação
Abaixo um diagrama completo do fluxo de dados e possibilidades de acontecimentos do sistema.
![Diagrama de fluxo de aplicação](https://raw.githubusercontent.com/abmBispo/elixir-queue/master/ElixirQueue.png)

### ElixirQueue.Application
A `Application`desta fila de processos supervisiona os processos que irão criar/consumir a fila. Eis os filhos da `ElixirQueue.Supervisor`:
```ex
children = [
  {ElixirQueue.Queue, name: ElixirQueue.Queue},
  {DynamicSupervisor, name: ElixirQueue.WorkerSupervisor, strategy: :one_for_one},
  {ElixirQueue.WorkerPool, name: ElixirQueue.WorkerPool},
  {ElixirQueue.EventLoop, []}
]
```
Os filhos, de cima para baixo, representam as seguintes estruturas: `ElixirQueue.Queue` é o `GenServer` que guarda o estado da fila numa tupla; `ElixirQueue.WorkerSupervisor`é o `DynamicSupervisor` dos _workers_ adicionados dinamicamente sempre igual ou menor que o número de `schedulers` onlines; `ElixirQueue.WorkerPool`, o processo responsável por guardar os `pids` dos _workers_ e os _jobs_ executados, quer seja com sucesso ou falha; e por último o `ElixirQueue.EventLoop` que é a `Task` que "escuta" as mudanças na `ElixirQueue.Queue` (ou seja, na fila de processos) e retira _jobs_ para serem executados. O funcionamento específico de cada módulo eu explicarei conforme for me parecendo útil.

### ElixirQueue.EventLoop
Eis aqui o processo que controla a retirada de elementos da fila. Um _event loop_ por padrão é uma função que executa numa iteração/recursão _pseudo infinita_, uma vez que não existe a intenção de se quebrar o _loop_. A cada ciclo o _loop_ busca _jobs_ adicionados na fila - ou seja, de certa forma o `ElixirQueue.EventLoop` "escuta" as alterações que ocorreram na fila e reage a partir desses eventos - os direciona ao `ElixirQueue.WorkerPool` para serem executados. Este módulo assume o _behaviour_ de `Task` e sua única função (`event_loop/0`) não retorna nenhum valor tendo em vista que é um _loop_ eterno: ela busca da fila algum elemento e pode receber ou uma tupla `{:ok, job}` com a a tarefa a ser realizada ou uma tupla `{:error, :empty}` para caso a fila esteja vazia; no primeiro caso ele envia para o `ElixirQueue.WorkerPool` a tarefa e executa `event_loop/0` novamente; no segundo caso ele apenas executa a própria função recursivamente, continuando o loop até encontrar algum evento relevante (inserção de elemento na fila).

### ElixirQueue.Queue
O módulo `ElixirQueue.Queue` guarda o coração do sistema. Aqui os _jobs_ são enfileirados para serem consumidos mais tarde pelos _workers_. É um `GenServer` sob a supervisão da `ElixirQueue.Application`, que guarda uma tupla como estado e nessa tupla estão guardados os jobs - para entender o porquê eu preferi por uma tupla ao invés de uma lista encadeada (`List`), mais abaixo em **Análise de Desempenho** está explicado. A `Queue` é uma estrutura bem simples, com funções triviais que basicamente limpam, buscam o primeiro elemento da fila para ser executado e insere um elemento ao fim da fila, de forma a ser executado mais tarde, conforme inserção.

### ElixirQueue.WorkerPool
Aqui está o módulo capaz de se comunicar tanto com a fila quanto com os _workers_. Quando a _Application_ é iniciada e os processos supervisionados, um dos eventos que ocorre é justamente a inciação dos _workers_ sob a supervisão do `ElixirQueue.WorkerSupervisor`, um `DynamicSupervisor`, e os seus respectivos _PIDs_ são adicionados ao estado do `ElixirQueue.WorkerPool`. Além disso, cada worker iniciado dentro do escopo do `WorkerPool` é também supervisionado por esse, o motivo disso será abordado a frente.

Quando o `WorkerPool` recebe o pedido para executar um _job_ ele procura por algum de seus _workers PIDs_ que esteja no estado ocioso, ou seja, sem nenhum job sendo executado no momento. Então, para cada _job_ recebido pelo `WorkerPool` através de seu `perform/1`, este vincula o _job_ a um _worker PID_, que passa para o estado de ocupado. Quando o worker termina a execução, limpa seu estado e então fica ocioso, esperando por outro _job_. No caso, isso que aqui chamamos de _worker_ nada mais é do que um `Agent` que guarda em seu estado qual job está sendo executado vinculado àquele PID; ele serve de lastro limitante uma vez que o `WorkerPool` incia uma nova `Task` para cada _job_. Imagine o cenário onde não tivessemos _workers_ para limitar a quantidade de jobs sendo executados concorrentemente: o nosso `EventLoop` inciaria `Task`s a bel prazer, podendo causar grande problemas como estouro de memória caso a `Queue` recebesse uma grande carga de _jobs_ de uma só vez.

### ElixirQueue.Worker
Neste módulo temos os atores responsáveis por tomar os _jobs_ e executá-los. Porém o processo é um pouco mais do que apenas a execução do job; na verdade funciona da seguinte forma:
1. O `Worker` recebe um pedido para performar um certo _job_, adiciona-o ao seu estado interno (estado interno do `Agent` do `PID` passado) e também a uma tabela `:ets` de backup;
2. Depois segue para a execução do _job_ em si. É **extremamente necessário lembrarmos** que a execução ocorre no escopo da `Task` invocada pelo `WorkerPool`, e não no escopo do processo do Agent. Foi uma opção de implementação, poderia ser feito de outras diversas formas porém escolhi assim pela simplicidade que acredito ter ficado o código.
3. Finalmente, com o _job_ finalizado, o `Worker` volta seu estado interno para ocioso e exclui o backup deste worker da tabela `:ets`.
4. Ademais, com a função do `Worker` tendo sido cumprida, a trilha de execução volta para a `Task` invocada pelo `WorkerPool` e apenas completa a corrida inserindo o _job_ na lista de _jobs_ bem sucedidos.

#### Por que o `WorkerPool` superviosiona `Worker`s? Ou: e se `Worker` morrer, como ficamos?
Como ficou claro na explicação, não existe nenhum ponto da trilha de execução dos _jobs_ onde nos preocupamos com a questão: o que acontece se uma função mal feita for passada como _job_ para a fila de execução, _ou até mesmo!_, o que ocorre caso algum processo `Agent` `Worker` simplesmente corromper a memória e morrer? Pois bem, na intenção de escrever o código da forma mais perene possível, talvez o mais _Elixir like_ o possível, o que foi feito é justamente adicionar garantias de que se os processos falharem (e falharão!) o sistema consiga reagir de tal forma que mitigue os erros.

Na ocasião da falha de algum worker que acarrete em sua morte via _EXIT signal_ o `WorkerPool`, que monitora todos os seus workers via `Process.monitor`, repõe este worker morto por outro, adicionando-o ao `WorkerSupervisor`. Com isso também remove o `PID` do `Worker` morto da lista de `PID`s e adiciona o novo. Porém não para por ai: o `WorkerPool` checa por algum backup criado do `Worker` morto e, encontrando, repõe o _job_ na fila com seu valor de _attempt_retry_ adicionado de um. O `WorkerPool` sempre irá adicionar o _job_ novamente na fila uma quantidade pré-determinada de vezes, definida no arquivo `mix.exs`, no _environment_ da _application_. 

## 🏃 Análise de desempenho
### Por que `Tuple` ao invés de `List`
Para fila de processos funcionar normalmente eu preciso apenas de inserir no final e retirar do início. Claramente isso pode ser feito tanto com `List` quanto com `Tuple`, e acabei optando por tuple pelo simples fato de ser mais rápido. Direto do _output_ do Benchee rodando `mix run benchmark.exs` na raiz do projeto:
```
Operating System: Linux
CPU Information: Intel(R) Core(TM) i7-8565U CPU @ 1.80GHz
Number of Available Cores: 8
Available memory: 15.56 GB
Elixir 1.10.2
Erlang 22.3.2

Benchmark suite executing with the following configuration:
warmup: 2 s
time: 5 s
memory time: 0 ns
parallel: 1
inputs: none specified
Estimated total run time: 14 s

Benchmarking Insert element at end of linked list...
Benchmarking Insert element at end of tuple...

Name                                           ips        average  deviation         median         99th %
Insert element at end of tuple              4.89 K      204.42 μs    ±72.94%      119.45 μs      571.85 μs
Insert element at end of linked list        1.24 K      808.27 μs    ±54.67%      573.68 μs     1896.52 μs

Comparison: 
Insert element at end of tuple              4.89 K
Insert element at end of linked list        1.24 K - 3.95x slower +603.85 μs
```

### Teste de estresse
Preparei um teste de estresse para a aplicação que enfileira 1000 _fake jobs_, cada um ordenando uma `List` reversamente ordenada com 3 milhões de elementos, utilizando o `Enum.sort/1` (de acordo com a documentação, o algoritmo é um _merge sort_). Para executá-lo basta entrar no terminal via `iex -S mix` e rodar `ElixirQueue.Fake.populate`; a execução leva alguns minutos (e pelo menos uns 2gb de RAM), e depois você pode conferir os resultados com `ElixirQueue.Fake.spec`.

## 💼 Exemplos de uso
Para ver a fila de processos funcionando basta executar `iex -S mix` na raiz do projeto e utilizar os comandos abaixo. A menos que você esteja em modo `test`, você verá _logs_ de informação sobre a execução do _job_.

### ElixirQueue.Queue.perform_later/1
É possível construir a _struct_ do _job_ manualmente e passá-lo para a fila.
```ex
iex> job = %ElixirQueue.Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}
iex> ElixirQueue.Queue.perform_later(job)
:ok
```

### ElixirQueue.Queue.perform_later/3
Além disso também podemos passar manualmente os valores do módulo, função e argumentos para `perform_later/3`.
```ex
iex> ElixirQueue.Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
:ok
```
