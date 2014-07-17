/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.UnitTest {

/**
 * Base class for suites of related tests.
 */

public abstract class Harness : BaseObject {
    public delegate bool Case(out string? dump = null) throws Error;
    
    private class TestCase : BaseObject {
        public string name;
        public unowned Case unit_test;
        
        public TestCase(string name, Case unit_test) {
            this.name = name;
            this.unit_test = unit_test;
        }
        
        public override string to_string() {
            return name;
        }
    }
    
    private static Gee.ArrayList<Harness>? harnesses = null;
    
    /**
     * Name of the {@link Harness}.
     */
    public string name { get; private set; }
    
    private Gee.ArrayList<TestCase> test_cases = new Gee.ArrayList<TestCase>();
    
    protected Harness(string? name = null) {
        this.name = name ?? get_class().get_type().name();
    }
    
    /**
     * Register a {@link Harness} to the total list of Harneses.
     */
    public static void register(Harness harness) {
        if (harnesses == null)
            harnesses = new Gee.ArrayList<Harness>();
        
        harnesses.add(harness);
    }
    
    /**
     * Execute all {@link register}ed {@link Harness}es.
     */
    public static int exec_all() {
        if (harnesses == null || harnesses.size == 0)
            return 0;
        
        foreach (Harness harness in harnesses) {
            try {
                harness.setup();
            } catch (Error err) {
                stdout.printf("Unable to setup harness %s: %s", harness.name, err.message);
                Posix.exit(Posix.EXIT_FAILURE);
            }
            
            harness.exec();
            harness.teardown();
        }
        
        return 0;
    }
    
    /**
     * Executed before running any test cases.
     */
    protected abstract void setup() throws Error;
    
    /**
     * Executed after all test cases have completed.
     */
    protected abstract void teardown();
    
    /**
     * Executed prior to each test case.
     */
    protected virtual void prepare() throws Error {
    }
    
    /**
     * Executed after each test case.
     */
    protected virtual void cleanup() {
    }
    
    /**
     * Add a test case to the {@link Harness}.
     */
    protected void add_case(string name, Case unit_test) {
        test_cases.add(new TestCase(name, unit_test));
    }
    
    private void exec() {
        foreach (TestCase test_case in test_cases) {
            stdout.printf("Executing test: %s.%s...", name, test_case.name);
            
            try {
                prepare();
            } catch (Error err) {
                stdout.printf("prepare failed: %s\n", err.message);
                Posix.exit(Posix.EXIT_FAILURE);
            }
            
            bool success = false;
            string? dump = null;
            Error? err = null;
            try {
                success = test_case.unit_test(out dump);
            } catch (Error caught) {
                err = caught;
            }
            
            if (err != null)
                stdout.printf("failed (thrown error):\n\t\"%s\"\n", err.message);
            else if (!success)
                stdout.printf("failed (test):\n");
            
            if ((err != null || !success) && !String.is_empty(dump))
                stdout.printf("%s\n", dump);
            
            if (err != null || !success)
                Posix.exit(Posix.EXIT_FAILURE);
            
            cleanup();
            
            stdout.printf("success\n");
        }
    }
    
    public override string to_string() {
        return name;
    }
}

}

