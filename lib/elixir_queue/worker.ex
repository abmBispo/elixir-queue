defmodule ElixirQueue.Worker do
  use Agent
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

  def get(worker, field) do
    Agent.get(worker, fn state -> Map.get(state, field) end)
  end

  @spec perform(pid(), ElixirQueue.Job.t()) :: :ok
  def perform(worker, job = %Job{mod: mod, func: func, args: args}) do
    Agent.update(worker, &(Map.put(&1, :current_job, job)))

    apply(mod, func, args)

    jobs = Worker.get(worker, :jobs)
    Agent.update(worker, &(Map.put(&1, :current_job, %Job{})))
    Agent.update(worker, &(Map.put(&1, :jobs, [job | jobs])))

    :ok
  end
end
