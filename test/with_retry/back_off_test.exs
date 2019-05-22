defmodule WithRetry.BackOffTest do
  use ExUnit.Case, async: true
  use WithRetry

  describe "constant/1" do
    test "returns 1_000 endlessly (default)" do
      check = Enum.random(1..100)

      assert Enum.take(constant(), check) == Enum.map(0..(check - 1), fn _ -> 1_000 end)
    end

    test "returns give endlessly" do
      given = Enum.random(1..100)
      check = Enum.random(1..100)

      assert Enum.take(constant(given), check) == Enum.map(0..(check - 1), fn _ -> given end)
    end
  end

  describe "linear/2" do
    test "returns u(n) = u(n-1) + 1_000 (u(0) = 1_000) endlessly (default)" do
      check = Enum.random(1..100)

      assert Enum.take(linear(), check) == Enum.map(1..check, fn x -> x * 1_000 end)
    end

    test "returns u(n) = u(n-1) + 1_000 (n(0) = given) endlessly" do
      given = Enum.random(1..100)
      check = Enum.random(1..100)

      assert Enum.take(linear(given), check) ==
               Enum.map(0..(check - 1), fn x -> given + x * 1_000 end)
    end

    test "returns u(n) = u(n-1) + increase (n(0) = given) endlessly" do
      given = Enum.random(1..100)
      increase = Enum.random(1..100)
      check = Enum.random(1..100)

      assert Enum.take(linear(given, increase), check) ==
               Enum.map(0..(check - 1), fn x -> given + x * increase end)
    end
  end

  describe "exponential/2" do
    test "returns u(n) = u(n-1) * 2 (u(0) = 1_000) endlessly (default)" do
      check = Enum.random(1..100)

      assert Enum.take(exponential(), check) ==
               Enum.map(0..(check - 1), fn x -> 1_000 * :math.pow(2, x) end)
    end

    test "returns u(n) = u(n-1) * 2 (n(0) = given) endlessly" do
      given = Enum.random(1..100)
      check = Enum.random(1..100)

      assert Enum.take(exponential(given), check) ==
               Enum.map(0..(check - 1), fn x -> round(given * :math.pow(2, x)) end)
    end

    test "returns u(n) = u(n-1) * factor (n(0) = given) endlessly" do
      given = Enum.random(1..10)
      factor = Enum.random(2..3)
      check = Enum.random(1..20)

      assert Enum.take(exponential(given, factor), check) ==
               Enum.map(0..(check - 1), fn x -> round(given * :math.pow(factor, x)) end)
    end
  end

  describe "cap/2" do
    test "caps wait to given value" do
      check = Enum.random(1..50)
      cap = Enum.random(0..999)

      assert Enum.take(cap(constant(), cap), check) == Enum.map(1..check, fn _ -> cap end)
    end
  end

  describe "max_try/2" do
    test "returns constant with one less then given" do
      check = Enum.random(2..10)

      assert Enum.to_list(max_try(0)) == []
      assert Enum.to_list(max_try(check)) == Enum.map(0..(check - 2), fn _ -> 1_000 end)
    end

    test "limits given back off" do
      check = Enum.random(2..10)

      assert Enum.to_list(max_try(linear(1, 1), 0)) == []
      assert Enum.to_list(max_try(linear(1, 1), check)) == Enum.to_list(1..(check - 1))
    end
  end

  describe "max_retry/2" do
    test "returns constant with give attempts" do
      check = Enum.random(1..10)

      assert Enum.to_list(max_retry(check)) == Enum.map(1..check, fn _ -> 1_000 end)
    end

    test "limits given back off" do
      check = Enum.random(1..10)

      assert Enum.to_list(max_retry(linear(1, 1), check)) == Enum.to_list(1..check)
    end
  end

  describe "limit/2" do
    test "returns timeouts until time runs out" do
      back_off = limit(1_000)
      assert Enum.take(back_off, 1) == [1_000]

      :timer.sleep(1_000)
      assert Enum.take(back_off, 1) == []
    end

    test "limits given back off" do
      back_off = limit(linear(1, 1), 1_000)
      assert Enum.take(back_off, 3) == Enum.to_list(1..3)

      :timer.sleep(1_000)
      assert Enum.take(back_off, 3) == []
    end
  end

  describe "limit_wait/2" do
    test "returns constant with max waiting for given" do
      check = Enum.random(1..10)

      assert Enum.to_list(limit_wait(check * 1_000)) == Enum.map(1..check, fn _ -> 1_000 end)
    end

    test "limits given back off" do
      check = Enum.random(3..10)

      assert Enum.sum(limit_wait(linear(1, 1), check)) <= check
    end
  end
end
