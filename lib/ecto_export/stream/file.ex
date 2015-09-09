defmodule Ecto.Export.Stream.File do
  alias Ecto.Export.Dispatcher

  def send_stream formatted_entries, filename do
    filehandle = File.open! filename, [:write, :utf8]
    Enum.map formatted_entries, &IO.write(filehandle, &1)
    File.close filehandle
  end

  def receive_stream filename do
    Stream.resource(
      fn -> {File.open!(filename, [:read, :utf8]), 0} end,
      fn {filehandle, linecount} ->
        case IO.read(filehandle, :line) do
          :eof -> {:halt, filehandle}
          {:error, _} = _err -> {:halt, filehandle}
          data ->
            Dispatcher.progress_update({:read_file, linecount})
            {[data], {filehandle, linecount + 1}}
        end
      end,
      fn filehandle -> File.close(filehandle) end)
  end
end
