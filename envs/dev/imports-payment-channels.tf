# ---------------------------------------------------------------------------
# Adopting the twelve payment-channel parameters that already exist
# ---------------------------------------------------------------------------
#
# They were created by hand with `aws ssm put-parameter` during G3, on
# 6 September, and have never been in terraform state. Without these blocks the
# plan calls them **creates**, because from terraform's point of view they do not
# exist - and a plan is a diff against state, not against reality.
#
# That matters for one specific reason. `lifecycle { ignore_changes = [value] }`
# on those resources protects a value from *subsequent* applies; it does nothing
# on a first create, where `overwrite = true` writes the declared value straight
# over the live one. So without importing:
#
#   - anybody correcting a bank account number between this plan and the apply
#     would have that correction silently reverted, and
#   - the plan would say nothing about it, because it has nothing to compare to.
#
# The declared values and the live ones were compared with
# `aws ssm get-parameters-by-path --with-decryption` and matched exactly, in
# value and in type (SecureString), at the time this branch was written. The
# import blocks are here so that the apply stays correct **even if that stops
# being true before Visquis runs it** - which is precisely the window a
# correction would land in.
#
# The same near-miss already happened once on type: G10's first draft declared
# these as `String` while the live ones are `SecureString`, and the plan showed
# twelve clean creations and warned about nothing. Comparing by hand caught it.
#
# The four per-operator parameters (ORANGE_MONEY_*, MTN_MONEY_*) are NOT imported:
# they do not exist yet and are genuine creates.
#
# **Remove this file after the apply.** Once the twelve are in state the blocks
# are inert, and a leftover import block is a thing the next reader has to work
# out the meaning of.

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["BANK_NAME"]
  id = "/kambriq/${var.env}/api/payment-channels/BANK_NAME"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["BANK_ACCOUNT_NAME"]
  id = "/kambriq/${var.env}/api/payment-channels/BANK_ACCOUNT_NAME"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["BANK_IBAN"]
  id = "/kambriq/${var.env}/api/payment-channels/BANK_IBAN"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["BANK_SWIFT"]
  id = "/kambriq/${var.env}/api/payment-channels/BANK_SWIFT"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["MOBILE_MONEY_OPERATOR"]
  id = "/kambriq/${var.env}/api/payment-channels/MOBILE_MONEY_OPERATOR"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["MOBILE_MONEY_NUMBER"]
  id = "/kambriq/${var.env}/api/payment-channels/MOBILE_MONEY_NUMBER"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["MOBILE_MONEY_NAME"]
  id = "/kambriq/${var.env}/api/payment-channels/MOBILE_MONEY_NAME"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["NOTARY_NAME"]
  id = "/kambriq/${var.env}/api/payment-channels/NOTARY_NAME"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["NOTARY_PHONE"]
  id = "/kambriq/${var.env}/api/payment-channels/NOTARY_PHONE"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["NOTARY_ADDRESS"]
  id = "/kambriq/${var.env}/api/payment-channels/NOTARY_ADDRESS"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["SUPPORT_EMAIL"]
  id = "/kambriq/${var.env}/api/payment-channels/SUPPORT_EMAIL"
}

import {
  to = module.ssm_app_parameters.aws_ssm_parameter.payment_channels["SUPPORT_PHONE"]
  id = "/kambriq/${var.env}/api/payment-channels/SUPPORT_PHONE"
}
