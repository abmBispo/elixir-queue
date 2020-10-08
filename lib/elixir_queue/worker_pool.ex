defmodule ElixirQueue.WorkerPool do
  require Logger
  use GenServer

  alias ElixirQueue.{
    WorkerSupervisor,
    WorkerPool,
    Worker
  }

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, opts)
  end

  @impl true
  @spec init(any) :: {:ok, %{failed_jobs: [], pids: [], successful_jobs: []}}
  def init(_opts) do
    pids =
      for _ <- 1..Application.fetch_env!(:elixir_queue, :workers) do
        {:ok, pid} = DynamicSupervisor.start_child(WorkerSupervisor, Worker)
        ref = Process.monitor(pid)
        {pid, ref}
      end

    :ets.new(:workers_backup, [:set, :protected, :named_table])

    {:ok, %{pids: pids, successful_jobs: [], failed_jobs: []}}
  end

  # Server side functions
  @impl true
  def handle_cast({:perform, job}, state) do
    worker = WorkerPool.idle_worker()
    :ets.insert(:workers_backup, {worker, job})
    {:ok, result} = Worker.perform(worker, job)

    {:noreply, Map.put(state, :successful_jobs, [{worker, job, result} | state.successful_jobs])}
  end

  @impl true
  def handle_call(:workers, _from, state), do: {:reply, Enum.map(state.pids, &elem(&1, 0)), state}

  def handle_call(:failed_jobs, _from, state), do: {:reply, state.failed_jobs, state}

  def handle_call(:successful_jobs, _from, state), do: {:reply, state.successful_jobs, state}

  def handle_call({:add_successful_job, worker, job, result}, _from, state),
    do: {
      :reply,
      :ok,
      Map.put(state, :successful_jobs, [{worker, job, result} | state.successful_jobs])
    }

  def handle_call({:add_failed_job, worker, job, err}, _from, state),
    do: {:reply, :ok, Map.put(state, :failed_jobs, [{worker, job, err} | state.failed_jobs])}

  @impl true
  def handle_info({:DOWN, _ref, :process, dead_worker, reason}, state) do
    {:ok, worker} = DynamicSupervisor.start_child(WorkerSupervisor, Worker)
    worker_reference = Process.monitor(worker)
    pids = Enum.filter(state.pids, &(&1 != dead_worker))
    [{_, job}] = :ets.lookup(:workers_backup, dead_worker)

    state =
      state
      |> Map.put(:pids, [{worker, worker_reference} | pids])
      |> Map.put(:failed_jobs, [{dead_worker, job, reason} | state.failed_jobs])

    {:noreply, state}
  end

  def handle_info(_msg, state),
    do: {:noreply, state}

  # Client side functions #

  @doc """
  Returns _workers_ `PID`s kept in the state.
  """
  @spec workers :: list()
  def workers, do: GenServer.call(__MODULE__, :workers)

  @doc """
  Returns _workers_ `PID`s kept in the state.
  """
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

  @spec backup_worker(pid(), ElixirQueue.Job.t()) :: :ok
  def backup_worker(worker, job),
    do: GenServer.call(__MODULE__, {:backup_worker, worker, job})

  @spec idle_worker :: pid()
  def idle_worker do
    case Enum.find(WorkerPool.workers(), fn worker -> Worker.idle?(worker) end) do
      worker when is_pid(worker) -> worker
      _ -> WorkerPool.idle_worker()
    end
  end

  @spec perform(ElixirQueue.Job.t()) :: :ok
  def perform(job), do: GenServer.cast(__MODULE__, {:perform, job})
end
