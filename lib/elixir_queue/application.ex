defmodule ElixirQueue.Application do
  use Application
  alias ElixirQueue.{
    WorkerSupervisor,
    WorkerPool,
    Worker
  }

  @impl true
  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    children = [
      {ElixirQueue.Queue, name: ElixirQueue.Queue},
      {DynamicSupervisor, name: ElixirQueue.WorkerSupervisor, strategy: :one_for_one},
      {ElixirQueue.WorkerPool, name: ElixirQueue.WorkerPool},
      {ElixirQueue, []}
    ]

    tuple = Supervisor.start_link(children, strategy: :one_for_all, name: ElixirQueue.Supervisor)
    start_workers()
    tuple
  end

  @spec start_workers :: :ok
  def start_workers do
    1..:erlang.system_info(:logical_processors_online)
    |> Enum.each(fn _ ->
      {:ok, pid} = DynamicSupervisor.start_child(WorkerSupervisor, Worker)
      WorkerPool.add_worker(pid)
    end)
    :ok
  end
end
