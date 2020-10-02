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
  @spec init(any) :: {:ok, %{failed_jobs: [], pids: [], successful_jobs: []}}
  def init(_opts), do: {:ok, %{pids: [], successful_jobs: [], failed_jobs: []}}

  @impl true
  def handle_call({:add_worker, pid}, _from, state = %{pids: workers}) do
    {:reply, :ok, Map.put(state, :pids, [pid | workers])}
  end

  def handle_call(:workers, _from, state) do
    {:reply, state.pids, state}
  end

  def handle_call(:failed_jobs, _from, state) do
    {:reply, state.failed_jobs, state}
  end

  def handle_call(:successful_jobs, _from, state) do
    {:reply, state.successful_jobs, state}
  end

  def handle_call({:add_successful_job, worker, job, result}, _from, state) do
    {:reply, :ok, Map.put(state, :successful_jobs, [{worker, job, result} | state.successful_jobs])}
  end

  def handle_call({:add_failed_job, worker, job, err}, _from, state) do
    {:reply, :ok, Map.put(state, :failed_jobs, [{worker, job, err} | state.failed_jobs])}
  end

  # Client side functions
  @spec add_worker(pid()) :: :ok
  def add_worker(pid), do: GenServer.call(__MODULE__, {:add_worker, pid})

  @spec workers :: list()
  def workers, do: GenServer.call(__MODULE__, :workers)

  @spec failed_jobs :: list()
  def failed_jobs, do: GenServer.call(__MODULE__, :failed_jobs)

  @spec successful_jobs :: list()
  def successful_jobs, do: GenServer.call(__MODULE__, :successful_jobs)

  @spec add_successful_job(pid(), ElixirQueue.Job.t(), any) :: :ok
  def add_successful_job(worker, job, result),
    do: GenServer.call(__MODULE__, {:add_successful_job, worker, job, result})

  @spec add_failed_job(pid(), ElixirQueue.Job.t(), any) :: :ok
  def add_failed_job(worker, job, err),
    do: GenServer.call(__MODULE__, {:add_failed_job, worker, job, err})

  @spec idle_worker :: pid()
  def idle_worker do
    case Enum.find(WorkerPool.workers(), &Worker.idle?(&1)) do
      pid when is_pid(pid) -> pid
      _ -> WorkerPool.idle_worker()
    end
  end

  @spec perform(ElixirQueue.Job.t()) :: no_return()
  def perform(job) do
    worker = WorkerPool.idle_worker()
    Task.start(fn ->
      case Worker.perform(worker, job) do
        {:ok, result, worker} ->
          WorkerPool.add_successful_job(worker, job, result)

        {:error, err, worker} ->
          WorkerPool.add_failed_job(worker, job, err)
      end
    end)
  end
end
