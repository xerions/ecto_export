defmodule Ecto.Export.Formatter.JSON do

  def import(entry) do
    fix_structs(entry)
  end

  defp fix_structs(old = %{"__struct__" => module}) do
    helper = fn(a) -> struct(string_to_elixir_atom(module), a) end
    Map.delete(old, "__struct__")
      |> Enum.map(&fix_keys/1)
      |> helper.()
  end

  defp fix_structs(val), do: val

  defp fix_keys({k, val}), do: {string_to_elixir_atom(k), fix_structs(val)}

  defp string_to_elixir_atom(str), do: :erlang.list_to_atom(String.to_char_list(str))
  def export(entry) do
    entry
  end

  def to_string(exprs), do: :jsx.encode(exprs)
  def from_string(string), do: :jsx.decode(string)
end
