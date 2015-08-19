defmodule Ecto.Export.Dispatcher do
  use GenServer
  alias Ecto.Export.Worker

  defstruct jobs: %{}, jobcounter: 0, jobcounter_index: %{}

  def start_export(repo, models, options \\ []), do: call {:start_export, repo, models, options}

  def check_status(id) when is_integer(id), do: call {:check_status, id}
  def check_status(_), do: {:error, :bad_id}

  def done, do: cast {:done, self}
  def done(val), do: cast {:done, val}

  def progress_update(val), do: cast {:progress_update, val, self}

  def init(_) do
    :erlang.process_flag :trap_exit, :true
    {:ok, %__MODULE__{}}
  end

  def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def handle_call({:start_export, repo, models, options}, _from, state) do
    jobcounter = get_jobcounter(state)
    {:ok, pid} = Task.start_link(Worker, :export_import, [repo, models, options])
    {:reply, {:ok, jobcounter}, state 
                                |> put_jobcounter(jobcounter + 1) 
                                |> put_job(pid, {repo, models, options, pid, jobcounter, 0}) 
                                |> put_index(jobcounter, pid) }
  end
  def handle_call({:check_status, id}, _from, state) do
    reply =
      case get_index(state, id) do
        nil -> cond do
                 id < get_jobcounter(state) -> {:ok, :job_finished}
                 true -> {:error, :not_found}
               end
        pid -> {_repo, _models, _options, _pid, _jobcounter, progress} = get_job(state, pid)
               {:ok, progress}
      end
    {:reply, reply, state}
  end

  def handle_cast({:done, job}, state), do: {:noreply, delete_job_and_index(state, job)}
  def handle_cast({:progress_update, new_val, from}, state) do
    case get_job(state, from) do
      nil ->
        {:noreply, state}
      {repo, models, options, pid, jobcounter, _old_val} ->
        {:noreply, state |> put_job(from, {repo, models, options, pid, jobcounter, new_val})}
    end
  end

  def handle_info({:EXIT, from, _reason}, state), do: {:noreply, delete_job_and_index(state, from)}
  def handle_info(_, _, state), do: {:noreply, state}

  defp delete_job_and_index(state, id) when is_integer(id), do: delete_job_and_index(state, get_index(state, id))
  defp delete_job_and_index(state, job) do
    case get_job(state, job) do
      nil -> state
      {_repo, _models, _options, pid, jobcounter, _progress} -> 
        stop_task(pid)
        delete_job(state, job) |> delete_index(jobcounter)
    end
  end

  defp delete_job(%__MODULE__{jobs: jobs} = state, job), do: %{state | jobs: Map.delete(jobs, job)}
  defp get_job(%__MODULE__{jobs: jobs}, pid), do: Map.get(jobs, pid)
  defp put_job(state = %__MODULE__{jobs: jobs}, pid, job), do: %{state | jobs: Map.put(jobs, pid, job)}

  defp put_jobcounter(state = %__MODULE__{}, jobcounter), do: %{state | jobcounter: jobcounter}
  defp get_jobcounter(%__MODULE__{jobcounter: jobcounter}), do: jobcounter

  defp get_index(%__MODULE__{jobcounter_index: jobcounter_index}, id), do: Map.get(jobcounter_index, id)
  defp put_index(state = %__MODULE__{jobcounter_index: jobcounter_index}, id, pid), do: %{state | jobcounter_index: Map.put(jobcounter_index, id, pid)}
  defp delete_index(%__MODULE__{jobcounter_index: jcidx} = state, id), do: %{state | jobcounter_index: Map.delete(jcidx, id)}

  defp stop_task(pid) when is_pid(pid) do
    case Process.alive?(pid) do
      true -> Process.exit(pid, :kill)
      false -> []
    end
  end
  defp stop_task(_), do: []

  defp call(params), do: GenServer.call(__MODULE__, params)
  defp cast(params), do: GenServer.cast(__MODULE__, params)
end
