defmodule ElixirQueue.Queue do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(_opts) do
    {:ok, {}}
  end

  @impl true
  def handle_call({:enqueue, job}, _from, queue) do
    {:reply, :ok, Tuple.append(queue, job)}
  end

  def handle_call(:dequeue, _from, {}), do: {:reply, {:ok, {}}, {}}

  def handle_call(:dequeue, _from, queue) do
    job = elem(queue, 0)
    {:reply, {:ok, job}, Tuple.delete_at(queue, 0)}
  end
end
