defmodule WithRetryTest do
  use ExUnit.Case
  use WithRetry

  defp raise?(true), do: raise("Must raise 🧟")
  defp raise?(false), do: :no_raise

  defp throw?(true), do: throw("Must throw 🏀")
  defp throw?(false), do: :no_throw

  defp throw_exit(true), do: exit(1)

  describe "with_retry (pattern match)" do
    test "returns success" do
      result =
        with_retry {:ok, x} <- {:ok, 5},
                   back_off: false do
          x
        end

      assert result == 5
    end

    test "returns failure without else" do
      result =
        with_retry {:ok, x} <- {:error, :failure},
                   back_off: false do
          x
        end

      assert result == {:error, :failure}
    end

    test "pattern matches failure with else" do
      result =
        with_retry {:ok, x} <- {:error, :failure},
                   back_off: false do
          x
        else
          {:error, :failure} -> :caught
        end

      assert result == :caught
    end

    test "raise if no matches on else" do
      assert_raise(
        CaseClauseError,
        fn ->
          with_retry {:ok, x} <- {:error, :failure},
                     back_off: false do
            x
          else
            {:error, :different} -> :caught
          end
        end
      )
    end
  end

  describe "with_retry (potentially raising)" do
    test "returns success" do
      result =
        with_retry x <- raise?(false),
                   back_off: false do
          x
        end

      assert result == :no_raise
    end

    test "bubbles raise without rescue" do
      assert_raise(
        RuntimeError,
        fn ->
          with_retry x <- raise?(true),
                     back_off: false do
            x
          end
        end
      )
    end

    test "pattern matches failure with resceu" do
      result =
        with_retry x <- raise?(true),
                   back_off: false do
          x
        rescue
          %RuntimeError{message: "Must raise 🧟"} -> :caught
        end

      assert result == :caught
    end

    test "raise if no matches on rescue" do
      assert_raise(
        CaseClauseError,
        fn ->
          with_retry x <- raise?(true),
                     back_off: false do
            x
          rescue
            {:error, :different} -> :caught
          end
        end
      )
    end
  end

  describe "with_retry (potentially throwing)" do
    test "returns success" do
      result =
        with_retry x <- throw?(false),
                   back_off: false do
          x
        end

      assert result == :no_throw
    end

    test "bubbles throw without catch" do
      assert catch_throw(
               with_retry x <- throw?(true),
                          back_off: false do
                 x
               end
             ) == "Must throw 🏀"
    end

    test "pattern matches failure with catch" do
      result =
        with_retry x <- throw?(true),
                   back_off: false do
          x
        catch
          "Must throw 🏀" -> :caught
        end

      assert result == :caught
    end

    test "raise if no matches on catch" do
      assert_raise(
        CaseClauseError,
        fn ->
          with_retry x <- throw?(true),
                     back_off: false do
            x
          catch
            :different -> :caught
          end
        end
      )
    end

    test "catches exits" do
      result =
        with_retry x <- throw_exit(true),
                   back_off: false do
          x
        catch
          {:exit, _} -> :caught_exit
        end

      assert result == :caught_exit
    end
  end
end
