defmodule ElixirQueue.Queue do
  use GenServer
  alias __MODULE__
  alias ElixirQueue.Job

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, opts)
  end

  @impl true
  @spec init(any) :: {:ok, %{jobs: tuple(), workers_pids: list()}}
  def init(_opts), do: {:ok, %{jobs: {}, workers_pids: []}}

  @doc ~S"""
  Get next job to be processed
  ## Examples
      iex> ElixirQueue.Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
      :ok
  """
  @spec perform_later(atom, atom, list(any)) :: :ok
  def perform_later(mod, func, args \\ []) do
    job = %Job{mod: mod, func: func, args: args}
    GenServer.call(Queue, {:perform_later, job})
  end

  @doc ~S"""
  Get next job to be processed
  ## Examples
      iex> ElixirQueue.Queue.fetch()
      {:error, :empty}
      iex> ElixirQueue.Queue.perform_later(Enum, :reverse, [[1,2,3,4,5]])
      :ok
      iex> ElixirQueue.Queue.fetch()
      {:ok, %ElixirQueue.Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}}
      iex> ElixirQueue.Queue.fetch()
      {:error, :empty}
  """
  @spec fetch :: {:ok, any} | {:error, :empty}
  def fetch, do: GenServer.call(Queue, :fetch)

  @spec add_worker(pid()) :: :ok
  def add_worker(pid) do
    GenServer.call(Queue, {:add_worker, pid})
    :ok
  end

  @impl true
  def handle_call({:perform_later, job}, _from, queue) do
    {:reply, :ok, Tuple.append(queue, job)}
  end

  def handle_call(:fetch, _from, %{jobs: {}, workers_pids: workers_pids}) do
    {:reply, {:error, :empty}, %{jobs: {}, workers_pids: workers_pids}}
  end

  def handle_call(:fetch, _from, state = %{jobs: queue}) do
    job = elem(queue, 0)
    {:reply, {:ok, job}, Map.put(state, :jobs, Tuple.delete_at(queue, 0))}
  end

  def handle_call({:add_worker, pid}, _from, state = %{workers_pids: workers_pids}) do
    {:reply, :ok, Map.put(state, :workers_pids, [pid | workers_pids])}
  end
end
