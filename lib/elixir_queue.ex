defmodule ElixirQueue do
  use Task, restart: :permanent
  require Logger

  alias ElixirQueue.{
    Queue,
    WorkerPool
  }

  @spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :event_loop, [])
  end

  @spec event_loop :: no_return
  def event_loop do
    :timer.sleep(100)

    case Queue.fetch() do
      {:ok, job} ->
        case Task.await(Task.async(fn -> WorkerPool.perform(job) end)) do
          {:ok, result} ->
            Logger.info("JOB DONE SUCCESSFULLY #{inspect(job)} ====> RESULT: #{inspect(result)}")
          {:error, err} ->
            Logger.info("JOB FAIL #{inspect(job)} ====> ERR: #{inspect(err)}")
        end

      {:error, :empty} ->
        event_loop()
    end

    event_loop()
  end
end
