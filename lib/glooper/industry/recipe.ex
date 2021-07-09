defmodule Glooper.Recipe do
  @moduledoc """
  A description of what components are required to yield a single unit produced.
  """

  alias __MODULE__

  @enforce_keys [:name]
  @optional_keys [label: nil, components: [], consumable: true]
  defstruct @enforce_keys ++ @optional_keys

  #############################################################################
  #### Initialization
  #############################################################################

  @doc """
  Returns a new `Recipe`.
  """
  def create(init_args) do
    struct!(Recipe, init_args)
  end

  @doc """
  Load `Recipe` from a Glooper configuration map.
  """
  def from_config(name, config \\ %{}) when is_map(config) do
    create(
      name: name,
      label: Map.get(config, "label", "Unknown")
    )
  end

  #############################################################################
  #### Components
  #############################################################################

  @doc """
  Checks the given components against the recipe.

  Returns true if the components match the recipe.
  """
  def valid_components?(%Recipe{} = r, components),
    do: components |> Enum.sort() == raw_components(r)

  @doc """
  Converts the recipe to a list of components.
  """
  def raw_components(%Recipe{components: components}) do
    Enum.flat_map(components, fn {name, count} ->
      Enum.map(1..count, fn _ -> name end)
    end)
  end
end
