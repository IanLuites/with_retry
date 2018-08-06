defmodule WithRetry do
  @moduledoc ~S"""
  Adds a with_retry block for writing with statements that are automatically retried.

  ## Example

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
  """

  @doc false
  defmacro __using__(_opts \\ []) do
    quote do
      require WithRetry
      import WithRetry
      import WithRetry.BackOff
    end
  end

  ### Generate `with_try` macro.
  ## Elixir has not variable arity macros.
  #

  Enum.each(0..10, fn count ->
    arg = Enum.map(0..count, &Macro.var(:"c#{&1}", nil))

    @doc ~S"""
    """
    defmacro with_retry(unquote_splicing(arg), opts), do: create_with_retry(unquote(arg), opts)
  end)

  ### `with_try` execution.

  @doc false
  @spec do_with_retry(function, Enumerable.t(), Keyword.t()) :: any
  def do_with_retry(exec, back_off, opts \\ []) do
    back_off
    |> Enum.reduce_while(
      nil,
      fn sleep, acc ->
        acc = acc || attempt(exec)

        if success?(acc) do
          {:halt, acc}
        else
          :timer.sleep(sleep)
          {:cont, attempt(exec)}
        end
      end
    )
    |> Kernel.||(attempt(exec))
    |> process(opts)
  end

  ### Generation Helpers ###

  defp create_with_retry(args, opts) do
    maybe_opts = List.last(args)

    {args, opts} =
      if Keyword.keyword?(maybe_opts),
        do: {List.delete_at(args, -1), Keyword.merge(opts, maybe_opts)},
        else: {args, opts}

    back_off =
      if Keyword.has_key?(opts, :back_off),
        do: opts[:back_off],
        else: quote(do: max_try(5))

    quote do
      do_with_retry(
        fn ->
          with unquote_splicing(args) do
            {:success, unquote(opts[:do])}
          else
            failed -> {:failed, failed}
          end
        end,
        unquote(back_off) || [],
        else: unquote(create_case_call(opts[:else])),
        rescue: unquote(create_case_call(opts[:rescue])),
        catch: unquote(create_case_call(opts[:catch]))
      )
    end
  end

  defp create_case_call(nil), do: nil

  defp create_case_call(code) do
    quote do
      fn input ->
        case input do
          unquote(code)
        end
      end
    end
  end

  ### Execution Helpers ###

  @spec success?(any) :: boolean
  defp success?({:success, _}), do: true
  defp success?(_), do: false

  @spec process({:success | :failed | :rescue | :catch | :exit, any}, Keyword.t()) ::
          any | no_return
  defp process({:success, result}, _opts), do: result

  defp process({:failed, result}, opts) do
    if opts[:else], do: opts[:else].(result), else: result
  end

  defp process({:rescue, result}, opts) do
    if opts[:rescue], do: opts[:rescue].(result), else: raise(result)
  end

  defp process({:catch, result}, opts) do
    if opts[:catch], do: opts[:catch].(result), else: throw(result)
  end

  defp process({:exit, result}, opts) do
    if opts[:catch], do: opts[:catch].({:exit, result}), else: exit(result)
  end

  @spec attempt(function) :: {:success | :failed | :rescue | :catch | :exit, any}
  defp attempt(exec) do
    exec.()
  rescue
    e -> {:rescue, e}
  catch
    cat -> {:catch, cat}
    :exit, cat -> {:exit, cat}
  end
end
