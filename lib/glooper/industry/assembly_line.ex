defmodule Glooper.AssemblyLine do
  @moduledoc """
  A `Glooper.AssemblyLine` is a simple module that uses a `Glooper.Recipe` and given
  the required components produces a `Glooper.Product`.
  """

  alias __MODULE__, as: AL
  alias Glooper.{Product, Recipe}

  @enforce_keys []
  @optional_keys [
    components: [],
    worker_output: 0,
    recipe: nil,
    sales_log: %{}
  ]

  defstruct @enforce_keys ++ @optional_keys

  #############################################################################
  #### Production
  #############################################################################

  @doc """
  Produce the requested number of units. Produces to maximum capacity by
  default.
  """
  def produce(_factory, _units \\ nil)

  def produce(%AL{} = f, nil), do: produce(f, factory_capacity(f))

  def produce(%AL{} = f, units) do
    case factory_capacity(f) >= units do
      false ->
        {:error, :insufficient_output_capacity}

      true ->
        {products, factory} =
          Enum.map_reduce(1..units, {f, []}, fn _, {f, products} ->
            {f, product} = assemble(f)
            {[product | products], f}
          end)

        {:ok, {factory, List.flatten(products)}}
    end
  end

  @doc """
  Returns whether this factory has enough components to output products.
  """
  def can_output?(%AL{} = factory), do: factory_capacity(factory) > 0

  @doc """
  Returns how many units can be produced given available components.
  """
  def component_capacity(%AL{recipe: recipe} = factory) do
    Enum.reduce(recipe.components, factory.worker_output, fn {name, count}, cap ->
      div(length(Keyword.get(factory.components, name, [])), count)
      |> min(cap)
    end)
  end

  @doc """
  Returns how many units can be produced given available components and
  provided extras.
  """
  def component_capacity(%AL{recipe: recipe} = factory, extras \\ []) do
    Enum.reduce(recipe.components, factory.worker_output, fn {name, count}, cap ->
      div(
        length(Keyword.get(factory.components, name, [])) +
          length(Keyword.get(extras, name, [])),
        count
      )
      |> min(cap)
    end)
  end

  # Assembles the product in `recipe` and deducts from the available factory
  # components.
  defp assemble(%AL{recipe: recipe} = factory) do
    with {components, f} <- prepare_components(factory),
         true <- Recipe.valid_components?(recipe, components),
         product <-
           Product.create(
             name: recipe.name,
             components: components,
             recipe: recipe
           ) do
      {f, product}
    end
  end

  # Looks at the component storage and removes the required components and
  # prepares them for assembly.
  defp prepare_components(%AL{recipe: recipe} = factory) do
    # Take components from factory storage and collect them into a list of ingredients
    {components, f} =
      Enum.map_reduce(recipe.components, factory, fn {name, amount}, f ->
        {result, remains} = Enum.split(f.components[name], amount)
        {result, %{f | components: Keyword.put(f.components, name, remains)}}
      end)

    # Flatten and sort the list of ingredients before returning
    {components |> List.flatten() |> Enum.sort(), f}
  end

  @doc """
  Returns the output capacity of the factory given available components, maximum
  worker output and overall factory max restrictions.
  """
  def factory_capacity(%AL{worker_output: worker_output} = f) do
    min(component_capacity(f), worker_output)
  end
end
