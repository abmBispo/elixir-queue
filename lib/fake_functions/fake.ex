defmodule ElixirQueue.Fake do
  alias ElixirQueue.{
    Queue,
    Fake,
    JobsPool
  }

  def fake_raise(reason) do
    raise reason
  end

  @spec task(2 | 3) :: :sorted
  def task(2) do
    Enum.to_list(1_000_000..1)
    |> Enum.sort()
    :sorted
  end

  def task(3) do
    Enum.to_list(2_000_000..1)
    |> Enum.sort()
    :sorted
  end

  @spec populate :: :ok
  def populate do
    for i <- 0..2000 do
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
    String.t() => map()
  }
  def spec do
    %{
      "Successful jobs count" => Enum.frequencies_by(JobsPool.successful_jobs(), fn x -> elem(x, 1) end),
      "Failed jobs count" => Enum.frequencies_by(JobsPool.failed_jobs(), fn x -> elem(x, 1) end)
    }
  end
end
