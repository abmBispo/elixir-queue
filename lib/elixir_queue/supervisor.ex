defmodule ElixirQueue.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {DynamicSupervisor, name: ElixirQueue.WorkerSupervisor, strategy: :one_for_one},
      {ElixirQueue.Queue, name: ElixirQueue.Queue}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
