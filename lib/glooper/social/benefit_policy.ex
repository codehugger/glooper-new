defmodule Glooper.BenefitPolicy do
  @moduledoc """
  A benefit policy describes a value formula for a payment made by a
  `Glooper.Government` to any qualifying target agents.
  """

  @enforce_keys [:target, :value]
  @optional_keys [label: "No label"]

  defstruct @enforce_keys ++ @optional_keys
end
