defmodule Glooper.Finance do
  @polarities %{"asset" => -1, "liability" => 1, "equity" => 1}
  @account_types ["asset", "equity", "liability"]
  @ledger_types ["capital", "cash", "deposit", "loan"]
  @loan_types ["simple", "compound", "indexed"]

  @doc """
  The polarities for individual account types in the system.
  """
  def polarities, do: @polarities

  @doc """
  The account types available in the system.
  """
  def account_types, do: @account_types

  @doc """
  The ledger types available in the system.
  """
  def ledger_types, do: @ledger_types

  @doc """
  The loan types available in the system.
  """
  def loan_types, do: @loan_types
end
