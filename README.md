# ElixirQueue

## Motivação
O motivo principal pelo qual resolvi desenvolver essa fila de processos foi o aprendizado das estruturas e APIs do Erlang/OTP utilizando o Elixir. Provalvemente existem muitas outras filas de processamento de serviços em segundo plano espalhadas por ai bem mais eficientes do que esta que se encontra aqui. No entanto acredito que para quem está começando é demasiado interessante ter acesso a estruturas mais simples, tanto do ponto de vista de lógica de programação quanto da perspectiva operacional do OTP. Por isso optei por fazer desde a base um software para execução de processos de forma a conseguir explicar as tomadas de decisão e, eventualmente, ir corrigindo esse caminho conforme a comunidade demonstre que uma ou outra opção é melhor, através de _pull requests_ ou mesmo _issues_ abertas. Tenho certeza que será de grande ajuda para iniciantes e para mim o que for tratado aqui.

## Estrutura
### ElixirQueue.Application
A `Application`desta fila de processos possui duas funções extremamente relevantes: supervisionar os processos que irão criar/consumir a fila e inciar de 1 a quantidade `System.schedulers_online` processos dinâmicos, os chamados workers, sob a supervisão de `ElixirQueue.WorkerSupervisor`. Eis os filhos da `ElixirQueue.Supervisor`:

```ex
    children = [
      {ElixirQueue.Queue, name: ElixirQueue.Queue},
      {DynamicSupervisor, name: ElixirQueue.WorkerSupervisor, strategy: :one_for_one},
      {ElixirQueue.WorkerPool, name: ElixirQueue.WorkerPool},
      {ElixirQueue.EventLoop, []}
    ]
```
Os filhos, de cima para baixo, representam as seguintes estruturas: `ElixirQueue.Queue` é o `GenServer` que guarda o estado da fila numa tupla; `ElixirQueue.WorkerSupervisor`é o `DynamicSupervisor` dos _workers_ adicionados dinamicamente sempre igual ou menor que o número de `schedulers` onlines; `ElixirQueue.WorkerPool`, o processo responsável por guardar os `pids` dos _workers_ e os _jobs_ executados, quer seja com sucesso ou falha; e por último o `ElixirQueue.EventLoop` que é a `Task` que "escuta" as mudanças na `ElixirQueue.Queue` (ou seja, na fila de processos) e retira _jobs_ para serem executados. O funcionamento específico de cada módulo eu explicarei conforme for me parecendo útil.

## Análise de comportamento assintótico

## Análise de desempenho
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

## Exemplos de uso

## Melhorias necessárias
