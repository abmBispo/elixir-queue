defmodule ElixirQueue.WorkerPool do
  require Logger
  use GenServer

  alias ElixirQueue.{
    WorkerSupervisor,
    WorkerPool,
    Worker,
    Queue
  }

  # Server side functions
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, opts)
  end

  @impl true
  @spec init(any) :: {:ok, %{failed_jobs: [], pids: [], successful_jobs: []}}
  def init(_opts) do
    pids =
      for _ <- 1..System.schedulers_online() do
        {:ok, pid} = DynamicSupervisor.start_child(WorkerSupervisor, Worker)
        Process.monitor(pid)
        pid
      end

    :ets.new(:worker_backup, [:set, :protected, :named_table])

    {:ok, %{pids: pids, successful_jobs: [], failed_jobs: []}}
  end

  @impl true
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
    {:reply, :ok,
     Map.put(state, :successful_jobs, [{worker, job, result} | state.successful_jobs])}
  end

  def handle_call({:add_failed_job, worker, job, err}, _from, state) do
    {:reply, :ok, Map.put(state, :failed_jobs, [{worker, job, err} | state.failed_jobs])}
  end

  def handle_call({:backup_worker, worker, job}, _from, state) do
    :ets.insert(:worker_backup, {worker, job})
    {:reply, :ok, state}
  end

  def handle_call({:clean_worker_backup, worker}, _from, state) do
    :ets.delete(:worker_backup, worker)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, _, :process, dead_worker, reason}, state) do
    {:ok, pid} = DynamicSupervisor.start_child(WorkerSupervisor, Worker)
    Process.monitor(pid)
    pids = Enum.filter(state.pids, &(&1 != dead_worker))

    {^dead_worker, backuped_job} =
      :ets.lookup(:worker_backup, dead_worker)
      |> List.first()

    backuped_job = Map.put(backuped_job, :retry_attempts, backuped_job.retry_attempts + 1)

    state =
      state
      |> Map.put(:pids, [pid | pids])
      |> Map.put(:failed_jobs, [{dead_worker, backuped_job, reason} | state.failed_jobs])

    if backuped_job.retry_attempts < Application.fetch_env!(:elixir_queue, :retries),
      do: Queue.perform_later(backuped_job)

    {:noreply, state}
  end

  # Client side functions
  @spec workers :: list()
  def workers, do: GenServer.call(__MODULE__, :workers)

  @spec failed_jobs :: list()
  def failed_jobs, do: GenServer.call(__MODULE__, :failed_jobs)

  @spec successful_jobs :: list()
  def successful_jobs, do: GenServer.call(__MODULE__, :successful_jobs)

  @spec add_successful_job({pid(), ElixirQueue.Job.t(), any}) :: :ok
  def add_successful_job({worker, job, result}),
    do: GenServer.call(__MODULE__, {:add_successful_job, worker, job, result})

  @spec backup_worker(pid(), ElixirQueue.Job.t()) :: true
  def backup_worker(worker, job),
    do: GenServer.call(__MODULE__, {:backup_worker, worker, job})

  @spec clean_worker_backup(pid()) :: true
  def clean_worker_backup(worker),
    do: GenServer.call(__MODULE__, {:clean_worker_backup, worker})

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
      Worker.perform(worker, job)
      |> WorkerPool.add_successful_job()
    end)
  end
end
