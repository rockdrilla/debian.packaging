#!/usr/bin/make -f
# SPDX-License-Identifier: BSD-3-Clause
# (c) 2020, Konstantin Demin

## simple template expansion snippet
## it expands variables enclosed within '%' in files and renames files accordingly

## example is taken from my nginx package (work-in-progress for now):
##   find in debian/ directory files named '*.in' or '*NGX*'
##   replace 'NGX' in name with source package name (usually 'nginx', but... ;) )
##   strip '.in' suffix from file name
##   expand variables in source file and save it in destination file

## change next two lines appropriately for your case
deb_control_templates +=$(wildcard debian/*.in debian/*NGX*)
deb_template_rename =$(patsubst %.in,%,$(subst NGX,$(DEB_SOURCE),$(strip $(1))))

define deb_recipe =

$(strip $(1)): $(strip $(2))


endef

deb_templates +=$(deb_control_templates)

deb_control_files =$(foreach f,$(sort $(deb_control_templates)),$(call deb_template_rename,$(f)))

deb_files =$(foreach f,$(sort $(deb_templates)),$(call deb_template_rename,$(f)))

deb_safe_var_rx :=^[a-zA-Z][a-zA-Z0-9_]+$$
deb_safe_vars =$(shell echo '$(.VARIABLES)' | tr -s ' ' '\n' | grep -E '$(deb_safe_var_rx)')

$(foreach f,$(sort $(deb_templates)),$(eval \
    $(call deb_recipe, $(call deb_template_rename,$(f)), $(f) ) \
))

deb_grep_var =$(findstring %$(2)%,$(file < $(1)))
deb_repl_var =$(file > $(1),$(subst %$(2)%,$($(2)),$(file < $(1))))

## deb_process_inplace() and deb_process_template() share same api:
##   deb_process_*(source,destination)
## but deb_process_inplace() doesn't interact with 'source' argument at all.
## this may be useful in case where source file is destination file too,
## i.e. just process variables within it without need to rename.

## TODO: add appropriate example for deb_process_inplace() usage.
## (i just lost it in flow of space and time)

define deb_process_inplace =
    $(foreach v/v,$(deb_safe_vars),                     \
        $(if $(call deb_grep_var,$(strip $(2)),$(v/v)), \
            $(call deb_repl_var,$(strip $(2)),$(v/v))   \
    ) )
endef

define deb_process_template =
    $(shell cp -af '$(strip $(1))' '$(strip $(2))')
    $(call deb_process_inplace,$(1),$(2))
    $(shell touch -m -r '$(strip $(1))' '$(strip $(2))')
endef

$(deb_files):
	$(call deb_process_template,$(<),$(@))

## deb_control_files is list of (renamed) files which are needed by debhelper
## at least, debian/control must be here (if it's templated one)

clean: $(deb_control_files)

## uncomment following lines if this is your case

# override_dh_clean: $(deb_control_files)

## deb_files is list of (renamed) files which are generally needed by build
## e.g. configs, wrappers for real binaries, et cetera

# build binary: $(deb_files)

## note: you can add manually files to deb_files list and provide custom renaming scheme
## example:
##
## debian/tmp/superb.conf: debian/configs/superb.in
##
## deb_files +=debian/tmp/superb.conf
