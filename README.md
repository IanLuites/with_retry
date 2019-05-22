# WithRetry
[![Hex.pm](https://img.shields.io/hexpm/v/with_retry.svg "Hex")](https://hex.pm/with_retry/with_retry)
[![Hex.pm](https://img.shields.io/hexpm/l/with_retry.svg "License")](LICENSE.md)

`with_retry` is an additional code block used for writing
with statements that have retry logic.

[API Reference](https://hexdocs.pm/with_retry/)

## Getting started

### 1. Check requirements

- Elixir 1.7+

### 2. Install WithRetry

Edit `mix.exs` and add `with_retry` to your list of dependencies and applications:

```elixir
def deps do
  [{:with_retry, "~> 1.0"}]
end
```

Then run `mix deps.get`.

### 3. Use

Configure hosts and queues:

```elixir
defmodule Example do
  use WithRetry


  def download(url, file) do
    with_retry {:ok, %{body: data}} <- HTTPX.get(url),
               :ok <- File.write(file, data) do
      data
    end
  end
end
```

## Capturing failures

The `with_retry` captures many possible failures including:
 - Pattern mismatch.
 - Raise
 - Throw
 - Exit

All none captured failures will either return in the case of no `else` or
bubble up.

### Pattern Mismatch (else)

```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data) do
  data
else
  _error -> nil
end
```

### Raise (rescue)

```elixir
with_retry %{body: data} <- HTTPX.get(url),
           :ok <- File.write!(file, data) do
  data
rescue
  _ -> nil
end
```

### Throw (catch)

```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- might_throw(data),
           :ok <- File.write(file, data) do
  data
catch
  _thrown -> nil
end
```

### Exit (catch)

```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- might_exit(data),
           :ok <- File.write(file, data) do
  data
catch
  {:exit, _code} -> nil
end
```

### Combined

```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- might_throw(data),
           :ok <- might_exit(data),
           :ok <- File.write!(file, data) do
  data
else
  _error -> nil
rescue
  _ -> nil
catch
  {:exit, _code} -> nil
  _thrown -> nil
end
```

## Back Off

The back off (timeouts) can be configured on the last last of the `with_retry`.

The default back off is 5 total tries with 1s in between attempts.
To update the configuration see the following examples.

### No Retry

Setting the `back_off` to `false` will disable retries and
function like a normal `with`.

```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: false do
  data
end
```

### Passing An Enumerable

The `back_off` accepts any enumerable that returns timeouts in milliseconds.

In this example we wait `250`ms after the first attempt,
`1_000` after the second, and `5_000` after the third.
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: [250, 1_000, 5_000] do
  data
end
```

### Build In Back Off Strategies
#### Constant

To retry with a constant timeout use: `constant/1` passing the timeout in `ms`.

Retry endlessly every `5_000`ms.
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: constant(5_000) do
  data
end
```

#### Linear

To retry with a linearly increasing timeout use: `linear/2` passing
the base timeout in `ms` and the increase in `ms`.

Retry endlessly starting with `1_000`ms and increasing the timeout with
`1_500` every wait. (e.g. `1_000`, `2_500`, `4_000`, ...)
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: linear(1_000, 1_500) do
  data
end
```

#### Exponential

To retry with an exponentially increasing timeout use: `exponential/2` passing
the base timeout in `ms` and the factor.

Retry endlessly starting with `250`ms and doubling after every wait.
(e.g. `250`, `500`, `1_000`, `2_000`, ...)
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: exponential(250, 2) do
  data
end
```

### Build In Back Off Modifiers
#### Cap

To cap the retry to a maximum timeout one can use `cap/2` and give a
`back_off` and a cap in ms.

Retry endlessly starting with `250`ms and doubling after every wait,
but capping at `1_500`.
(e.g. `250`, `500`, `1_000`, `1_500`, `1_500`, ...)
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: cap(exponential(250, 2), 1_500) do
  data
end
```

#### Max Try

Limit the back off to a given amount of tries using `max_try/2` and give a
`back_off` and a count of tries.
(Including the first attempt.)

Try 4 times with exponential back off.
(e.g. `#1`, wait `250`, `#2`, wait `500`, `#3`, wait `1_000`, `#4`)
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: max_try(exponential(250, 2), 4) do
  data
end
```

#### Max Retry

Limit the back off to a given amount of retries using `max_retry/2` and give a
`back_off` and a count of retries.
(Excluding the first attempt.)

Retry 3 times with exponential back off.
(e.g. `#1`, wait `250`, `#2`, wait `500`, `#3`, wait `1_000`, `#4`)
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: max_try(exponential(250, 2), 3) do
  data
end
```

#### Limit

Limit execution of the `with_retry` to a given time limit in `ms`
using `limit/2`.

This includes the time spend doing processing the actually `with`.
See: `limit_wait/2` to limit the time spend waiting, excluding execution time.

The prediction is a best effort limitation and a long execution time might
bring the total time spend on executing the `with_try` over the set limit.

Retry as many times as fit within `4_000`ms with exponential back off.
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: limit(exponential(250, 2), 8_000) do
  data
end
```

#### Limit Wait

Limit the waiting time of the `with_retry` to a given time limit in `ms`
using `limit_wait/2`.

This excludes the time spend doing processing the actually `with`.
See: `limit/2` to limit the total time, including execution time.

Retry as many times as fit within `8_000`ms with exponential back off.
(e.g. `250`, `500`, `1_000`, `2_000`, `4_000` for a total of `7_750`.)
```elixir
with_retry {:ok, %{body: data}} <- HTTPX.get(url),
           :ok <- File.write(file, data),
           back_off: limit_wait(exponential(250, 2), 8_000) do
  data
end
```

## Changelog

### v1.0

- Fix dialyzer issue.

## Copyright and License

Copyright (c) 2018, Ian Luites.

WithRetry code is licensed under the [MIT License](LICENSE.md).
