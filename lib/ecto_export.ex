defmodule Ecto.Export do
  @moduledoc """
  Ecto plugin for exporting and importing Ecto.Model application data.
  """
  import Ecto.Query
  alias Ecto.Export.Dispatcher, as: Dispatcher

  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    tree = [worker(Ecto.Export.Dispatcher, [])]
    opts = [name: Ecto.Export.Sup, strategy: :one_for_one]
    Supervisor.start_link(tree, opts)
  end

  @doc """
  Start an export or import job.

  ## Params

  * `repo` - mandatory, the Ecto.Repo which contains the models to be exported
  * `models` - mandatory, list of modules which implement Ecto.Model
  * `options` - optional, Map whith the following options
    * `"filename"` - mandatory, string, the filename to export/import from
    * `"import"` - boolean, if true starts an import - default is false
    * `"formatter"` - atom, defines which module to use for string conversion - default is `Ecto.Export.Formatter.JSON`

  ## Result

  `{:ok, job_id}`

  """
  def export(repo, models, options \\ []), do: Dispatcher.start_export(repo, models, options)

  @doc """
  Check the status of a former started job

  ## Params

  * `options` - optional, Map with the following options
    * `"id"` - job_id obtained when starting the job

  ## Result

  * `{:ok, {stage, progress}}` where stage is an atom and progress is an integer representing 0-100%
  * `{:error, :not_found}`

  """
  def check_job(args), do: Dispatcher.check_status(args)
end
