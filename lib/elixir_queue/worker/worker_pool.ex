defmodule ElixirQueue.Worker.WorkerPool do
  @spec perform(ElixirQueue.Job.t()) :: {:ok, any}
  def perform(job) do
    # TODO: find best worker to perform the job
    {:ok, job}
  end
end
