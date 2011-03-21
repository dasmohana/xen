include $(XEN_ROOT)/tools/Rules.mk

CC ?= gcc
OCAMLOPT ?= ocamlopt
OCAMLC ?= ocamlc
OCAMLMKLIB ?= ocamlmklib
OCAMLDEP ?= ocamldep
OCAMLLEX ?= ocamllex
OCAMLYACC ?= ocamlyacc

CFLAGS += -fPIC -Werror
CFLAGS += $(CFLAGS_xeninclude) $(CFLAGS_libxenctrl) $(CFLAGS_libxenstore) $(CFLAGS_libxenlight)
CFLAGS-$(CONFIG_Linux) += -I/usr/lib64/ocaml -I/usr/lib/ocaml
CFLAGS-$(CONFIG_NetBSD) += -I/usr/pkg/lib/ocaml -fPIC

OCAMLOPTFLAG_G := $(shell $(OCAMLOPT) -h 2>&1 | sed -n 's/^  *\(-g\) .*/\1/p')
OCAMLOPTFLAGS = $(OCAMLOPTFLAG_G) -ccopt "$(LDFLAGS)" -dtypes $(OCAMLINCLUDE) -cc $(CC) -w F -warn-error F
OCAMLCFLAGS += -g $(OCAMLINCLUDE) -w F -warn-error F

VERSION := 4.1

OCAMLDESTDIR ?= $(DESTDIR)$(shell ocamlfind printconf destdir)

o= >$@.new && mv -f $@.new $@
