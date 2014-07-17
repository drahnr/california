data_desktopdir = $(datadir)/applications
data_desktop_in_files = data/california.desktop.in
data_desktop_DATA = $(data_desktop_in_files:.desktop.in=.desktop)

appdata_in_files = data/california.appdata.xml.in
appdata_files = $(appdata_in_files:.xml.in=.xml)

@INTLTOOL_XML_RULE@

data_appdatadir = $(datadir)/appdata
data_appdata_DATA = data/california.appdata.xml

gsettings_SCHEMAS = data/org.yorba.california.gschema.xml
@GSETTINGS_RULES@

# Local build of California's GSettings schema to allow executing from build dir
data/gschemas.compiled: data/org.yorba.california.gschema.xml
	@echo Building local GSettings schema...
	@glib-compile-schemas data/

BUILT_SOURCES += data/gschemas.compiled

EXTRA_DIST += \
	$(data_desktop_in_files) \
	$(appdata_in_files) \
	data/org.yorba.california.gschema.xml \
	$(NULL)

CLEANFILES += \
	$(data_desktop_DATA) \
	$(data_appdata_DATA) \
	data/gschemas.compiled \
	$(NULL)

DISTCLEANFILES += \
	$(data_desktop_DATA) \
	$(data_appdata_DATA) \
	$(NULL)

GITIGNOREFILES += \
	$(data_desktop_in_files) \
	$(data_appdata_DATA) \
	$(data_desktop_DATA) \
	$(NULL)
