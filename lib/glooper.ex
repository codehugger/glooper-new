defmodule Glooper do
  @moduledoc """
  Glooper keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @typedoc "Error values used to ensure consistency on failure responses."
  @type error :: {:error, term}

  @doc """
  Returns a `:via` tuple for the given agent id using the
  `Glooper.AgentRegistry`.
  """
  def via_tuple(agent_id) when is_atom(agent_id) or is_binary(agent_id) do
    {:via, Registry, {Glooper.AgentRegistry, agent_id}}
  end

  def via_tuple(agent_id, module) when is_atom(agent_id) or is_binary(agent_id) do
    {:via, Registry, {Glooper.AgentRegistry, agent_id, module}}
  end
end
