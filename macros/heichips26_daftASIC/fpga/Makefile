# SPDX-FileCopyrightText: 2026 The HeiChips Contributors
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Dispatcher: forwards every target to the chosen board's own Makefile
# (default: basys3). See ../README.md.

BOARD ?= basys3

.DEFAULT_GOAL := help

%:
	$(MAKE) -C design/$(BOARD) $@
