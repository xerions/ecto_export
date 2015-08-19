defmodule Ecto.Export.Formatter.JSON do

  def export(filehandle, entries) do
    IO.write(filehandle, <<"[">>)
    export_entries(Enum.take(entries, 1), Stream.drop(entries, 1), filehandle)
    IO.write(filehandle, <<"]">>)
    :ok
  end

  def import(repo, string_stream) do
    decoder = :jsx.decoder(__MODULE__, [repo], [:stream])
    Enum.reduce string_stream, decoder, &import_line/2
  end

  defp import_line(string, decoder) do
    case decoder.(string) do
      {:incomplete, new_decoder} -> new_decoder
      value -> value
    end
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

  defp export_entries([], _, _), do: nil
  defp export_entries([first], entries, filehandle) do
    IO.write(filehandle, :jsx.encode(first))
    Enum.reduce entries, nil, fn(entry, _) -> IO.write(filehandle, <<",\n">> <> :jsx.encode(entry)) end
  end

  def init([repo]) do
    {{repo, 0}, :jsx_to_term.start_term([:return_maps])}
  end

  def handle_event(:end_json, {_, state}), do: :jsx_to_term.handle_event(:end_json, state)
  def handle_event(:start_object, {{repo, n}, state}) do
    reply = :jsx_to_term.handle_event :start_object, state
    {{repo, n + 1}, reply}
  end
  def handle_event(:end_object, {{repo, 1}, _state = {[obj | rest], config}}) do
    finished = :jsx_to_term.finish({[obj], config}) |> :jsx_to_term.get_value
    imported = fix_structs(finished)
    Ecto.Export.Worker.insert(repo, imported)
    reply = :jsx_to_term.handle_event(:end_object, {[{:object, []} | rest], config})
    {{repo, 0}, reply}
  end
  def handle_event(:end_object, {{repo, succ_n}, state}) do
    reply = :jsx_to_term.handle_event :end_object, state
    {{repo, succ_n - 1}, reply}
  end
  def handle_event(event, {rn, state}) do
    {rn, :jsx_to_term.handle_event(event, state)}
  end

end
