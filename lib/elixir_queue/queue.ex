defmodule ElixirQueue.Queue do
  use GenServer
  alias __MODULE__
  alias ElixirQueue.Job

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, opts)
  end

  @impl true
  @spec init(any) :: {:ok, tuple()}
  def init(_opts), do: {:ok, {}}

  @doc ~S"""
  Enqueues job to be processed
  ## Examples
      iex> ElixirQueue.Queue.clear()
      iex> ElixirQueue.Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
      :ok
  """
  @spec perform_later(atom, atom, list(ElixirQueue.Job.t())) :: :ok
  def perform_later(mod, func, args \\ []) do
    job = %Job{mod: mod, func: func, args: args, retry_attempts: 0}
    GenServer.call(Queue, {:perform_later, job})
  end

  @doc ~S"""
  Enqueues job to be processed
  ## Examples
      iex> ElixirQueue.Queue.clear()
      iex> job = %ElixirQueue.Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}
      iex> ElixirQueue.Queue.perform_later(job)
      :ok
  """
  @spec perform_later(ElixirQueue.Job.t()) :: :ok
  def perform_later(job = %Job{}) do
    GenServer.call(Queue, {:perform_later, job})
  end

  @doc ~S"""
  Get next job to be processed
  ## Examples
      iex> ElixirQueue.Queue.clear()
      iex> ElixirQueue.Queue.fetch()
      {:error, :empty}
      iex> ElixirQueue.Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
      :ok
      iex> ElixirQueue.Queue.fetch()
      {:ok, %ElixirQueue.Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]], retry_attempts: 0}}
      iex> ElixirQueue.Queue.fetch()
      {:error, :empty}
  """
  @spec fetch :: {:ok, any} | {:error, :empty}
  def fetch, do: GenServer.call(Queue, :fetch)

  @spec clear :: :ok
  def clear, do: GenServer.call(Queue, :clear)

  @impl true
  def handle_call({:perform_later, job}, _from, queue),
    do: {:reply, :ok, Tuple.append(queue, job)}

  def handle_call(:fetch, _from, {}),
    do: {:reply, {:error, :empty}, {}}

  def handle_call(:fetch, _from, queue),
    do: {:reply, {:ok, elem(queue, 0)}, Tuple.delete_at(queue, 0)}

  def handle_call(:clear, _from, _queue),
    do: {:reply, :ok, {}}
end
