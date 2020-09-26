defmodule ElixirQueue do
  use Task, restart: :permanent

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
    case Queue.fetch() do
      {:ok, job} ->
        Task.start(fn -> WorkerPool.perform(job) end)
      {:error, :empty} ->
        event_loop()
    end

    event_loop()
  end
end
