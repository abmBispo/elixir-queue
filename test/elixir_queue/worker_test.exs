defmodule ElixirQueue.WorkerTest do
  use ExUnit.Case
  alias ElixirQueue.{
    Worker,
    Job
  }

  setup do
    %{worker: start_supervised!(Worker)}
  end

  test "Worker.get/1 should return valid state", %{worker: worker} do
    assert %Job{} == Worker.get(worker)
  end

  test "Worker.idle?/1 should return true", %{worker: worker} do
    assert Worker.idle?(worker)
  end

  test "Worker.perform/2 should return {:ok, out, worker_pid} tuple", %{worker: worker} do
    job = %Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}
    assert  {:ok, [5, 4, 3, 2, 1], worker} == Worker.perform(worker, job)
  end

  test "Worker.perform/2 should return {:error, err, worker} tuple", %{worker: worker} do
    job = %Job{mod: ElixirQueue.Fake, func: :fake_raise, args: ["oh noes"]}
    assert {:error, err, worker} = Worker.perform(worker, job)
    assert err.message == "oh noes"
  end
end
