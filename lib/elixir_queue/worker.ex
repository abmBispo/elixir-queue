defmodule ElixirQueue.Worker do
  use GenServer, restart: :temporary
  require Logger

  alias ElixirQueue.Job

  @doc """
  Starts a new worker.
  """
  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  @spec init(any) :: {:ok, Job.t()}
  def init(_opts), do: {:ok, %Job{}}

  @impl true
  def handle_call({:start, job}, _from, _state),
    do: {:reply, :ok, job}

  def handle_call({:perform, %Job{mod: mod, func: func, args: args}}, _from, state),
    do: {:reply, apply(mod, func, args), state}

  def handle_call(:halt, _from, _state),
    do: {:reply, :ok, %Job{}}

  def handle_call(:idle?, _from, state),
    do: {:reply, state == %Job{}, state}

  @spec perform(pid(), Job.t()) :: any()
  def perform(worker, job) do
    GenServer.call(worker, {:start, job})
    result = GenServer.call(worker, {:perform, job})
    GenServer.call(worker, :halt)

    unless Mix.env() == :test,
      do: Logger.info("JOB DONE SUCCESSFULLY #{inspect(job)} ====> RESULT: #{inspect(result)}")

    {:ok, result}
  end

  @spec idle?(pid()) :: any
  def idle?(worker), do: GenServer.call(worker, :idle?)
end
