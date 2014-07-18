/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Activator {

[GtkTemplate (ui = "/org/yorba/california/rc/google-authenticating.ui")]
public class GoogleAuthenticatingPane : Gtk.Grid, Toolkit.Card {
    public const string ID = "GoogleAuthenticatingPane";
    
    private const int SUCCESS_DELAY_MSEC = 1500;
    
    public class Message : BaseObject {
        public string username { get; private set; }
        public string password { get; private set; }
        
        public Message(string username, string password) {
            this.username = username;
            this.password = password;
        }
        
        public override string to_string() {
            return "Google:%s".printf(username);
        }
    }
    
    private static string? app_id = null;
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return again_button; } }
    
    public Gtk.Widget? initial_focus { get { return null; } }
    
    [GtkChild]
    private Gtk.Spinner spinner;
    
    [GtkChild]
    private Gtk.Label message_label;
    
    [GtkChild]
    private Gtk.Button cancel_button;
    
    [GtkChild]
    private Gtk.Button again_button;
    
    private Cancellable cancellable = new Cancellable();
    
    public GoogleAuthenticatingPane() {
        if (app_id == null)
            app_id = "yorba-california-%s".printf(Application.VERSION);
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        Message? credentials = message as Message;
        assert(credentials != null);
        
        cancel_button.sensitive = true;
        again_button.sensitive = false;
        
        cancellable = new Cancellable();
        login_async.begin(credentials);
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        // spinner's active property doubles as flag if async operation is in progress
        if (!spinner.active) {
            jump_home();
            
            return;
        }
        
        cancellable.cancel();
        cancel_button.sensitive = false;
    }
    
    [GtkCallback]
    private void on_again_button_clicked() {
        jump_back();
    }
    
    private async void login_async(Message credentials) {
        spinner.active = true;
        message_label.label = _("Authenticating…");
        
        GData.ClientLoginAuthorizer authorizer = new GData.ClientLoginAuthorizer(app_id,
            typeof(GData.CalendarService));
        authorizer.captcha_challenge.connect(uri => { debug("CAPTCHA required: %s", uri); return ""; } );
        
        try {
            if (!yield authorizer.authenticate_async(credentials.username, credentials.password, cancellable)) {
                login_failed(_("Unable to authenticate with Google Calendar service"));
                
                return;
            }
        } catch (Error err) {
            if (err is IOError.CANCELLED)
                login_cancelled();
            else if (err is GData.ClientLoginAuthorizerError.BAD_AUTHENTICATION)
                login_failed(_("Unable to authenticate: Incorrect account name or password"));
            else
                login_failed(_("Unable to authenticate: %s").printf(err.message));
            
            spinner.active = false;
            
            return;
        }
        
        GData.CalendarService calservice = new GData.CalendarService(authorizer);
        
        GData.Feed own_calendars;
        GData.Feed all_calendars;
        try {
            own_calendars = calservice.query_own_calendars(null, cancellable, null);
            all_calendars = calservice.query_all_calendars(null, cancellable, null);
        } catch (Error err) {
            if (err is IOError.CANCELLED)
                login_cancelled();
            else
                login_failed(_("Unable to retrieve calendar list: %s").printf(err.message));
            
            return;
        }
        
        spinner.active = false;
        message_label.label = _("Authenticated");
        
        // depending on network conditions, this pane can come and go quite quickly; this brief
        // delay gives the user a chance to see what's transpired
        yield sleep_msec_async(SUCCESS_DELAY_MSEC);
        
        jump_to_card_by_name(GoogleCalendarListPane.ID, new GoogleCalendarListPane.Message(
            credentials.username, own_calendars, all_calendars));
    }
    
    private void login_failed(string msg) {
        message_label.label = msg;
        spinner.active = false;
        again_button.sensitive = true;
    }
    
    private void login_cancelled() {
        spinner.active = false;
        jump_home();
    }
}

}

