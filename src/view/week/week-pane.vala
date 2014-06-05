/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View.Week {

internal abstract class Pane : Gtk.EventBox {
    public weak Grid owner { get; private set; }
    
    /**
     * {@link View.Palette} for the {@link Pane}.
     *
     * The palette should be associated with the Gtk.Window hosting the Pane.
     */
    public View.Palette palette { get; private set; }
    
    /**
     * The height of each "line" of text, including top and bottom padding
     */
    protected int line_height_px { get; private set; default = 0; }
    
    private int requested_width;
    private Gtk.DrawingArea canvas = new Gtk.DrawingArea();
    
    public Pane(Grid owner, int requested_width) {
        this.owner = owner;
        palette = owner.owner.palette;
        this.requested_width = requested_width;
        
        margin = 0;
        
        add(canvas);
        
        update_palette_metrics();
        palette.palette_changed.connect(on_palette_changed);
        
        canvas.draw.connect(on_draw);
    }
    
    ~Pane() {
        palette.palette_changed.disconnect(on_palette_changed);
    }
    
    private void update_palette_metrics() {
        // calculate the amount of space each "line" gets when drawing (normal font height plus
        // padding on top and bottom)
        line_height_px = palette.normal_font_height_px + (Palette.LINE_PADDING_PX * 2);
        
        // update the height request based on the number of lines needed to show the entire day
        canvas.set_size_request(requested_width, get_line_y(Calendar.WallTime.latest));
    }
    
    private void on_palette_changed() {
        update_palette_metrics();
        queue_draw();
    }
    
    protected virtual bool on_draw(Cairo.Context ctx) {
        int width = get_allocated_width();
        int height = get_allocated_height();
        
        // save and restore so child override doesn't have to deal with context state issues
        ctx.save();
        
        // draw right-side border line
        Palette.prepare_hairline(ctx, palette.border);
        ctx.move_to(width, 0);
        ctx.line_to(width, height);
        ctx.line_to(0, height);
        ctx.stroke();
        
        // draw hour and half-hour lines
        Calendar.WallTime wall_time = Calendar.WallTime.earliest;
        for(;;) {
            bool rollover;
            wall_time = wall_time.adjust(30, Calendar.TimeUnit.MINUTE, out rollover);
            if (rollover)
                break;
            
            int line_y = get_line_y(wall_time);
            
            // solid line on the hour, dashed on the half-hour
            if (wall_time.minute == 0)
                Palette.prepare_hairline(ctx, palette.border);
            else
                Palette.prepare_hairline_dashed(ctx, palette.border);
            
            ctx.move_to(0, line_y);
            ctx.line_to(width, line_y);
            ctx.stroke();
        }
        
        ctx.restore();
        
        return true;
    }
    
    /**
     * Returns the y (in pixels) for a particular line of text for the {@link Calendar.WallTime}.
     *
     * If displaying text, use {@link get_text_y}, as that will deduct padding.
     */
    public int get_line_y(Calendar.WallTime wall_time) {
        // every hour gets two "lines" of text
        int line_y = line_height_px * 2 * wall_time.hour;
        
        // break up space for each minute in the two lines per hour
        if (wall_time.minute != 0) {
            double fraction = (double) wall_time.minute / (double) Calendar.WallTime.MINUTES_PER_HOUR;
            double amt = (double) line_height_px * 2.0 * fraction;
            
            line_y += (int) Math.round(amt);
        }
        
        return line_y;
    }
    
    /**
     * Returns the y (in pixels) for the top of a line of text at {@link Calendar.WallTime}.
     *
     * Use this when displaying text.  Drawing lines, borders, etc. should use {@link get_line_y}.
     */
    public int get_text_y(Calendar.WallTime wall_time) {
        return get_line_y(wall_time) + Palette.LINE_PADDING_PX;
    }
    
    /**
     * Returns the {@link Calendar.WallTime} for a y-coordinate down to the minute;
     */
    public Calendar.WallTime get_wall_time(int y) {
        // every hour gets two "lines" of text
        int one_hour = line_height_px * 2;
        
        int hour = y / one_hour;
        int rem = y % one_hour;
        double min = ((double) rem / (double) one_hour) * 60.0;
        
        return new Calendar.WallTime(hour, (int) min, 0);
    }
}

}

