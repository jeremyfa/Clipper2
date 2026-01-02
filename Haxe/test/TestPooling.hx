package test;

import clipper.ClipperCore;
import clipper.ClipperEngine;
import clipper.ClipperOffset;
import clipper.ClipperPool;
import clipper.Clipper;

class TestPooling {
    public static var passed:Int = 0;
    public static var failed:Int = 0;

    public static function run():Void {
        trace("Testing Pooling...");

        // Clear any leftover state
        ClipperPool.clearPools();

        testBasicPooling();
        testPoolReuse();
        testTrackingWarning();
        testClipperOperationWithPooling();
        testInflateWithPooling();
        testMultipleSequentialOperations();

        trace("Pooling tests complete.");
    }

    public static function assertTrue(condition:Bool, msg:String):Void {
        if (condition) {
            passed++;
        } else {
            failed++;
            trace('FAILED: $msg');
        }
    }

    public static function assertEquals<T>(expected:T, actual:T, msg:String):Void {
        if (expected == actual) {
            passed++;
        } else {
            failed++;
            trace('FAILED: $msg - Expected $expected but got $actual');
        }
    }

    static function testBasicPooling():Void {
        // Test that tracking and recycling works
        ClipperPool.clearPools();

        assertTrue(!ClipperPool.isTracking(), "Not tracking initially");

        ClipperPool.trackObjects();
        assertTrue(ClipperPool.isTracking(), "Tracking after trackObjects()");

        // Create some points that will be tracked
        var p1 = Point64.get(100, 200);
        var p2 = Point64.get(300, 400);
        var pd1 = PointD.get(1.5, 2.5);

        ClipperPool.recycleObjects();
        assertTrue(!ClipperPool.isTracking(), "Not tracking after recycleObjects()");

        // Objects should now be in pool
        assertTrue(ClipperPool.getPoint64PoolSize() >= 2, "Point64 pool has objects");
        assertTrue(ClipperPool.getPointDPoolSize() >= 1, "PointD pool has objects");
    }

    static function testPoolReuse():Void {
        // Test that pooled objects are reused
        ClipperPool.clearPools();

        // First pass: create and recycle objects
        ClipperPool.trackObjects();
        var originalX:Int = 111;
        var originalY:Int = 222;
        var p1 = Point64.get(originalX, originalY);
        ClipperPool.recycleObjects();

        var poolSizeAfterRecycle = ClipperPool.getPoint64PoolSize();
        assertTrue(poolSizeAfterRecycle >= 1, "Pool has at least one object after recycle");

        // Second pass: create a new point - should reuse from pool
        ClipperPool.trackObjects();
        var p2 = Point64.get(333, 444);
        ClipperPool.recycleObjects();

        // Pool size should remain the same (reused one, then recycled it back)
        var poolSizeAfterSecondRecycle = ClipperPool.getPoint64PoolSize();
        assertTrue(poolSizeAfterSecondRecycle >= 1, "Pool still has objects after second recycle");

        // The point should have new values, not old ones
        ClipperPool.trackObjects();
        var p3 = Point64.get(555, 666);
        assertTrue(p3.x == 555, "Reused point has correct x value");
        assertTrue(p3.y == 666, "Reused point has correct y value");
        ClipperPool.recycleObjects();
    }

    static function testTrackingWarning():Void {
        // Test that calling trackObjects() while already tracking logs warning
        // (We can't easily test the warning output, but we can verify behavior)
        ClipperPool.clearPools();

        ClipperPool.trackObjects();
        assertTrue(ClipperPool.isTracking(), "Tracking after first call");

        // This should log a warning but still work
        ClipperPool.trackObjects();
        assertTrue(ClipperPool.isTracking(), "Still tracking after second call");

        ClipperPool.recycleObjects();
        assertTrue(!ClipperPool.isTracking(), "Not tracking after recycle");
    }

    static function testClipperOperationWithPooling():Void {
        // Test pooling with actual clipper operation
        ClipperPool.clearPools();

        // Create a simple polygon to clip
        var subject = new Paths64();
        var subjectPath = new Path64();
        subjectPath.push(Point64.get(0, 0));
        subjectPath.push(Point64.get(100, 0));
        subjectPath.push(Point64.get(100, 100));
        subjectPath.push(Point64.get(0, 100));
        subject.push(subjectPath);

        var clip = new Paths64();
        var clipPath = new Path64();
        clipPath.push(Point64.get(50, 50));
        clipPath.push(Point64.get(150, 50));
        clipPath.push(Point64.get(150, 150));
        clipPath.push(Point64.get(50, 150));
        clip.push(clipPath);

        // Perform intersection with pooling
        ClipperPool.trackObjects();

        var clipper = new Clipper64();
        clipper.addSubjectPaths(subject);
        clipper.addClipPaths(clip);

        var result = new Paths64();
        clipper.execute(ClipType.Intersection, FillRule.NonZero, result);

        // Copy the result data we need before recycling
        assertTrue(result.length == 1, "Intersection produced one path");
        var resultArea = InternalClipper.area(result[0]);
        assertTrue(resultArea > 0, "Result has positive area");

        ClipperPool.recycleObjects();

        // Verify pools have objects now
        assertTrue(ClipperPool.getPoint64PoolSize() > 0, "Point64 pool populated after clipper operation");
        assertTrue(ClipperPool.getVertexPoolSize() > 0, "Vertex pool populated after clipper operation");
    }

    static function testInflateWithPooling():Void {
        // Test pooling with inflate operation
        ClipperPool.clearPools();

        // Create a simple square
        var paths = new Paths64();
        var path = new Path64();
        path.push(Point64.get(0, 0));
        path.push(Point64.get(100, 0));
        path.push(Point64.get(100, 100));
        path.push(Point64.get(0, 100));
        paths.push(path);

        // Inflate with pooling
        ClipperPool.trackObjects();

        var result = Clipper.inflatePaths(paths, 10, JoinType.Miter, EndType.Polygon);

        assertTrue(result.length >= 1, "Inflate produced paths");

        // Copy data before recycling
        var resultPathCount = result.length;

        ClipperPool.recycleObjects();

        // Verify pools have objects
        assertTrue(ClipperPool.getPoint64PoolSize() > 0, "Pool populated after inflate");

        // Do another inflate - should reuse pooled objects
        var initialPoolSize = ClipperPool.getPoint64PoolSize();

        ClipperPool.trackObjects();
        var result2 = Clipper.inflatePaths(paths, 5, JoinType.Round, EndType.Polygon);
        ClipperPool.recycleObjects();

        // Pool should have similar or more objects (some reused, some new recycled)
        assertTrue(ClipperPool.getPoint64PoolSize() > 0, "Pool still has objects after second inflate");
    }

    static function testMultipleSequentialOperations():Void {
        // This test verifies that pooled objects are correctly reused across multiple
        // sequential operations without corruption (the Active.get() bug fix).
        ClipperPool.clearPools();

        // Create a simple square path for testing
        var paths = new Paths64();
        var path = new Path64();
        path.push(Point64.get(0, 0));
        path.push(Point64.get(100, 0));
        path.push(Point64.get(100, 100));
        path.push(Point64.get(0, 100));
        paths.push(path);

        // First operation
        ClipperPool.trackObjects();
        var result1 = Clipper.inflatePaths(paths, 10, JoinType.Miter, EndType.Polygon);
        assertTrue(result1.length > 0, "First inflate produces results");
        var result1PathCount = result1.length;
        ClipperPool.recycleObjects();

        var poolSize1 = ClipperPool.getPoint64PoolSize();
        assertTrue(poolSize1 > 0, "Pool populated after first operation");

        // Second operation - should reuse pooled objects
        ClipperPool.trackObjects();
        var result2 = Clipper.inflatePaths(paths, 5, JoinType.Round, EndType.Polygon);
        assertTrue(result2.length > 0, "Second inflate produces results");
        ClipperPool.recycleObjects();

        var poolSize2 = ClipperPool.getPoint64PoolSize();
        assertTrue(poolSize2 > 0, "Pool still has objects after second operation");

        // Third operation - verify no corruption (this would fail with the old Active.get() bug)
        ClipperPool.trackObjects();
        var result3 = Clipper.inflatePaths(paths, 15, JoinType.Bevel, EndType.Square);
        assertTrue(result3.length > 0, "Third inflate produces valid results (no corruption)");
        ClipperPool.recycleObjects();

        // Fourth operation with different parameters
        ClipperPool.trackObjects();
        var result4 = Clipper.inflatePaths(paths, 20, JoinType.Miter, EndType.Round);
        assertTrue(result4.length > 0, "Fourth inflate produces valid results");
        ClipperPool.recycleObjects();
    }
}
