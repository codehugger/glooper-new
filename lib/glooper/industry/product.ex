defmodule Glooper.Product do
  @moduledoc """
  An article or substance produced by a `Glooper.Factory` typically according to a
  `Glooper.Recipe` and then typically sold by `Glooper.Market`.
  """

  alias __MODULE__
  alias Glooper.Utils
  @enforce_keys [:name, :creator]
  @optional_keys [product_no: nil, components: [], recipe: nil, consumable: true]

  defstruct @enforce_keys ++ @optional_keys

  def create(init_args \\ []) do
    struct!(Product, init_args)
    |> init_product_no()
  end

  defp init_product_no(%Product{product_no: nil} = product),
    do: %{product | product_no: Utils.gen_product_no()}

  defp init_product_no(%Product{product_no: _} = product), do: product
end
