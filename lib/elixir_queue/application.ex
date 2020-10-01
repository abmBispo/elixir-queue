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
      {ElixirQueue.JobsPool, name: ElixirQueue.JobsPool},
      {ElixirQueue.EventLoop, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ElixirQueue.Supervisor)
  end
end
