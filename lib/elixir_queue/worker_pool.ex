defmodule ElixirQueue.WorkerPool do
  require Logger
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

  @spec idle_worker :: pid()
  def idle_worker do
    case Enum.find(WorkerPool.workers, &Worker.idle?(&1)) do
      pid when is_pid(pid) -> pid
      _ -> WorkerPool.idle_worker()
    end
  end

  @spec perform(ElixirQueue.Job.t()) :: no_return()
  def perform(job) do
    finished_with =
      WorkerPool.idle_worker()
      |> Worker.perform(job)

    case finished_with do
      {:ok, result, worker} ->
        Logger.info(
          "JOB DONE SUCCESSFULLY #{inspect(job)} ====> RESULT: #{inspect(result)}\n
          Responsible worker: [#{inspect(worker)}]")

      {:error, err} ->
        Logger.info("JOB FAILED #{inspect(job)} ====> ERR: #{inspect(err)}")
    end
  end
end
