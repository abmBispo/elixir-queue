defmodule ElixirQueue.Fake do
  def fake_raise(reason) do
    raise reason
  end

  @spec task(2 | 3 | 5 | 7) :: 2 | 3 | 5 | 7
  def task(2) do
    :timer.sleep(200)
    2
  end

  def task(3) do
    :timer.sleep(300)
    3
  end
end
