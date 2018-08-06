defmodule WithRetryBackOffTest do
  use ExUnit.Case, async: false
  use WithRetry

  setup do
    {:ok, agent} = Agent.start(fn -> 0 end)

    [agent: agent]
  end

  defp attempt(agent), do: Agent.get_and_update(agent, &{&1 + 1, &1 + 1})
  defp tries(agent), do: Agent.get(agent, & &1)

  test "retries till success", %{agent: agent} do
    result =
      with_retry 3 <- attempt(agent) do
        :success
      end

    assert result == :success
    assert tries(agent) == 3
  end

  # I might want to change this.
  test "retries whole if ", %{agent: agent} do
    result =
      with_retry x <- attempt(agent),
                 4 <- attempt(agent) do
        x
      end

    assert result == 3
    assert tries(agent) == 4
  end

  describe "back off tries the set amount of times" do
    test "false => only one try", %{agent: agent} do
      with_retry {:ok, x} <- attempt(agent),
                 back_off: false do
        x
      end

      assert tries(agent) == 1
    end

    test "[...] => length of list + initial", %{agent: agent} do
      with_retry {:ok, x} <- attempt(agent),
                 back_off: [1, 1] do
        x
      end

      assert tries(agent) == 3
    end

    test "Stream => length of stream + initial", %{agent: agent} do
      with_retry {:ok, x} <- attempt(agent),
                 back_off: max_retry(constant(1), 4) do
        x
      end

      assert tries(agent) == 5
    end
  end
end
