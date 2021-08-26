alias Glooper.{Bank, Borrower, Simulation}

# Government, Factory, Market, Population

###############################################################################
#### Borrower POC - Config Example
###############################################################################
borrower_config = Toml.decode_file!("#{__DIR__}/examples/borrower.toml")

###############################################################################
#### Builder POC - Config Example
###############################################################################
builder_config = Toml.decode_file!("#{__DIR__}/examples/builder.toml")

###############################################################################
#### UBI 2 Products - Config Example
###############################################################################
ubi_config = Toml.decode_file!("#{__DIR__}/examples/ubi.toml")
