NULL =
GITIGNOREFILES =

# Build in these directories:

SUBDIRS = \
	src \
	po \
	$(NULL)

californiadocdir = ${prefix}/doc/california
californiadoc_DATA = \
	ChangeLog \
	README \
	COPYING \
	AUTHORS \
	INSTALL \
	NEWS\
	$(NULL)

EXTRA_DIST = \
	$(californiadoc_DATA) \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in\
	$(NULL)

BUILT_SOURCES =

CLEANFILES =

DISTCLEANFILES = \
	configure \
	config.guess \
	config.h.in \
	config.h.in~ \
	config.sub \
	intltool-extract \
	intltool-extract.in \
	intltool-merge \
	intltool-merge.in \
	intltool-update \
	intltool-update.in \
	Makefile.in \
	po/.intltool-merge-cache \
	$(NULL)

EXTRADIST = \
	autogen.sh \
	$(NULL)

GITIGNOREFILES += \
	*~ \
	.deps \
	.valencia \
	*_vala.stamp \
	Makefile \
	Makefile.in \
	Makefile.in.in \
	aclocal.m4 \
	autom4te.cache \
	compile \
	config/ \
	config.guess \
	config.h \
	config.h.in \
	config.log \
	config.status \
	config.sub \
	configure \
	depcomp \
	install-sh \
	intltool-extract.sh \
	intltool*.in \
	libtool \
	ltmain.sh \
	m4 \
	missing \
	stamp-it \
	stamp-h1 \
	po/POTFILES \
	vapi/libecal-1.2/libecal-1.2.gi \
	$(NULL)

devclean:
	$(MAKE) -C src devclean

include data/Makefile.am

@INTLTOOL_DESKTOP_RULE@

-include $(top_srcdir)/git.mk
