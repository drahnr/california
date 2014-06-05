/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

extern const string PACKAGE_VERSION;
extern const string GETTEXT_PACKAGE;
extern const string PREFIX;

namespace California {

/**
 * The main California application object.
 */

public class Application : Gtk.Application {
    public const string TITLE = _("California");
    public const string DESCRIPTION = _("GNOME 3 Calendar");
    public const string COPYRIGHT = _("Copyright 2014 Yorba Foundation");
    public const string VERSION = PACKAGE_VERSION;
    public const string WEBSITE_NAME = _("Visit California's home page");
    public const string WEBSITE_URL = "https://wiki.gnome.org/Apps/California";
    public const string BUGREPORT_URL = "https://bugzilla.gnome.org/enter_bug.cgi?product=california";
    public const string ID = "org.yorba.california";
    public const string ICON_NAME = "x-office-calendar";
    
    public const string AUTHORS[] = {
        "Jim Nelson <jim@yorba.org>",
        null
    };
    
    // public application menu actions; note their "app." prefix which does not
    // match the actions in the action_entries table
    public const string DETAILED_ACTION_NEW_CALENDAR = "app.new-calendar";
    public const string ACTION_NEW_CALENDAR = "new-calendar";
    
    public const string DETAILED_ACTION_CALENDAR_MANAGER = "app.calendar-manager";
    public const string ACTION_CALENDAR_MANAGER = "calendar-manager";
    
    public const string DETAILED_ACTION_ABOUT = "app.about";
    public const string ACTION_ABOUT = "about";
    
    public const string DETAILED_ACTION_QUIT = "app.quit";
    public const string ACTION_QUIT = "quit";
    
    // internal actions; no "app." prefix
    private const string ACTION_PROCESS_FILE = "process-file";
    
    private static Application? _instance = null;
    public static Application instance {
        get {
            return (_instance != null) ? _instance : _instance = new Application();
        }
    }
    
    private static const ActionEntry[] action_entries = {
        // public actions
        { ACTION_NEW_CALENDAR, on_new_calendar },
        { ACTION_CALENDAR_MANAGER, on_calendar_manager },
        { ACTION_ABOUT, on_about },
        { ACTION_QUIT, on_quit },
        
        // internal
        { ACTION_PROCESS_FILE, on_process_file, "s" }
    };
    
    /**
     * The executable's location on the filesystem.
     *
     * This will be null until {@link local_command_line} is executed.
     */
    public File? exec_file { get; private set; default = null; }
    
    /**
     * The executable's parent directory on the filesystem.
     *
     * This will be null until {@link local_command_line} is executed.
     */
    public File? exec_dir { owned get { return (exec_file != null) ? exec_file.get_parent() : null; } }
    
    /**
     * The configured prefix directory as a File.
     */
    public File prefix_dir { owned get { return File.new_for_path(PREFIX); } }
    
    /**
     * Whether or not the running executable is the installed executable (if installed at all).
     *
     * False if {@link local_command_line} hasn't executed yet.
     */
    public bool is_installed {
        get {
            return (exec_dir != null) ? exec_dir.has_prefix(prefix_dir) : false;
        }
    }
    
    /**
     * If not installed, returns the root of the build directory (which may not be the location
     * of the main executable).
     *
     * null if {@link is_installed} is true.
     */
    public File? build_root_dir {
        owned get {
            // currently the build system stores the exec in the src/ directory
            return (!is_installed && exec_dir != null) ? exec_dir.get_parent() : null;
        }
    }
    
    private Host.MainWindow? main_window = null;
    
    private Application() {
        Object (application_id: ID);
    }
    
    // This method is executed from run() every time.
    public override bool local_command_line(ref unowned string[] args, out int exit_status) {
        exec_file = File.new_for_path(Posix.realpath(Environment.find_program_in_path(args[0])));
        
        // process arguments now, prior to register and activate; if true is returned before that,
        // the application will exit with the exit code
        if (!Commandline.parse(args, out exit_status))
            return true;
        
        try {
            register();
        } catch (Error err) {
            error("Error registering application: %s", err.message);
        }
        
        activate();
        
        // tell the primary instance (which this instance may not be) about the command-line options
        // it should act upon
        if (Commandline.files != null) {
            foreach (string file in Commandline.files)
                activate_action(ACTION_PROCESS_FILE, file);
        }
        
        exit_status = 0;
        
        return true;
    }
    
    // This method is invoked when the primary instance is first started.
    public override void startup() {
        base.startup();
        
        // prep gettext before initialize various units
        Intl.setlocale(LocaleCategory.ALL, "");
        Intl.bindtextdomain(GETTEXT_PACKAGE,
            File.new_for_path(PREFIX).get_child("share").get_child("locale").get_path());
        Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain(GETTEXT_PACKAGE);
        
        // unit initialization
        try {
            Settings.init();
            Host.init();
            Manager.init();
            Activator.init();
        } catch (Error err) {
            error_message(_("Unable to open California: %s").printf(err.message));
            quit();
        }
        
        add_action_entries(action_entries, this);
        set_app_menu(Resource.load<MenuModel>("app-menu.interface", "app-menu"));
    }
    
    // This method is invoked when the main loop terminates on the primary instance.
    public override void shutdown() {
        main_window.destroy();
        main_window = null;
        
        // unit termination
        Activator.terminate();
        Manager.terminate();
        Host.terminate();
        Settings.terminate();
        
        base.shutdown();
    }
    
    // This method is invoked when the primary instance is first started or is activated by a
    // secondary instance.  It is called after startup().
    public override void activate() {
        if (main_window == null) {
            main_window = new Host.MainWindow(this);
            main_window.show_all();
        }
        
        main_window.present();
        
        base.activate();
    }
    
    /*
     * Presents a modal error dialog to the user.
     */
    public void error_message(string msg) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog(main_window, Gtk.DialogFlags.MODAL,
            Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, "%s", msg);
        dialog.run();
        dialog.destroy();
    }
    
    private void on_new_calendar() {
        Activator.Window.display(main_window);
    }
    
    private void on_calendar_manager() {
        Manager.Window.display(main_window);
    }
    
    private void on_process_file(SimpleAction action, Variant? variant) {
        if (variant == null)
            return;
        
        // TODO: Support URIs
        File file = File.new_for_commandline_arg((string) variant);
        if (!file.is_native() || file.get_path() == null)
            return;
        
        Component.iCalendar ical;
        try {
            MappedFile mmap = new MappedFile(file.get_path(), false);
            ical = Component.iCalendar.parse((string) mmap.get_contents());
        } catch (Error err) {
            message("Unable to add %s: %s", file.get_path(), err.message);
            
            return;
        }
        
        debug("Parsed %s", ical.to_string());
        
        // Ask the user to select a calendar to import it into
        main_window.present_with_time(Gdk.CURRENT_TIME);
        Host.ImportCalendar importer = new Host.ImportCalendar(main_window, ical);
        Gtk.ResponseType response_type = (Gtk.ResponseType) importer.run();
        importer.destroy();
        
        if (response_type != Gtk.ResponseType.OK || importer.chosen == null)
            return;
        
        importer.chosen.import_icalendar_async.begin(ical, null, on_import_completed);
    }
    
    private void on_import_completed(Object? object, AsyncResult result) {
        Backing.CalendarSource calendar_source = (Backing.CalendarSource) object;
        try {
            calendar_source.import_icalendar_async.end(result);
        } catch (Error err) {
            debug("Unable to import iCalendar: %s", err.message);
        }
    }
    
    private void on_about() {
        Gtk.show_about_dialog(main_window,
            "program-name", TITLE,
            "comments", DESCRIPTION,
            "authors", AUTHORS,
            "copyright", COPYRIGHT,
            "license-type", Gtk.License.LGPL_2_1,
            "version", VERSION,
            "title", _("About %s").printf(TITLE),
            "logo-icon-name", ICON_NAME,
            "website", WEBSITE_URL,
            "website-label", WEBSITE_NAME,
            // Translators: add your name and email address to receive credit in the About dialog
            // For example: Yamada Taro <yamada.taro@example.com>
            "translator-credits", _("translator-credits")
        );
    }
    
    private void on_quit() {
        quit();
    }
}

}

