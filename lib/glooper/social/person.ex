defmodule Glooper.Person do
  @moduledoc """
  A person is a someone that belongs to a population and contributes to a company
  like `Glooper.Factory` or `Glooper.Market`, and receive benefits from a
  `Glooper.Government` or pay taxes.
  """

  @enforce_keys [:person_no]
  @optional_keys [
    label: "Person",
    # Finance
    bank: "",
    account_no: "",

    # Purchase
    needs: %{}
  ]

  defstruct @enforce_keys ++ @optional_keys
end
