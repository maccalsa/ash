defmodule Ash.Test do
  @moduledoc """
  Testing helpers for Ash.
  """

  require ExUnit.Assertions

  @doc """
  Assert that the given changeset, query, or action input has a matching error.

  Use the optional second argument to assert that the errors (all together) are of a specific class.
  """
  @spec assert_has_error(
          Ash.Changeset.t()
          | Ash.Query.t()
          | Ash.ActionInput.t()
          | {:error, term}
          | {:ok, term}
          | :ok,
          error_class :: Ash.Error.class_module(),
          (Ash.Error.t() -> boolean)
        ) :: Ash.Error.t() | no_return
  def assert_has_error(changeset_query_or_input, error_class \\ nil, callback, opts \\ [])

  def assert_has_error({:error, %{splode: splode} = error}, error_class, callback, opts) do
    error = splode.to_class(error)

    if error_class do
      ExUnit.Assertions.assert(error.__struct__ == error_class,
        message:
          "Expected the value to have errors of class #{inspect(error_class)}, got: #{inspect(error.__struct__)}"
      )
    end

    match = Enum.find(error.errors, callback)

    ExUnit.Assertions.assert(match,
      message:
        opts[:message] ||
          """
          Expected at least one error to match the provided callback, but none did.

          Errors:

          #{inspect(error.errors, pretty: true)}
          """
    )

    match
  end

  def assert_has_error({:ok, _record}, error_class, _callback, _opts), do: no_errors(error_class)
  def assert_has_error(:ok, error_class, _callback, _opts), do: no_errors(error_class)

  def assert_has_error(changeset_query_or_input, error_class, callback, opts) do
    type =
      case changeset_query_or_input do
        %Ash.Changeset{} -> "changeset"
        %Ash.Query{} -> "query"
        %Ash.ActionInput{} -> "action input"
      end

    error = Ash.Error.to_error_class(changeset_query_or_input)

    if error_class do
      ExUnit.Assertions.assert(error.__struct__ == error_class,
        message:
          "Expected the #{type} to have errors of class #{inspect(error_class)}, got: #{inspect(error.__struct__)}"
      )
    end

    match = Enum.find(error.errors, callback)

    ExUnit.Assertions.assert(match,
      message:
        opts[:message] ||
          """
          Expected at least one error to match the provided callback, but none did.

          Errors:

          #{inspect(error.errors, pretty: true)}
          """
    )

    match
  end

  defp no_errors(error_class) do
    message =
      if error_class do
        "Expected the value to have errors of class #{inspect(error_class)}, but it had no errors"
      else
        "Expected the value to have errors matching the provided callback, but it had no errors"
      end

    ExUnit.Assertions.flunk(message)
  end

  @doc """
  Refute that the given changeset, query, or action input has a matching error.

  The `error_class` argument has been deprecated and should not be used.
  """
  @spec refute_has_error(
          Ash.Changeset.t()
          | Ash.Query.t()
          | Ash.ActionInput.t()
          | :ok
          | {:ok, term}
          | {:error, term},
          error_class :: Ash.Error.class_module(),
          (Ash.Error.t() -> boolean)
        ) :: Ash.Error.t() | no_return
  def refute_has_error(changeset_query_or_input, error_class \\ nil, callback, opts \\ [])

  # An :ok response doesn't have any errors!
  def refute_has_error(:ok, _error_class, _callback, _opts), do: :ok
  def refute_has_error({:ok, _record}, _error_class, _callback, _opts), do: :ok

  def refute_has_error({:error, error}, error_class, callback, opts) do
    if error_class != nil do
      IO.warn("`error_class` argument to `refute_has_error` is deprecated and will be ignored")
    end

    error = Ash.Error.to_error_class(error)
    match = Enum.find(error.errors, callback)

    ExUnit.Assertions.assert(!match,
      message:
        opts[:message] ||
          """
          Expected no errors to match the provided callback, but one did.

          Errors:

          #{inspect(match, pretty: true)}
          """
    )

    match
  end

  def refute_has_error(changeset_query_or_input, error_class, callback, opts) do
    if error_class != nil do
      IO.warn("`error_class` argument to `refute_has_error` is deprecated and will be ignored")
    end

    error = Ash.Error.to_error_class(changeset_query_or_input)
    match = Enum.find(error.errors, callback)

    ExUnit.Assertions.refute(match,
      message:
        opts[:message] ||
          """
          Expected no errors to match the provided callback, but one did.

          Matching Error:

          #{inspect(match, pretty: true)}

          Errors:

          #{inspect(error.errors, pretty: true)}
          """
    )

    match
  end

  @doc """
  Clears the `__metadata__` field and the underlying ecto `__meta__` field

  This allows for easier comparison of changeset/query results
  """
  def strip_metadata(structs) when is_list(structs), do: Enum.map(structs, &strip_metadata/1)

  def strip_metadata(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> strip_metadata()
    |> List.to_tuple()
  end

  def strip_metadata(%page_struct{results: results} = page)
      when page_struct in [Ash.Page.Offset, Ash.Page.Keyset] do
    %{page | results: Enum.map(results, &strip_metadata/1)}
  end

  def strip_metadata(%{__metadata__: _, __meta__: _} = struct) do
    struct = %{struct | __metadata__: %{}, __meta__: %Ecto.Schema.Metadata{}}

    struct
    |> Map.keys()
    |> Enum.reduce(struct, fn key, struct ->
      Map.update!(struct, key, &strip_metadata/1)
    end)
  end

  def strip_metadata(%{__metadata__: _} = struct) do
    struct = %{struct | __metadata__: %{}}

    struct
    |> Map.keys()
    |> Enum.reduce(struct, fn key, struct ->
      Map.update!(struct, key, &strip_metadata/1)
    end)
  end

  def strip_metadata(other), do: other
end
