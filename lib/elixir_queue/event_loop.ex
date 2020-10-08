defmodule ElixirQueue.EventLoop do
  use Task, restart: :transient

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

    :timer.sleep(1)
    case Queue.fetch() do
      {:ok, job} -> WorkerPool.perform(job)
      {:error, :empty} -> event_loop()
    end

    event_loop()
  end
end
