defmodule ElixirQueue.Worker do
  use Agent
  alias ElixirQueue.Job

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  @doc """
  Starts a new worker.
  """
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end)
  end

  @spec perform(ElixirQueue.Job.t()) :: :ok
  def perform(%Job{mod: mod, func: func, args: args}) do
    apply(mod, func, args)
    :ok
  end
end
