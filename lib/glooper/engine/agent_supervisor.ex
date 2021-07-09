defmodule Glooper.AgentSupervisor do
  # Do not attempt to restart agents when they crash
  use DynamicSupervisor

  @name __MODULE__

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: @name)
  end

  def start_agent(sup \\ @name, spec, args \\ [])

  def start_agent(sup, spec, [{:name, name} | _rest] = args) when is_list(args) do
    {:ok, pid} = DynamicSupervisor.start_child(sup, spec)
    Registry.register(Glooper.AgentRegistry, name, pid)
  end

  def start_agent(sup, spec, _args) do
    DynamicSupervisor.start_child(sup, spec)
  end

  def stop_agent(sup \\ @name, agent_id)

  def stop_agent(sup, agent_id) when is_pid(agent_id) do
    DynamicSupervisor.terminate_child(sup, agent_id)
  end

  def stop_agent(sup, agent_id) when is_atom(agent_id) or is_binary(agent_id) do
    case Registry.lookup(Glooper.AgentRegistry, agent_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(sup, pid)
      [] -> {:error, :not_found}
    end
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
