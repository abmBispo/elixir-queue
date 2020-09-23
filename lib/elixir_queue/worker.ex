defmodule ElixirQueue.Worker do
  use Agent
  require Logger

  alias ElixirQueue.{
    Job,
    Worker
  }

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  @doc """
  Starts a new worker.
  """
  def start_link(_opts) do
    Agent.start_link(fn -> %{current_job: %Job{}, jobs: []} end)
  end

  @spec get(pid(), atom()) :: (Job.t() | %{} | list(Job.t()) | [])
  def get(worker, field), do:
    Agent.get(worker, fn state -> Map.get(state, field) end)

  @spec idle?(pid()) :: boolean
  def idle?(worker), do:
    Agent.get(worker, fn state -> state.current_job end) == %Job{}

  @spec perform(pid(), ElixirQueue.Job.t()) :: any()
  def perform(worker, job = %Job{mod: mod, func: func, args: args}) do
    Logger.info("worker: #{inspect(worker)}")
    Logger.info("job: #{inspect(job)}")
    Agent.update(worker, &Map.put(&1, :current_job, job))
    Logger.info("Passed ONE")
    result = apply(mod, func, args)
    Logger.info("Passed TWO")
    jobs = Worker.get(worker, :jobs)
    Agent.update(worker, &Map.put(&1, :current_job, %Job{}))
    Agent.update(worker, &Map.put(&1, :jobs, [job | jobs]))
    {:ok, result}
  end
end
