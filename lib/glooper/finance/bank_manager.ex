defmodule Glooper.BankManager do
  @moduledoc """
  The `Glooper.BankManager` module handles all basic bank functionality expected of a
  conventional retail bank running on double-entry bookkeeping through the means
  of `Glooper.GeneralLedger`, `Glooper.LoanBook` and `Glooper.TransactionLog`.
  """

  alias __MODULE__, as: BM
  alias Glooper.GeneralLedger, as: GL
  alias Glooper.LoanBook, as: LB
  alias Glooper.TransactionLog, as: TL
  alias Glooper.{Account, GBAN, Utils}

  @enforce_keys []
  @optional_keys [
    bank_no: nil,
    gl: %GL{},
    lb: %LB{},
    tl: %TL{}
  ]

  defstruct @enforce_keys ++ @optional_keys

  @doc """
  Creates a new bank and initializes the internals for basic banking like
  creating required ledgers etc.

  If `GeneralLedger`, `LoanBook` or `TransactionLog` are provided then they will
  be maintained as is and no initialization will take place.
  """
  def create(fields \\ []) do
    fields =
      fields
      # GeneralLedger
      |> Keyword.put(:gl, GL.create())
      # LoanBook
      |> Keyword.put(:lb, LB.create())
      # TransactionLog
      |> Keyword.put(:tl, TL.create())

    struct!(BM, fields)
  end

  #############################################################################
  #### Accounts
  #############################################################################

  @doc """
  Get customer deposit account for `acc_no`.
  """
  def get_customer_account(%BM{gl: gl}, acc_no) do
    GL.get_account(gl, "deposit", acc_no)
  end

  @doc """
  Get non-customer account matching `acc_no`.
  """
  def get_account(%BM{gl: gl}, acc_no) do
    GL.get_account(gl, acc_no)
  end

  @doc """
  Get customer deposit accounts for `customer_no`.
  """
  def get_accounts(%BM{gl: gl}, customer_no) do
    GL.get_accounts(gl, customer_no)
  end

  @doc """
  Open a customer deposit account for `customer_no` using a generated `acc_no`.
  """
  def open_account(bank, customer_no) do
    open_account(bank, customer_no, Utils.gen_account_no())
  end

  @doc """
  Open a customer deposit account for `customer_no` with desired `acc_no`.
  """
  def open_account(%BM{gl: gl} = bm, customer_no, acc_no) do
    case GL.add_account(gl, "deposit", acc_no, customer_no) do
      {:ok, gl} -> {:ok, %{bm | gl: gl}, acc_no}
      {:error, _} = err -> err
    end
  end

  @doc """
  Generate a fully qualified GBAN code for the given account.

  If the account exists in the bank then a valid GBAN string will be returned
  including `bank_no` and `acc_no`.
  """
  def get_account_gban(%BM{bank_no: bank_no} = bm, acc_no) do
    case get_account(bm, acc_no) do
      {:ok, _} -> {:ok, GBAN.generate(bank_no, acc_no)}
      {:error, _} = err -> err
    end
  end

  #############################################################################
  #### Transfers
  #############################################################################

  @doc """
  Deposit cash into a customer deposit account.
  """
  def deposit_cash(%BM{gl: gl, tl: tl} = bm, acc_no, amount, text \\ "Deposit cash", ts \\ -1) do
    with {:ok, gl} <- GL.transfer(gl, "cash", acc_no, amount),
         {:ok, tl, t} <- TL.add(tl, "cash", acc_no, amount, text, ts) do
      {:ok, %{bm | gl: gl, tl: tl}, t}
    else
      {:error, _} = err -> err
    end
  end

  @doc """
  Withdraw cash from a customer deposit account.
  """
  def withdraw_cash(%BM{} = bm, acc_no, amount, text \\ "Withdraw cash", ts \\ -1) do
    with {:ok, gl} <- GL.transfer(bm.gl, acc_no, "cash", amount),
         {:ok, tl, t} <- TL.add(bm.tl, acc_no, "cash", amount, text, ts) do
      {:ok, %{bm | gl: gl, tl: tl}, t}
    else
      {:error, _} = err -> err
    end
  end

  @doc """
  Transfer from one account to another.
  """
  def transfer(%BM{} = bm, from, to, amount, text \\ "Transfer", ts \\ -1) do
    with {:ok, gl} <- GL.transfer(bm.gl, from, to, amount),
         {:ok, tl, t} <- TL.add(bm.tl, from, to, amount, text, ts) do
      {:ok, %{bm | gl: gl, tl: tl}, t}
    else
      {:error, _} = err -> err
    end
  end

  #############################################################################
  #### Loans
  #############################################################################

  @doc """
  Returns true if a customer matching `customer_no` has any outstanding debt with
  the bank.
  """
  def has_debt?(%BM{lb: lb}, customer_no) do
    LB.has_debt?(lb, customer_no)
  end

  @doc """
  Request a loan to be paid out to account with `acc_no`.
  """
  def request_loan(
        %BM{} = bm,
        acc_no,
        amount,
        duration,
        rate \\ 0.05,
        frequency \\ 1,
        type \\ "compound",
        ts \\ -1
      ) do
    # 1. Figure out the customer from the account
    {:ok, %Account{customer_no: customer_no}} = GL.get_account(bm.gl, acc_no)

    # 2. Calculate the loan and add it to the loan book
    {:ok, {lb, loan_no}} =
      LB.add_loan(bm.lb, amount, rate, duration, frequency, type, customer_no, bm.bank_no)

    # 3. Transfer the loan amount in the general ledger
    {:ok, gl} = GL.transfer(bm.gl, "loan", acc_no, amount)

    # 4. Log the transaction in the transaction log
    {:ok, tl, t} = TL.add(bm.tl, "loan", acc_no, amount, "Loan #{loan_no}", ts)

    # 5. Update internal state and return
    {:ok, %{bm | lb: lb, gl: gl, tl: tl}, loan_no, t}
  end

  @doc """
  Gets the loan matching `loan_no`. Returns an error tuple if the loan is not
  found.
  """
  def get_loan(%BM{lb: lb}, loan_no) do
    LB.get_loan(lb, loan_no)
  end

  @doc """
  Returns all loans both paid and outstanding that belong to `customer_no`.
  """
  def get_loans(%BM{lb: lb}, customer_no) do
    LB.get_loans(lb, customer_no)
  end

  @doc """
  Returns a collection of outstanding loans and belong to `customer_no`.
  """
  def outstanding_loans(%BM{lb: lb}, customer_no) do
    LB.outstanding_loans(lb, customer_no)
  end

  @doc """
  Returns a collection of fully paid loans and belong to `customer_no`.
  """
  def paid_loans(%BM{lb: lb}, customer_no) do
    LB.paid_loans(lb, customer_no)
  end

  @doc """
  Finds the next payment for loan with `loan_no`.
  """
  def next_payment(%BM{lb: lb}, loan_no) do
    LB.next_payment(lb, loan_no)
  end

  @doc """
  Finds and transfers the next payment for loan with `loan_no`.

  If payment is found for the loan then two transactions are made for the loan
  principal and interest, respectively.
  """
  def make_next_payment(%BM{lb: lb, gl: gl, tl: tl} = bm, loan_no, acc_no, ts \\ -1) do
    with {:ok, p} <- LB.next_payment(lb, loan_no),
         # Pay loan interest
         {:ok, gl} <- GL.transfer(gl, acc_no, "interest_income", p.interest),
         {:ok, tl, t1} <-
           TL.add(tl, acc_no, "interest_income", p.interest, "#{loan_no}", ts),
         # Pay loan principal
         {:ok, gl} <- GL.transfer(gl, acc_no, "loan", p.principal),
         {:ok, tl, t2} <- TL.add(tl, acc_no, "loan", p.principal, "#{loan_no}", ts),
         # Mark payment as paid
         {:ok, lb} <- LB.make_payment(lb, loan_no, p.payment_no) do
      {:ok, %{bm | gl: gl, lb: lb, tl: tl}, [t1, t2]}
    else
      {:error, _} = err -> err
    end
  end

  #############################################################################
  #### Audit
  #############################################################################

  @doc """
  Performs a standard audit check on the bank's general ledger.

  If the general ledger can be balanced according to `asset = liability +
  equity` the function returns `true` otherwise `false`.
  """
  def audit(%BM{gl: gl}) do
    GL.audit(gl)
  end

  @doc """
  Fetch the total sum for ledger(s) matching `criteria`.

  The `criteria` can be either the label of the ledger or the account type as
  specified in `Glooper.account_types` e.g. "liability".
  """
  def ledger_total(%BM{gl: gl}, criteria) do
    GL.ledger_total(gl, criteria)
  end
end
