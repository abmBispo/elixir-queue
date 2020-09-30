defmodule ElixirQueue.Fake do
  alias ElixirQueue.{
    Queue,
    Fake,
    WorkerPool
  }

  def fake_raise(reason) do
    raise reason
  end

  def task(2) do
    Task.async(fn -> :timer.sleep(2000) end)
    |> Task.await()
    2
  end

  def task(3) do
    Task.async(fn -> :timer.sleep(3000) end)
    |> Task.await()
    3
  end

  @spec populate :: :ok
  def populate do
    for i <- 0..10_000 do
      case rem(i, 3) do
        0 -> Queue.perform_later(Fake, :fake_raise, ["No reason"])
        1 -> Queue.perform_later(Fake, :task, [2])
        2 -> Queue.perform_later(Fake, :task, [3])
      end
    end
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
