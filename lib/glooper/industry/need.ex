defmodule Glooper.Need do
  @moduledoc """
  The need describes the numerical necessity or obligation associated with a
  particular `Glooper.Product`.
  """

  @enforce_keys [:product]
  @optional_keys [purchase: 0, consume: 0, store: 0]

  defstruct @enforce_keys ++ @optional_keys
end
