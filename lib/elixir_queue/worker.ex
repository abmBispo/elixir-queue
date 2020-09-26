defmodule ElixirQueue.Worker do
  use Agent
  require Logger
  alias ElixirQueue.Job

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  @doc """
  Starts a new worker.
  """
  def start_link(_opts) do
    Agent.start_link(fn -> %Job{} end)
  end

  @spec get(pid()) :: Job.t()
  def get(worker), do: Agent.get(worker, fn state -> state end)

  @spec idle?(pid()) :: boolean
  def idle?(worker), do: Agent.get(worker, fn state -> state end) == %Job{}

  @spec perform(pid(), ElixirQueue.Job.t()) :: any()
  def perform(worker, job = %Job{mod: mod, func: func, args: args}) do
    Logger.info(">>> Worker: #{inspect(worker)}")
    Agent.update(worker, fn _ -> job end)

    result = try do
      {:ok, apply(mod, func, args), worker}
    rescue
      err -> {:error, err}
    after
      Agent.update(worker, fn _ -> %Job{} end)
    end

    result
  end
end
