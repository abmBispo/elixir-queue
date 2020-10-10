defmodule ElixirQueue.Worker do
  use Agent, restart: :temporary
  require Logger

  alias ElixirQueue.{
    Job,
    WorkerPool
  }

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
    start_job(worker, job)
    result = apply(mod, func, args)
    end_job(worker)

    unless Mix.env() == :test,
      do: Logger.info("JOB DONE SUCCESSFULLY #{inspect(job)} ====> RESULT: #{inspect(result)}")

    {worker, job, result}
  end

  defp start_job(worker, job) do
    Agent.update(worker, fn _ -> job end)
    WorkerPool.backup_worker(worker, job)
  end

  defp end_job(worker) do
    WorkerPool.clean_worker_backup(worker)
    Agent.update(worker, fn _ -> %Job{} end)
  end
end
