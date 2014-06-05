/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View {

/**
 * A "bag" of properties and constants holding colors and theme information for drawing the various
 * views to a particular Gtk.Window.
 *
 * TODO: Currently colors are hard-coded.  In the future we'll probably need to get these from the
 * system or the theme.
 */

public class Palette : BaseObject {
    /**
     * Margins around text (in pixels).
     */
    public const int TEXT_MARGIN_PX = 2;
    
    /**
     * Line padding when painting text (in pixels).
     */
    public const int LINE_PADDING_PX = 4;
    
    /**
     * Hairline line width.
     */
    public const double HAIRLINE_WIDTH = 0.5;
    
    /**
     * Dash pattern for Cairo.
     */
    public const double DASHES[] = { 1.0, 3.0 };
    
    /**
     * Minimum size (in points) of the {@link small_font}.
     */
    public const int MIN_SMALL_FONT_PTS = 7;
    
    /**
     * Maximum size (in points) of the {@link small_font}.
     */
    public const int MAX_SMALL_FONT_PTS = 14;
    
    /**
     * Default size (in points) of the {@link small_font}.
     *
     * This is also set in the GSettings schema file.
     */
    public const int DEFAULT_SMALL_FONT_PTS = 8;
    
    /**
     * Minimum size (in points) of the {@link normal_font}.
     */
    public const int MIN_NORMAL_FONT_PTS = 9;
    
    /**
     * Maximum size (in points) of the {@link normal_font}.
     */
    public const int MAX_NORMAL_FONT_PTS = 16;
    
    /**
     * Default size (in points) of the {@link normal_font}.
     *
     * This is also set in the GSettings schema file.
     */
    public const int DEFAULT_NORMAL_FONT_PTS = 11;
    
    /**
     * Border color (when separating days, for example).
     */
    public Gdk.RGBA border { get; private set; }
    
    /**
     * Color to use when drawing details of a day inside the current {@link View} range.
     *
     * @see day_outside_range
     */
    public Gdk.RGBA day_in_range { get; private set; }
    
    /**
     * Color to use when drawing details of a day outside the current {@link View} range.
     *
     * @see day_in_range
     */
    public Gdk.RGBA day_outside_range { get; private set; }
    
    /**
     * Background color for day representing current date.
     */
    public Gdk.RGBA current_day { get; private set; }
    
    /**
     * Foreground color representing current time of day.
     */
    public Gdk.RGBA current_time { get; private set; }
    
    /**
     * Background color to use for selected days/time.
     */
    public Gdk.RGBA selection { get; private set; }
    
    /**
     * Normal-sized font.
     *
     * In general this should be used sparingly, as most calendar views need to conserve screen
     * real estate and use {@link Host.ShowEvent} to display a greater amount of detail.
     *
     * @see small_font
     */
    public Pango.FontDescription normal_font;
    
    /**
     * Font height extent for {@link normal_font} (in pixels).
     *
     * This will be a negative value until the main window is mapped to the screen.
     *
     * @see main_window_mapped
     */
    public int normal_font_height_px { get; private set; default = -1; }
    
    /**
     * Small font.
     *
     * This is more appropriate than {@link normal_font} when displaying calendar information,
     * especially event detail.
     */
    public Pango.FontDescription small_font;
    
    /**
     * Font height extent for {@link small_font} (in pixels).
     *
     * This will be a negative value until the main window is mapped to the screen.
     *
     * @see main_window_mapped
     */
    public int small_font_height_px { get; private set; default = -1; }
    
    /**
     * Fired when palette has changed.
     *
     * It's generally simpler to subscribe to this signal rather than the "notify" for every
     * property.
     */
    public signal void palette_changed();
    
    private unowned Gtk.Window window;
    
    public Palette(Gtk.Window window) {
        this.window = window;
        
        border = { red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0 };
        day_in_range = { red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0 };
        day_outside_range = { red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0 };
        current_day = { red: 0.0, green: 0.25, blue: 0.50, alpha: 0.10 };
        current_time = { red: 1.0, green: 0.0, blue: 0.0, alpha: 0.90 };
        selection = { red: 0.0, green: 0.50, blue: 0.50, alpha: 0.10 };
        
        Settings.instance.notify[Settings.PROP_NORMAL_FONT_PTS].connect(on_normal_font_changed);
        Settings.instance.notify[Settings.PROP_SMALL_FONT_PTS].connect(on_small_font_changed);
        
        window.map.connect(on_window_mapped);
    }
    
    ~Palette() {
        Settings.instance.notify[Settings.PROP_NORMAL_FONT_PTS].disconnect(on_normal_font_changed);
        Settings.instance.notify[Settings.PROP_SMALL_FONT_PTS].disconnect(on_small_font_changed);
        
        window.map.disconnect(on_window_mapped);
    }
    
    // Font extents can only be determined when the window is mapped
    private void on_window_mapped() {
        on_normal_font_changed();
        on_small_font_changed();
        palette_changed();
    }
    
    private void on_normal_font_changed() {
        Pango.FontDescription? new_normal_font;
        int new_normal_height_px;
        if (!on_font_changed(Settings.instance.normal_font_pts, normal_font, normal_font_height_px,
            out new_normal_font, out new_normal_height_px)) {
            // nothing changed
            return;
        }
        
        normal_font = new_normal_font;
        normal_font_height_px = new_normal_height_px;
        
        palette_changed();
    }
    
    private void on_small_font_changed() {
        Pango.FontDescription? new_small_font;
        int new_small_height_px;
        if (!on_font_changed(Settings.instance.small_font_pts, small_font, small_font_height_px,
            out new_small_font, out new_small_height_px)) {
            // nothing changed
            return;
        }
        
        small_font = new_small_font;
        small_font_height_px = new_small_height_px;
        
        palette_changed();
    }
    
    private bool on_font_changed(int new_pts, Pango.FontDescription? current_font,
        int current_height_px, out Pango.FontDescription? new_font, out int new_height_px) {
        Pango.FontDescription font = new Pango.FontDescription();
        font.set_size(new_pts * Pango.SCALE);
        
        // if nothing changed, do nothing
        if (current_font != null && current_font.get_size() == font.get_size()) {
            new_font = current_font;
            new_height_px = current_height_px;
            
            return false;
        }
        
        new_font = font;
        new_height_px = get_height_extent(font);
        
        return true;
    }
    
    private int get_height_extent(Pango.FontDescription font) {
        Pango.Layout layout = window.create_pango_layout("Gg");
        layout.set_font_description(font);
        
        int width, height;
        layout.get_pixel_size(out width, out height);
        
        return height;
    }
    
    /**
     * Prepare a Cairo.Context for drawing hairlines.
     */
    public static Cairo.Context prepare_hairline(Cairo.Context ctx, Gdk.RGBA rgba) {
        Gdk.cairo_set_source_rgba(ctx, rgba);
        ctx.set_line_width(HAIRLINE_WIDTH);
        ctx.set_line_cap(Cairo.LineCap.ROUND);
        ctx.set_line_join(Cairo.LineJoin.ROUND);
        ctx.set_dash(null, 0);
        
        return ctx;
    }
    
    /**
     * Prepare a Cairo.Context for drawing hairline dashed lines.
     */
    public static Cairo.Context prepare_hairline_dashed(Cairo.Context ctx, Gdk.RGBA rgba) {
        Gdk.cairo_set_source_rgba(ctx, rgba);
        ctx.set_line_width(HAIRLINE_WIDTH);
        ctx.set_line_cap(Cairo.LineCap.ROUND);
        ctx.set_line_join(Cairo.LineJoin.ROUND);
        ctx.set_dash(DASHES, 0);
        
        return ctx;
    }
    
    public override string to_string() {
        return "View.Palette";
    }
}

}

