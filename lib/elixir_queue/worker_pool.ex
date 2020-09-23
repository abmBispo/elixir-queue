defmodule ElixirQueue.WorkerPool do
  use GenServer
  alias ElixirQueue.{
    WorkerPool,
    Worker
  }
  # Server side functions
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, opts)
  end

  @impl true
  @spec init(any) :: {:ok, []}
  def init(_opts), do: {:ok, []}

  @impl true
  def handle_call({:add_worker, pid}, _from, workers) do
    {:reply, :ok, [pid | workers]}
  end

  @impl true
  def handle_call(:workers, _from, workers) do
    {:reply, workers, workers}
  end

  # Client side functions
  @spec add_worker(pid()) :: :ok
  def add_worker(pid), do: GenServer.call(__MODULE__, {:add_worker, pid})
  @spec workers :: list()
  def workers, do: GenServer.call(__MODULE__, :workers)

  @spec perform(ElixirQueue.Job.t()) :: {:ok, any}
  def perform(job) do
    WorkerPool.workers()
    |> Enum.find(&Worker.idle?(&1))
    |> Worker.perform(job)
  end
end
