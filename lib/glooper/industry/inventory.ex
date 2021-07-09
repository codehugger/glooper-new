defmodule Glooper.Inventory do
  @moduledoc """
  A convenience module for keeping track of an inventory with limited capacity.
  """

  alias __MODULE__

  @enforce_keys [:capacity]
  @optional_keys [inventory: []]
  defstruct @enforce_keys ++ @optional_keys

  def create(init_args \\ []) do
    struct!(Inventory, init_args)
  end

  @doc """
  Stores the given units in the inventory.

  If there is no room in `inventory` `{:error, :inventory_full}` is returned.

  If there is room in `inventory` but not enough to store all the units.
  `{:error, :not_enough_room}` is returned
  """
  def store(%Inventory{capacity: capacity, inventory: inventory}, _units)
      when length(inventory) == capacity,
      do: {:error, :inventory_full}

  def store(%Inventory{capacity: capacity}, units) when length(units) > capacity,
    do: {:error, :not_enough_room}

  def store(%Inventory{capacity: capacity} = i, units) when length(units) <= capacity do
    {:ok, %Inventory{i | inventory: i.inventory ++ units}}
  end

  @doc """
  Take `count` of units from inventory.

  If there are no units in `inventory` `{:error, :inventory_empty}` is
  returned.

  If there are units in `inventory` but not enough to meet the requested number
  of units
  """
  def take(%Inventory{inventory: inventory}, count) when length(inventory) < count,
    do: {:error, :not_enough_stock}

  def take(%Inventory{inventory: inventory}, _count) when length(inventory) == 0,
    do: {:error, :inventory_empty}

  def take(%Inventory{inventory: inventory} = i, count) when length(inventory) >= count do
    {units, inventory} = Enum.split(inventory, count)
    {:ok, {%{i | inventory: inventory}, units}}
  end

  @doc """
  Returns the remaining inventory space given `capacity` and current
  inventory status.
  """
  def storage_capacity(%Inventory{capacity: i_max} = inventory) do
    i_max - inventory_count(inventory)
  end

  @doc """
  Returns the number of products in `inventory`.
  """
  def inventory_count(%Inventory{inventory: inventory}), do: length(inventory)

  @doc """
  Decrease the inventory storage by `amount`.
  """
  def decrease_capacity(inventory, amount \\ 1)

  def decrease_capacity(%Inventory{capacity: i_max} = inventory, amount)
      when i_max - amount >= 0 do
    %{inventory | capacity: i_max - amount}
  end

  def decrease_capacity(%Inventory{} = inventory, _amount), do: inventory

  @doc """
  Increase the inventory storage by `amount`.
  """
  def increase_capacity(inventory, amount \\ 1)

  def increase_capacity(%Inventory{capacity: i_max} = inventory, amount) do
    %{inventory | capacity: i_max + amount}
  end
end
