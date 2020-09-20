defmodule ElixirQueue.Queue do
  use GenServer
  alias __MODULE__

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, {}}
  end

  @doc ~S"""
  Get next job to be processed
  ## Examples
      iex> ElixirQueue.Queue.enqueue(%{foo: "bar"})
      :ok
  """
  @spec enqueue(any) :: :ok
  def enqueue(job), do: GenServer.call(Queue, {:enqueue, job})

  @doc ~S"""
  Get next job to be processed
  ## Examples
      iex> ElixirQueue.Queue.dequeue()
      {:error, :nojob}
      iex> ElixirQueue.Queue.enqueue(%{foo: "bar"})
      :ok
      iex> ElixirQueue.Queue.dequeue()
      {:ok, %{foo: "bar"}}
      iex> ElixirQueue.Queue.dequeue()
      {:error, :nojob}
  """
  @spec dequeue :: {:ok, any} | {:error, :nojob}
  def dequeue, do: GenServer.call(Queue, :dequeue)

  @impl true
  def handle_call({:enqueue, job}, _from, queue) do
    {:reply, :ok, Tuple.append(queue, job)}
  end

  def handle_call(:dequeue, _from, {}), do: {:reply, {:error, :nojob}, {}}

  def handle_call(:dequeue, _from, queue) do
    job = elem(queue, 0)
    {:reply, {:ok, job}, Tuple.delete_at(queue, 0)}
  end
end
