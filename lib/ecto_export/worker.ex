defmodule Ecto.Export.Worker do
  import Ecto.Query
  alias Ecto.Export.Dispatcher, as: Dispatcher
  # defmacrop with_open({varname, filehandle}, expressions) do
  #   quote do
  #     unquote(varname) = unquote(filehandle)
  #     ret = unquote_splicing(expressions)
  #     File.close unquote(varname)
  #     ret
  #   end
  # end

  def export_import(repo, modules, dispatcher, options \\ %{}) do
    cond do
      options["import"] -> import(repo, modules, dispatcher, options)
      true -> export(repo, modules, dispatcher, options)
    end
  end

  defp import(repo, modules, dispatcher, options) do
    cond do
      filename = options["filename"] ->
        File.read!(filename)
          |> do_import(repo, modules, options)
      true -> {:error, :filename_missing}
    end
  end

  defp export(repo, modules, dispatcher, options) do
    reply =
      cond do
        filename = options["filename"] ->
          handle = File.open! filename, [:write, :utf8]
          ret = do_export(repo, modules, options, handle)
          File.close handle
          ret
        true ->
          do_export(repo, modules, options)
      end
    GenServer.cast dispatcher, {:reply, reply}
  end

  defp do_import(file_content, repo, modules, options) do
    ordered_modules = order_modules(modules)
    formatter = options[:formatter] || Ecto.Export.Formatter.JSON
    initial_parsed = formatter.from_string(file_content)
    formatted_entries =
      for {model, entries} <- initial_parsed do
        for entry <- entries, do: formatter.import(entry)
    end
    formatted_entries = :lists.flatten formatted_entries
    :io.format "ordered_modules: ~p~n formatted_entries: ~p~n", [ordered_modules, formatted_entries]
    for model <- ordered_modules do
      case Enum.filter(formatted_entries, &(model == &1.__struct__)) do
        [] -> :ok
        entries -> for e <- entries, do: repo.insert! e
      end
      update_report(model, ordered_modules, :write_db)
    end
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

  defp do_export(repo, models, options, filehandle \\ false) do
    formatter = options[:formatter] || Ecto.Export.Formatter.JSON
    for model <- models do
      model_export =
        repo.all(from m in model )
          |> Enum.map(&preprocess(&1, model))
          |> formatter.export
      update_report(model, models, :read_db)
      Map.put %{}, model, model_export
    end
      |> Enum.reduce(%{}, &Map.merge/2)
      |> formatter.to_string
      |> write_file filehandle
  end

  defp update_report(model, ordered_modules, stage) do
    positions_models = Enum.zip(Enum.into(1..length(ordered_modules), []), ordered_modules)
    {pos, _} =
      Enum.find(positions_models,
        fn({_, maybe_model}) when maybe_model == model -> true
          (_) -> false
        end)
    Ecto.Export.Dispatcher.progress_update({stage, 100 * pos/length(ordered_modules)})
  end

  defp write_file(formatted_string, false), do: formatted_string
  defp write_file(formatted_string, filehandle), do: IO.puts(filehandle, formatted_string)

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

end
