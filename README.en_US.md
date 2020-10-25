# ElixirQueue

## 🤔 Why?
The main reason why I decided to develop this process queue was the learning of Erlang/OTP structures and APIs using Elixir. There are probably many other processing queue in-background services that are far more efficient than the one written here.

However, I believe that it is interesting for beginners to just have access to simpler structures, both from a programming logic and OTP operational perspective. That's why I chose to make a this software from the get-go in order to be able to explain the decision making and, eventually, improve it as the community shows that one or another option is better, through _pull requests_ or _issues_ in this repository. I am sure that what is dealt with here will be of great help for everyone learning, or seeking to improve his/her skills in Elixir, including me.

## 📘 Architecture
### Application diagram
The picture below shows a complete diagram of the data flow and possible system events.

![Diagrama de fluxo de aplicação](https://raw.githubusercontent.com/abmBispo/elixir-queue/master/ElixirQueue.png)

### ElixirQueue.Application
The `Application` of this process queue supervises the processes that will create/consume the queue. Here are the children of `ElixirQueue.Supervisor`:

```ex
children = [
  {ElixirQueue.Queue, name: ElixirQueue.Queue},
  {DynamicSupervisor, name: ElixirQueue.WorkerSupervisor, strategy: :one_for_one},
  {ElixirQueue.WorkerPool, name: ElixirQueue.WorkerPool},
  {ElixirQueue.EventLoop, []}
]
```

The children, from top to bottom, represent the following structures:
- `ElixirQueue.Queue` is the `GenServer` that stores the queue state in a tuple.
- `ElixirQueue.WorkerSupervisor` is the `DynamicSupervisor` of the dynamically added _workers_ always equal to or less than the number of online `schedulers`.
- `ElixirQueue.WorkerPool` is the process responsible for saving the `pids` of the executed _workers_ and _jobs_, whether successful or failed.
- `ElixirQueue.EventLoop`, which is the `Task` that "listens" to the changes in the `ElixirQueue.Queue` (i.e., in the process queue) and removes _jobs_ to be executed.

The specific functioning of each module I will explain as it seems useful to me.

### ElixirQueue.EventLoop

Here is the process that controls the removal of elements from the queue. A _event loop_ by default is a function that executes in an iteration/recession _pseuedo-infinitetely_, since there is no intention to break the _loop_. With each cycle the _loop_ looks for _jobs_ added to the queue - that is, in a way `ElixirQueue.EventLoop` "listens" for changes that have occurred in the queue and reacts from these events - it directs them to `ElixirQueue.WorkerPool` to be executed.

This module assumes the _behavior_ of `Task` and its only function (`event_loop/0`) does not return any value since it is an eternal _loop_: it searches the queue for some element and can receive either:
- a tuple `{:ok, job}` with the task to be performed. In this case, it sends to the `ElixirQueue.WorkerPool` the task and executes `event_loop/0` again.
- a tuple `{:error, :empty}` in case the queue is empty. In the second case it just executes the function itself recursively, continuing the loop until it finds some relevant event (element insertion in the queue).

### ElixirQueue.Queue
The `ElixirQueue.Queue` module holds the heart of the system. Here the _jobs_ are queued up to be consumed later by the _workers_. It is a `GenServer` under the supervision of `ElixirQueue.Application`, which stores a tuple as a state and in that tuple the jobs are stored - to understand why I preferred a tuple rather than a chained list (`List`), I explained this decision in the section **Performance Analysis** further below.

The `Queue` is a very simple structure, with trivial functions that basically clean, look for the first element of the queue to be executed and insert an element at the end of the queue, so that it can be executed later, as inserted.

### ElixirQueue.WorkerPool

Here is the module capable of communicating with both the queue and the _workers_. When the _Application_ is started and the processes are supervised, one of the events that occurs is precisely the initiation of the _workers_ under the supervision of the `ElixirQueue.WorkerSupervisor`, the `DynamicSupervisor`, and their respective _PIDs_ are added to the `ElixirQueue.WorkerPool` state. In addition, each worker started within the scope of the `WorkerPool` is also supervised by this, the reason for this will be addressed later.

When `WorkerPool` receives the request to execute a _job_ it looks for any of its _workers PIDs_ that are in the idle state, that is, without any jobs being executed at the moment. Then, for each _job_ received by the `WorkerPool` through its `perform/1`, it links the _job_ to a _worker PID_, which goes to the busy state. When the worker finishes the execution, it clears its state and then transitions itself to idle, waiting for another _job_.

In this case, what we call a _worker_ is nothing more than a `Agent` which stores in its state which job is being executed linked to that PID; it serves as a limiting ballast since the `WorkerPool` starts a new `Task` for each _job_. Imagine the scenario where we didn't have _workers_ to limit the amount of jobs being executed concurrently: our `EventLoop` would start `Task`s at its whim, and could cause some trouble, e.g. memory overflow if `Queue` received a big load of _jobs_ at once.

### ElixirQueue.Worker
In this module we have the actors responsible for taking the _jobs_ and executing them. But the process is a little more than just executing the job; it actually works as follows:
1. The `Worker` receives a request to perform a certain _job_, adds it to its internal state (internal state of the past PID agent) and also to a backup `:ets` table.
1. Then it goes to the execution of the _job_ itself. It is **indispensable to remember** that the execution occurs in the scope of the `Task` invoked by the `WorkerPool`, and not in the scope of the Agent's process. It is an implementation detail I chose because of its simplicity, but it can be done in other ways.
1. Finally, with the _job_ finished, the `Worker` returns its internal state to idle and excludes the backup of this worker from the `:ets` table.
1. With the `Worker` function having been fulfilled, the execution track goes back to the `Task` invoked by the `WorkerPool` and completes the race by inserting the _job_ in the list of successful _jobs_.

#### What happens if a `Worker` dies? Asked differently, why do we need an `WorkerPool` supervisioning `Worker`s?

As you might have noticed, there is no point in the _jobs_ execution trail where we worry about the question: what happens if a badly done function is passed as a _job_ to the execution queue, _or even!_, what happens if some `Agent` `Worker` process simply corrupts the memory and dies?

In order to write the code as robust as possible, and as idiomatic as possible too, what has been done is precisely to add guarantees that if the processes fail (and it will fail!) the system can react in such a way as to mitigate the errors.

When a worker fails to die via the _EXIT signal_, the `WorkerPool` (which monitors all their workers via the `Process.monitor`) replaces this dead worker with another, adding it to the `WorkerSupervisor`. This also removes the `PID` from the dead `Worker` list and adds the new one. But it doesn't stop there: the `WorkerPool` checks for some backup created from the dead `Worker` and, finding it, replaces the _job_ in the queue with its value of _attempt_retry_ plus one. The `WorkerPool` will always add the _job_ back to the queue a predetermined number of times, defined in the `mix.exs` file in the _environment_ of _application_. 

## 🏃 Performance Analysis
### Why `Tuple` instead of `List`?
For the process queue to work normally, I just need to insert at the end and remove from the head. Clearly this can be done with both `List` and `Tuple`, and I opted for tuple simply because it is faster. Result from Benchee's _output_ running `mix run benchmark.exs` at the root of the project:

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

### Stress test
I prepared a stress test for the application that queues 1000 _fake jobs_, each one sorting a `List` in reverse order with 3 million elements, using `Enum.sort/1` (according to the documentation, the algorithm is a _merge sort_). To execute it just enter the terminal via `iex -S mix` and run `ElixirQueue.Fake.populate`; the execution takes a few minutes (and at least 2gb of RAM), and then you can check the results with `ElixirQueue.Fake.spec`.

## 💼 Usecases
To see the process queue working just execute `iex -S mix` at the project root and use the commands below. Unless you are in `test` mode, you will see _logs_ about the execution of the _job_.

### ElixirQueue.Queue.perform_later/1
You can build the _struct_ of the _job_ by hand and pass it to the queue.
```ex
iex> job = %ElixirQueue.Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}
iex> ElixirQueue.Queue.perform_later(job)
:ok
```

### ElixirQueue.Queue.perform_later/3
We can also manually pass the module values, function and arguments to `perform_later/3`.
```ex
iex> ElixirQueue.Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
:ok
```
