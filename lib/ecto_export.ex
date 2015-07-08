defmodule Ecto.Export do
  import Ecto.Query
  alias Ecto.Export.Dispatcher, as: Dispatcher
  
  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    tree = [worker(Ecto.Export.Dispatcher, [])]
    opts = [name: Ecto.Export.Sup, strategy: :one_for_one]
    Supervisor.start_link(tree, opts)
  end

  def export(repo, models, options \\ []), do: Dispatcher.start_export(repo, models, options)
  def check_job(id), do: Dispatcher.check_status(id)
end
