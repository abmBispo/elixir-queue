defmodule ElixirQueue do
  use Application

  @impl true
  def start(_type, _args) do
    ElixirQueue.Supervisor.start_link(name: ElixirQueue.Supervisor)
  end
end
