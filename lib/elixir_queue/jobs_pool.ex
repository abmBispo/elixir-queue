defmodule ElixirQueue.JobsPool do
  require Logger
  use GenServer

  alias ElixirQueue.{
    JobsPool,
    Worker
  }

  # Server side functions
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, name, opts)
  end

  @impl true
  @spec init(any) :: {:ok, %{failed_jobs: [], successful_jobs: []}}
  def init(_opts), do: {:ok, %{failed_jobs: [], successful_jobs: []}}

  @impl true
  def handle_call(:failed_jobs, _from, state), do: {:reply, state.failed_jobs, state}

  def handle_call(:successful_jobs, _from, state), do: {:reply, state.successful_jobs, state}

  def handle_call({:add_successful_job, job, result}, _from, state),
    do: {:reply, :ok, Map.put(state, :successful_jobs, [{job, result} | state.successful_jobs])}

  def handle_call({:add_failed_job, job, err}, _from, state),
    do: {:reply, :ok, Map.put(state, :failed_jobs, [{job, err} | state.failed_jobs])}

  # Client side functions
  @spec failed_jobs :: list()
  def failed_jobs,
    do: GenServer.call(__MODULE__, :failed_jobs)

  @spec successful_jobs :: list()
  def successful_jobs,
    do: GenServer.call(__MODULE__, :successful_jobs)

  @spec add_successful_job(ElixirQueue.Job.t(), any) :: :ok
  def add_successful_job(job, result),
    do: GenServer.call(__MODULE__, {:add_successful_job, job, result})

  @spec add_failed_job(ElixirQueue.Job.t(), any) :: :ok
  def add_failed_job(job, err),
    do: GenServer.call(__MODULE__, {:add_failed_job, job, err})

  @spec perform(ElixirQueue.Job.t()) :: no_return()
  def perform(job) do
    Task.start(fn ->
      case Worker.perform(job) do
        {:ok, result} ->
          JobsPool.add_successful_job(job, result)

        {:error, err} ->
          JobsPool.add_failed_job(job, err)
      end
    end)
  end
end
