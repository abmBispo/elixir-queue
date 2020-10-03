defmodule ElixirQueue.Fake do
  alias ElixirQueue.{
    Queue,
    Fake,
    WorkerPool
  }

  def fake_raise(reason) do
    raise reason
  end

  @spec task(2 | 3) :: :sorted
  def task(2) do
    Enum.to_list(2_000_000..1)
    |> Enum.sort()
    :sorted
  end

  def task(3) do
    Enum.to_list(3_000_000..1)
    |> Enum.sort()
    :sorted
  end

  @spec populate :: :ok
  def populate do
    for _ <- 0..999, do: Queue.perform_later(Fake, :task, [3])
    :ok  
  end

  @spec spec :: %{
    String.t() => map(),
    String.t() => map(),
    String.t() => map(),
    String.t() => map()
  }
  def spec do
    %{
      "Successful jobs count" => Enum.frequencies_by(WorkerPool.successful_jobs(), fn x -> elem(x, 1) end),
      "Failed jobs count" => Enum.frequencies_by(WorkerPool.failed_jobs(), fn x -> elem(x, 1) end),
      "Successful jobs count by Worker PID" => Enum.frequencies_by(WorkerPool.successful_jobs(), fn x -> elem(x, 0) end),
      "Failed jobs count by Worker PID" => Enum.frequencies_by(WorkerPool.failed_jobs(), fn x -> elem(x, 0) end)
    }
  end
end
