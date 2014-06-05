/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View.Week {

internal class HourRunner : Pane {
    public const int REQUESTED_WIDTH = 50;
    
    private const Calendar.WallTime.PrettyFlag TIME_FLAGS =
        Calendar.WallTime.PrettyFlag.OPTIONAL_MINUTES;
    
    public HourRunner(Grid owner) {
        base (owner, REQUESTED_WIDTH);
        
        Calendar.System.instance.is_24hr_changed.connect(queue_draw);
    }
    
    ~HourRunner() {
        Calendar.System.instance.is_24hr_changed.disconnect(queue_draw);
    }
    
    // note that a painter's algorithm should be used here: background should be painted before
    // calling base method, and foreground afterward
    protected override bool on_draw(Cairo.Context ctx) {
        if (!base.on_draw(ctx))
            return false;
        
        int right_justify_px = get_allocated_width() - Palette.TEXT_MARGIN_PX;
        
        // draw hours in the border color
        Gdk.cairo_set_source_rgba(ctx, palette.border);
        
        // draw time-of-day down right-hand side of HourRunner pane, which acts as tick marks for
        // the rest of the week view
        Calendar.WallTime wall_time = Calendar.WallTime.earliest;
        for (;;) {
            Pango.Layout layout = create_pango_layout(wall_time.to_pretty_string(TIME_FLAGS));
            layout.set_font_description(palette.small_font);
            layout.set_width(right_justify_px);
            layout.set_alignment(Pango.Alignment.RIGHT);
            
            ctx.move_to(right_justify_px, get_text_y(wall_time));
            Pango.cairo_show_layout(ctx, layout);
            
            bool rollover;
            wall_time = wall_time.adjust(1, Calendar.TimeUnit.HOUR, out rollover);
            if (rollover)
                break;
        }
        
        return true;
    }
}

}

