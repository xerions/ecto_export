defmodule Ecto.Export.Worker do
  import Ecto.Query
  alias Ecto.Export.Dispatcher, as: Dispatcher

  @default_batch_size 1000

  def export_import(repo, modules, dispatcher, options \\ %{}) do
    filename = options["filename"]
    reply =
      cond do
        is_nil(filename) -> {:error, :no_filename}
        options["import"] -> import(repo, modules, dispatcher, options, filename)
        true -> export(repo, modules, dispatcher, options, filename)
      end
    GenServer.cast dispatcher, {:reply, reply}
  end

  def insert(repo, entry) do
    try do repo.insert! entry
    catch _, _ -> nil
    end
  end

  defp import(repo, modules, dispatcher, options, filename) do
    case import_stream(filename) do
      {:error, _} = e -> e
      string_stream -> do_import(string_stream, repo, modules, options)
    end
  end

  defp export(repo, modules, dispatcher, options, filename) do
    formatter = options[:formatter] || Ecto.Export.Formatter.JSON
    ordered_modules = order_modules(modules)
    entries = export_stream repo, ordered_modules, dispatcher
    case File.open filename, [:write, :utf8] do
      {ok, filehandle} ->
        ret = formatter.export(filehandle, entries)
        File.close filehandle
        GenServer.cast dispatcher, {:reply, ret, self}
      err -> err
    end
  end

  def import_stream(filename) do
    case File.open filename, [:read, :utf8] do
      {:ok, filehandle} ->
        Stream.resource(
          fn -> {:ok, handle} = File.open filename, [:read, :utf8]
                {handle, 0} end,
          fn {filehandle, linecount} ->
            case IO.read(filehandle, :line) do
              :eof -> {:halt, filehandle}
              {:error, _} = err -> {:halt, filehandle}
              data ->
                Ecto.Export.Dispatcher.progress_update({:read_file, linecount})
                {[data], {filehandle, linecount + 1}}
            end
          end,
          fn filehandle -> File.close(filehandle) end)
      _ -> {:error, :open_file}
    end
  end

  defp export_stream(repo, modules, dispatcher) do
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
  defp get_next_entries([], {[_ | rest], count, offset}, repo) do

    get_next_entries({rest, count, -1}, repo)
  end
  defp get_next_entries(entries, {[model | _] = models, count, offset}, repo) do
    prepared_entries = Enum.map entries, &preprocess(&1, model)
    count =  count + Enum.count(prepared_entries)
    Ecto.Export.Dispatcher.progress_update({:write_file, count})
    {prepared_entries, {models, count, offset}}
  end

  defp do_import(string_stream, repo, modules, options) do
    ordered_modules = order_modules(modules)
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

end
