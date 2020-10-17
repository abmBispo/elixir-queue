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

  test "Worker.perform/2 should return {worker, job, answer} tuple", %{worker: worker} do
    job = %Job{mod: Enum, func: :reverse, args: [[1,2,3,4,5]]}
    assert  {worker, job, [5,4,3,2,1]} == Worker.perform(worker, job)
  end

  test "Worker.perform/2 should raise RuntimeError", %{worker: worker} do
    job = %Job{mod: ElixirQueue.Fake, func: :fake_raise, args: ["oh noes"]}
    assert_raise RuntimeError, "oh noes", fn ->
      Worker.perform(worker, job)
    end
  end
end
