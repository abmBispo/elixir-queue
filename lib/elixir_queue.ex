defmodule ElixirQueue do
  use Application

  alias ElixirQueue.{
    Worker,
    WorkerSupervisor,
    Queue
  }

  @impl true
  def start(_type, _args) do
    supervisor_tuple = ElixirQueue.Supervisor.start_link(name: ElixirQueue.Supervisor)
    start_workers()
    supervisor_tuple
  end

  def start_workers do
    1..:erlang.system_info(:logical_processors_online)
    |> Enum.each(fn _ ->
      {:ok, pid} = DynamicSupervisor.start_child(WorkerSupervisor, Worker)
      Queue.add_worker(pid)
    end)
  end
end
