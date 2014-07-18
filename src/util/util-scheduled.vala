/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California {

/**
 * Perform an asynchronous delay for the specified number of seconds.
*/
public async void sleep_sec_async(uint seconds) {
    uint id = Timeout.add_seconds(seconds, sleep_sec_async.callback);
    yield;
    Source.remove(id);
}

/**
 * Perform an asynchronous delay for the specified number of milliseconds.
*/
public async void sleep_msec_async(uint milliseconds) {
    uint id = Timeout.add(milliseconds, sleep_msec_async.callback);
    yield;
    Source.remove(id);
}

/**
 * A reference-counted source ID to better control execution of Idle and Timeout callbacks in the
 * event loop.
 *
 * Idle and Timeout provide "fire and forget" ways to schedule events to be executed later.
 * Cancelling those calls after scheduling them is easy to get wrong, since the returned uint (the
 * source ID) is invalid once the callback has been removed from the scheduler, which must be done
 * manually by the calling code.
 *
 * Scheduled manages the validity of the source ID.  It also simplifies writing delegates for the
 * callback (especially for the Idle case) to make it easier to write Vala anonoymous functions.
 *
 * Note that if the last reference to a Scheduled is dropped the callback will be cancelled if its
 * not already executed and continuous callbacks will halt.
 */

public class Scheduled : BaseObject {
    public const string PROP_IS_SCHEDULED = "is-scheduled";
    public const string PROP_IS_CONTINUOUS = "is-continuous";
    public const string PROP_IS_EXECUTING = "is-executing";
    
    /**
     * Return value for {@link ScheduleContinuous} indicating if the code should remain scheduled.
     */
    public enum Reschedule {
        AGAIN,
        HALT
    }
    
    /**
     * A callback when only scheduling code to execute once.
     */
    public delegate void ScheduleOnce();
    
    /**
     * A callback when scheduling code to execute continuously (between timeouts).
     */
    public delegate Reschedule ScheduleContinuous();
    
    /**
     * Returns true if the callback is still scheduled for execution.
     */
    public bool is_scheduled { get { return source_id != 0; } }
    
    /**
     * Returns true if the code is scheduled for continuous execution.
     *
     * May return true even if the code is no longer scheduled for execution.
     */
    public bool is_continuous { get { return schedule_continuous != null; } }
    
    /**
     * Returns true if the code is currently executing.
     *
     * Note: this is not thread-safe.
     */
    public bool is_executing { get; private set; default = false; }
    
    private uint source_id;
    private ScheduleOnce? schedule_once = null;
    private ScheduleContinuous? schedule_continuous = null;
    
    /**
     * Schedule code to execute continuously when the event loop is idle.
     */
    public Scheduled.continuous_at_idle(ScheduleContinuous cb, int priority = Priority.DEFAULT_IDLE) {
        schedule_continuous = cb;
        
        source_id = Idle.add(on_continuous, priority);
    }
    
    /**
     * Schedule code to execute once when the event loop is idle.
     */
    public Scheduled.once_at_idle(ScheduleOnce cb, int priority = Priority.DEFAULT_IDLE) {
        schedule_once = cb;
        
        source_id = Idle.add(on_once, priority);
    }
    
    /**
     * Schedule code to execute every n milliseconds.
     */
    public Scheduled.continuous_every_msec(uint msec, ScheduleContinuous cb, int priority = Priority.DEFAULT) {
        schedule_continuous = cb;
        
        source_id = Timeout.add(msec, on_continuous, priority);
    }
    
    /**
     * Schedule code to execute once after n milliseconds has elapsed.
     */
    public Scheduled.once_after_msec(uint msec, ScheduleOnce cb, int priority = Priority.DEFAULT) {
        schedule_once = cb;
        
        source_id = Timeout.add(msec, on_once, priority);
    }
    
    /**
     * Schedule code to execute after n seconds.
     */
    public Scheduled.continuous_every_sec(uint sec, ScheduleContinuous cb, int priority = Priority.DEFAULT) {
        schedule_continuous = cb;
        
        source_id = Timeout.add_seconds(sec, on_continuous, priority);
    }
    
    /**
     * Schedule code to execute once after n seconds have elapsed.
     */
    public Scheduled.once_after_sec(uint sec, ScheduleOnce cb, int priority = Priority.DEFAULT) {
        schedule_once = cb;
        
        source_id = Timeout.add_seconds(sec, on_once, priority);
    }
    
    ~Scheduled() {
        cancel();
    }
    
    /**
     * Cancel executing of scheduled code.
     *
     * Dropping the last reference to this object will also cancel execution.
     */
    public void cancel() {
        if (source_id == 0)
            return;
        
        Source.remove(source_id);
        source_id = 0;
    }
    
    /**
     * Wait for the scheduled code to execute.
     *
     * This waits for execution by spinning the event loop, which can cause reentrancy.  There is
     * also the danger of waiting for continuously executing code that never returns
     * {@link Reschedule.HALT}.  In that case, wait() will never return.
     *
     * If the scheduled code has been cancelled, is executing, or has already executed, wait()
     * immediately returns.
     */
    public void wait(MainContext main_context = MainContext.default()) {
        if (!is_scheduled || is_executing)
            return;
        
        while (main_context.pending())
            main_context.iteration(false);
    }
    
    private bool on_once() {
        is_executing = true;
        schedule_once();
        is_executing = false;
        
        // with once, this source func is never renewed
        source_id = 0;
        
        return false;
    }
    
    private bool on_continuous() {
        is_executing = true;
        Reschedule reschedule = schedule_continuous();
        is_executing = false;
        
        switch (reschedule) {
            case Reschedule.AGAIN:
                return true;
            
            case Reschedule.HALT:
                source_id = 0;
                
                return false;
            
            default:
                assert_not_reached();
        }
    }
    
    public override string to_string() {
        return "Scheduled %s:%u".printf(schedule_once != null ? "once" : "continuously", source_id);
    }
}

}
