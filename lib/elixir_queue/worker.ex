defmodule ElixirQueue.Worker do
  require Logger
  alias ElixirQueue.Job

  @spec perform(ElixirQueue.Job.t()) :: any()
  def perform(job = %Job{mod: mod, func: func, args: args}) do
    try do
      out = apply(mod, func, args)

      unless Mix.env() == :test,
        do: Logger.info("JOB DONE SUCCESSFULLY #{inspect(job)} ====> RESULT: #{inspect(out)}")

      {:ok, out}
    rescue
      err ->
        unless Mix.env() == :test,
          do: Logger.info("JOB FAILED #{inspect(job)} ====> ERR: #{inspect(err)}")

        {:error, err}
    end
  end
end
