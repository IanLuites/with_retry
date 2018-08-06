defmodule WithRetry.BackOff do
  @moduledoc ~S"""
  Helper module with different back off strategies and functionality.
  """

  @doc ~S"""
  A constant stream of timeouts.

  ## Example

  ```
  iex> constant(2_000) |> Enum.to_list()
  [2_000, 2_000, ...]
  ```
  """
  @spec constant(pos_integer) :: Enumerable.t()
  def constant(timeout \\ 1_000), do: Stream.unfold(0, &{timeout, &1 + 1})

  @doc ~S"""
  A linearly increasing stream of timeouts.

  ## Example

  ```
  iex> linear(1_000, 1_500) |> Enum.to_list()
  [1_000, 2_500, 4_000, ...]
  ```
  """
  @spec linear(pos_integer, pos_integer) :: Enumerable.t()
  def linear(base \\ 1_000, addition \\ 1_000), do: Stream.unfold(base, &{&1, &1 + addition})

  @doc ~S"""
  A exponentially increasing stream of timeouts.

  ## Example

  ```
  iex> exponential(1_000, 2) |> Enum.to_list()
  [1_000, 2_000, 4_000, ...]
  ```
  """
  @spec exponential(pos_integer, pos_integer | float) :: Enumerable.t()
  def exponential(base \\ 1_000, factor \\ 2), do: Stream.unfold(base, &{round(&1), &1 * factor})

  @doc ~S"""
  Caps a stream of timeouts to the given value.

  ## Example

  ```
  iex> exponential(1_000, 2) |> cap(3_500) |> Enum.to_list()
  [1_000, 2_000, 3_500, ...]
  ```
  """
  @spec cap(Enumerable.t(), pos_integer) :: Enumerable.t()
  def cap(back_off, cap), do: Stream.map(back_off, &if(&1 < cap, do: &1, else: cap))

  @doc ~S"""
  Caps a stream to the given maximum number of tries.

  (Including the first attempt.)

  See: `max_retry/2` to cap to any number of retries.

  ## Example

  ```
  iex> exponential(1_000, 2) |> max_try(3) |> Enum.to_list()
  [1_000, 2_000]
  ```
  """
  @spec max_try(Enumerable.t(), pos_integer) :: Enumerable.t()
  def max_try(back_off \\ constant(), max), do: max_retry(back_off, max - 1)

  @doc ~S"""
  Caps a stream to the given maximum number of retries.

  (Excluding the first attempt.)

  See: `max_try/2` to cap to any number of tries.

  ## Example

  ```
  iex> exponential(1_000, 2) |> max_try(3) |> Enum.to_list()
  [1_000, 2_000, 4_000]
  ```
  """
  @spec max_retry(Enumerable.t(), pos_integer) :: Enumerable.t()
  def max_retry(back_off \\ constant(), max),
    do: Stream.transform(back_off, 0, &if(&2 < max, do: {[&1], &2 + 1}, else: {:halt, &2}))

  @doc ~S"""
  Limits a stream of timeouts to a maximum duration.

  This includes the time spend doing processing the actually `with`.
  See: `limit_wait/2` to limit the time spend waiting, excluding execution time.

  The prediction is a best effort limitation and a long execution time might
  bring the total time spend on executing the `with_try` over the set limit.

  ## Example

  ```
  iex> exponential(1_000, 2) |> limit(7_000) |> Enum.to_list()
  [1_000, 2_000]
  ```
  *Note:*
    You would expect `[1_000, 2_000, 4_000]` (sum: `7_000`),
    but assuming a non zero execution time the `3_000 + execution time + 4_000`
    would bring the total over the set `7_000` limit.
  """
  @spec limit(Enumerable.t(), pos_integer) :: Enumerable.t()
  def limit(back_off \\ constant(), limit) do
    Stream.transform(
      back_off,
      :os.system_time(:milli_seconds),
      &if(:os.system_time(:milli_seconds) - &2 + &1 <= limit, do: {[&1], &2}, else: {:halt, &2})
    )
  end

  @doc ~S"""
  Limits a stream of timeouts to a maximum duration.

  This excludes the time spend doing processing the actually `with`.
  See: `limit/2` to limit the total time, including execution time.

  ## Example

  ```
  iex> exponential(1_000, 2) |> limit_wait(7_000) |> Enum.to_list()
  [1_000, 2_000, 4_000]
  ```
  """
  @spec limit_wait(Enumerable.t(), pos_integer) :: Enumerable.t()
  def limit_wait(back_off \\ constant(), limit) do
    Stream.transform(
      back_off,
      0,
      &if(&2 + &1 <= limit, do: {[&1], &2 + &1}, else: {:halt, &2})
    )
  end
end
