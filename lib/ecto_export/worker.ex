defmodule Ecto.Export.Worker do
  import Ecto.Query
  alias Ecto.Export.Dispatcher, as: Dispatcher

  @default_batch_size 1000

  def export_import(repo, modules, options \\ %{}) do
    export_uri = options["export_uri"]
    cond do
      is_nil(export_uri) -> {:error, :no_export_uri}
      options["import"] -> import(repo, options, export_uri)
      true -> export(repo, modules, options, export_uri)
    end
  end

  def insert(repo, entry) do
    try do repo.insert! entry
    catch _, _ -> nil
    end
  end

  defp import(repo, options, export_uri),
    do: import_stream(export_uri) |> do_import(repo, options)

  defp export(repo, modules, options, export_uri) do
    formatter = options[:formatter] || Ecto.Export.Formatter.JSON
    {streamer, cut_uri} = find_stream_module export_uri
    ordered_modules = order_modules(modules)
    entries = export_stream repo, ordered_modules

    formatted_entries = formatter.export(entries)
    streamer.send_stream formatted_entries, cut_uri

    Dispatcher.done # XXX: I don't sure that it is needed
  end

  def import_stream(export_uri) do
    {streamer, cut_uri} = find_stream_module export_uri
    streamer.receive_stream cut_uri
  end

  defp export_stream(repo, modules) do
    Stream.resource(
      fn -> {modules, 0, -1} end,
      fn {modules, count, offset} ->
        get_next_entries({modules, count, offset}, repo)
      end,
      fn _ -> nil end)
  end

  defp get_next_entries({[module | _] = modules, count, offset}, repo) do
    entries = repo.all(from m in module, where: m.id > ^offset, limit: ^batch_size)
    last = List.last(entries)
    offset = if last, do: last.id, else: offset
    get_next_entries(entries, {modules, count, offset}, repo)
  end
  defp get_next_entries({[], _, _}, _), do: {:halt, nil}

  defp get_next_entries([], {[], _, _}, _), do: {:halt, nil}
  defp get_next_entries([], {[_ | rest], count, _offset}, repo) do
    get_next_entries({rest, count, -1}, repo)
  end
  defp get_next_entries(entries, {[model | _] = models, count, offset}, _repo) do
    prepared_entries = Enum.map entries, &preprocess(&1, model)
    count =  count + Enum.count(prepared_entries)
    Dispatcher.progress_update({:write_file, count})
    {prepared_entries, {models, count, offset}}
  end

  defp do_import(string_stream, repo, options) do
    formatter = options[:formatter] || Ecto.Export.Formatter.JSON
    formatter.import(repo, string_stream)
  end

  defp order_modules(modules), do: order_modules(modules, [], [])
  defp order_modules([], [], ret), do: ret
  defp order_modules([], leftovers, ret), do: order_modules(leftovers, [], ret)
  defp order_modules([module | rest], ignored, ret) do
    bad_assocs =
      Enum.filter(module.__schema__(:associations),
        fn(%Ecto.Association.BelongsTo{owner: owner}) -> if(:lists.member(owner, ret), do: false, else: true)
          (_) -> false
        end)
    cond do
      length(bad_assocs) > 0 -> order_modules(rest, [module | ignored], ret)
      true -> order_modules(rest, ignored, ret ++ [module])
    end
  end

  defp preprocess(entry_map, model) do
    entry_map
      |> Map.delete(:__meta__)
      |> export_associations(model)
  end

  defp export_associations(entry, model) do
    associations = model.__schema__ :associations
    associations = for a <- associations, do: model.__schema__(:association, a)
    Enum.reduce associations, entry, &export_association(&1, &2)
  end

  defp export_association(%Ecto.Association.Has{:field => field}, entry), do: Map.delete(entry, field)
  defp export_association(_, entry), do: entry

  defp batch_size, do: Application.get_env(:ecto_export, :batch_size, @default_batch_size)

  defp find_stream_module("file://" <> rest), do: {Ecto.Export.Stream.File, rest}

end
