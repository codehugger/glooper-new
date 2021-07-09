defmodule Glooper.TaxPolicy do
  @moduledoc """
  A tax policy describes a value formula for a payment made to a
  `Glooper.Government` by any qualifying target agents.
  """

  @enforce_keys [:target, :value]
  @optional_keys [label: "No label"]

  defstruct @enforce_keys ++ @optional_keys
end
