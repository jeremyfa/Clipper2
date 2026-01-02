package test;


import clipper.ClipperCore;
import clipper.ClipperEngine;
import clipper.ClipperOffset;
import clipper.ClipperRectClip;
import clipper.ClipperMinkowski;
import clipper.ClipperTriangulation;
import clipper.Clipper;
import test.TestPooling;

class TestRunner {
    static var passed:Int = 0;
    static var failed:Int = 0;

    public static function main():Void {
        trace("Running Clipper2 Haxe Tests...\n");

        testInt64();
        testPoint64();
        testPointD();
        testRect64();
        testRectD();
        testInternalClipper();
        testClipper64();
        testClipperOffset();
        testRectClip();
        testMinkowski();
        testTriangulation();
        testClipperHighLevelAPI();
        testPooling();

        trace('\n=== Test Summary ===');
        trace('Passed: $passed');
        trace('Failed: $failed');
        trace('Total: ${passed + failed}');

        #if sys
        Sys.exit(failed > 0 ? 1 : 0);
        #end
    }

    static function assertTrue(condition:Bool, msg:String):Void {
        if (condition) {
            passed++;
        } else {
            failed++;
            trace('FAILED: $msg');
        }
    }

    static function assertEquals<T>(expected:T, actual:T, msg:String):Void {
        if (expected == actual) {
            passed++;
        } else {
            failed++;
            trace('FAILED: $msg - Expected $expected but got $actual');
        }
    }

    static function testInt64():Void {
        trace("Testing ClipperInt64...");

        // === Construction & Conversion ===

        // ofInt
        var zero:ClipperInt64 = 0;
        var pos:ClipperInt64 = 100;
        var neg:ClipperInt64 = -100;
        assertTrue(zero == 0, "ofInt zero");
        assertTrue(pos == 100, "ofInt positive");
        assertTrue(neg == -100, "ofInt negative");

        // fromFloat - must truncate towards zero (not store fractional values)
        var fromF = ClipperInt64.fromFloat(123.7);
        assertTrue(!Math.isNaN(fromF.toFloat()), "fromFloat not NaN");
        assertTrue(fromF.toFloat() == 123.0, "fromFloat truncates positive");
        var fromFNeg = ClipperInt64.fromFloat(-123.7);
        assertTrue(fromFNeg.toFloat() == -123.0, "fromFloat truncates negative towards zero");
        var fromFExact = ClipperInt64.fromFloat(456.0);
        assertTrue(fromFExact.toFloat() == 456.0, "fromFloat preserves exact integers");
        // Test with values that caused infinite loop bug (fractional coordinates)
        var fracVal = ClipperInt64.fromFloat(14683544.942772454);
        assertTrue(fracVal.toFloat() == 14683544.0, "fromFloat truncates fractional coordinate");

        // make(high, low)
        var made = ClipperInt64.make(0, 100);
        assertTrue(made == 100, "make(0, 100)");
        assertTrue(!Math.isNaN(made.toFloat()), "make not NaN");

        var madeNegLow = ClipperInt64.make(0, -1);
        assertTrue(!Math.isNaN(madeNegLow.toFloat()), "make with negative low not NaN");

        // toFloat round-trip
        var val:ClipperInt64 = 12345;
        assertTrue(val.toFloat() == 12345.0, "toFloat accuracy");

        // toInt
        var bigVal:ClipperInt64 = 100;
        assertTrue(bigVal.toInt() == 100, "toInt");

        // === Arithmetic - Basic ===

        var a:ClipperInt64 = 100;
        var b:ClipperInt64 = 50;

        assertTrue(a + b == 150, "Int64 addition");
        assertTrue(a - b == 50, "Int64 subtraction");
        assertTrue(a * b == 5000, "Int64 multiplication");
        assertTrue(a / b == 2, "Int64 division");

        // === Arithmetic - Division Edge Cases ===

        var one:ClipperInt64 = 1;
        var negOne:ClipperInt64 = -1;
        var zeroVal:ClipperInt64 = 0;

        // Normal division
        assertTrue(a / one == 100, "100 / 1 = 100");
        assertTrue(a / negOne == -100, "100 / -1 = -100");

        // Note: Division/modulo by zero is undefined behavior
        // - Float mode: div by zero → Infinity, mod by zero → NaN
        // - Int64 mode: throws exception
        // We skip these tests as they're platform-dependent

        // === Arithmetic - Modulo Edge Cases ===

        assertTrue(a % b == 0, "100 % 50 = 0");
        var a1:ClipperInt64 = 101;
        assertTrue(a1 % b == 1, "101 % 50 = 1");

        // Negative modulo
        var negMod = neg % b;
        assertTrue(!Math.isNaN(negMod.toFloat()), "Negative modulo not NaN");

        // === getHigh / getLow ===

        var testVal:ClipperInt64 = 100;
        var highPart = testVal.getHigh();
        var lowPart = testVal.getLow();
        assertTrue(highPart == 0, "getHigh for small value");
        assertTrue(lowPart == 100, "getLow for small value");

        var negVal:ClipperInt64 = -100;
        var negHigh = negVal.getHigh();
        var negLow = negVal.getLow();
        // Check they don't return NaN-like values (NaN != NaN)
        assertTrue(negHigh == negHigh, "getHigh for negative not NaN");
        assertTrue(negLow == negLow, "getLow for negative not NaN");

        // === abs ===

        assertTrue(pos.abs() == 100, "abs positive");
        assertTrue(neg.abs() == 100, "abs negative");
        assertTrue(zero.abs() == 0, "abs zero");

        // === min / max ===

        assertTrue(ClipperInt64.min(a, b) == 50, "min(100, 50)");
        assertTrue(ClipperInt64.max(a, b) == 100, "max(100, 50)");
        assertTrue(ClipperInt64.min(a, a) == 100, "min equal values");
        assertTrue(ClipperInt64.max(neg, pos) == 100, "max with negative");

        // === triSign ===

        assertTrue(pos.triSign() == 1, "triSign positive");
        assertTrue(neg.triSign() == -1, "triSign negative");
        assertTrue(zero.triSign() == 0, "triSign zero");

        // === roundFromFloat ===

        var rounded1 = ClipperInt64.roundFromFloat(2.4);
        var rounded2 = ClipperInt64.roundFromFloat(2.5);
        var rounded3 = ClipperInt64.roundFromFloat(2.6);
        var rounded4 = ClipperInt64.roundFromFloat(-2.5);

        assertTrue(!Math.isNaN(rounded1.toFloat()), "roundFromFloat 2.4 not NaN");
        assertTrue(rounded1 == 2, "roundFromFloat 2.4 = 2");
        assertTrue(rounded2 == 3, "roundFromFloat 2.5 = 3 (away from zero)");
        assertTrue(rounded3 == 3, "roundFromFloat 2.6 = 3");
        assertTrue(rounded4 == -3, "roundFromFloat -2.5 = -3 (away from zero)");

        // === roundEvenFromFloat (banker's rounding) ===

        var even1 = ClipperInt64.roundEvenFromFloat(2.5);
        var even2 = ClipperInt64.roundEvenFromFloat(3.5);
        var even3 = ClipperInt64.roundEvenFromFloat(4.5);

        assertTrue(!Math.isNaN(even1.toFloat()), "roundEvenFromFloat 2.5 not NaN");
        assertTrue(even1 == 2, "roundEvenFromFloat 2.5 = 2 (to even)");
        assertTrue(even2 == 4, "roundEvenFromFloat 3.5 = 4 (to even)");
        assertTrue(even3 == 4, "roundEvenFromFloat 4.5 = 4 (to even)");

        // === Comparison operators ===

        assertTrue(a > b, "Int64 greater than");
        assertTrue(b < a, "Int64 less than");
        assertTrue(a >= 100, "Int64 greater than or equal");
        assertTrue(b <= 50, "Int64 less than or equal");
        assertTrue(a == 100, "100 == 100");
        assertTrue(a != 99, "100 != 99");

        // Negative numbers
        var c:ClipperInt64 = -100;
        assertTrue(c < 0, "Int64 negative less than zero");
        assertTrue(InternalClipper.abs64(c) == 100, "Int64 abs via InternalClipper");

        trace("ClipperInt64 tests complete.");
    }

    static function testPoint64():Void {
        trace("Testing Point64...");

        var p1 = new Point64(100, 200);
        var p2 = new Point64(50, 100);

        // Basic properties
        assertTrue(p1.x == 100, "Point64 x");
        assertTrue(p1.y == 200, "Point64 y");

        // Addition
        var sum = p1 + p2;
        assertTrue(sum.x == 150, "Point64 addition x");
        assertTrue(sum.y == 300, "Point64 addition y");

        // Subtraction
        var diff = p1 - p2;
        assertTrue(diff.x == 50, "Point64 subtraction x");
        assertTrue(diff.y == 100, "Point64 subtraction y");

        // Equality
        var p3 = new Point64(100, 200);
        assertTrue(p1 == p3, "Point64 equality");
        assertTrue(p1 != p2, "Point64 inequality");

        // Copy
        var p4 = Point64.copy(p1);
        assertTrue(p4 == p1, "Point64 copy equality");

        trace("Point64 tests complete.");
    }

    static function testPointD():Void {
        trace("Testing PointD...");

        var p1 = new PointD(100.5, 200.5);
        var p2 = new PointD(50.0, 100.0);

        // Basic properties
        assertTrue(Math.abs(p1.x - 100.5) < 0.001, "PointD x");
        assertTrue(Math.abs(p1.y - 200.5) < 0.001, "PointD y");

        // Equality with tolerance
        var p3 = new PointD(100.5 + 1e-15, 200.5 + 1e-15);
        assertTrue(p1 == p3, "PointD equality with tolerance");

        trace("PointD tests complete.");
    }

    static function testRect64():Void {
        trace("Testing Rect64...");

        var rect = new Rect64(10, 20, 110, 220);

        assertTrue(rect.width == 100, "Rect64 width");
        assertTrue(rect.height == 200, "Rect64 height");
        assertTrue(!rect.isEmpty(), "Rect64 not empty");

        // Contains point
        var inside = new Point64(50, 100);
        var outside = new Point64(5, 10);
        assertTrue(rect.contains(inside), "Rect64 contains inside point");
        assertTrue(!rect.contains(outside), "Rect64 does not contain outside point");

        // Invalid rect
        var invalid = Rect64.createInvalid();
        assertTrue(!invalid.isValid(), "Rect64 invalid");

        trace("Rect64 tests complete.");
    }

    static function testRectD():Void {
        trace("Testing RectD...");

        var rect = new RectD(10.0, 20.0, 110.0, 220.0);

        assertTrue(Math.abs(rect.width - 100.0) < 0.001, "RectD width");
        assertTrue(Math.abs(rect.height - 200.0) < 0.001, "RectD height");
        assertTrue(!rect.isEmpty(), "RectD not empty");

        trace("RectD tests complete.");
    }

    static function testInternalClipper():Void {
        trace("Testing InternalClipper...");

        // Cross product
        var pt1 = new Point64(0, 0);
        var pt2 = new Point64(10, 0);
        var pt3 = new Point64(10, 10);
        var cross = InternalClipper.crossProduct(pt1, pt2, pt3);
        assertTrue(cross > 0, "CrossProduct positive");

        // Collinear check
        var pt4 = new Point64(5, 0);
        assertTrue(InternalClipper.isCollinear(pt1, pt4, pt2), "Collinear points");
        assertTrue(!InternalClipper.isCollinear(pt1, pt2, pt3), "Non-collinear points");

        // Bounds
        var path:Path64 = [
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ];
        var bounds = InternalClipper.getBounds(path);
        assertTrue(bounds.left == 0, "Bounds left");
        assertTrue(bounds.top == 0, "Bounds top");
        assertTrue(bounds.right == 100, "Bounds right");
        assertTrue(bounds.bottom == 100, "Bounds bottom");

        // Point in polygon
        var inside = new Point64(50, 50);
        var outside = new Point64(150, 150);
        var result1 = InternalClipper.pointInPolygon(inside, path);
        var result2 = InternalClipper.pointInPolygon(outside, path);
        assertTrue(result1 == PointInPolygonResult.IsInside, "Point inside polygon");
        assertTrue(result2 == PointInPolygonResult.IsOutside, "Point outside polygon");

        trace("InternalClipper tests complete.");
    }

    static function testClipper64():Void {
        trace("Testing Clipper64...");

        // Create two overlapping squares
        // Square 1: (0,0) to (100,100)
        var subject:Paths64 = [[
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ]];

        // Square 2: (50,50) to (150,150)
        var clip:Paths64 = [[
            new Point64(50, 50),
            new Point64(150, 50),
            new Point64(150, 150),
            new Point64(50, 150)
        ]];

        var clipper = new Clipper64();
        clipper.preserveCollinear = true;
        clipper.addSubjectPaths(subject);
        clipper.addClipPaths(clip);

        // Test Intersection - should be the overlapping region (50,50) to (100,100)
        var solution:Paths64 = [];
        var success = clipper.execute(ClipType.Intersection, FillRule.NonZero, solution);
        assertTrue(success, "Clipper64 intersection executes");
        assertTrue(solution.length == 1, "Clipper64 intersection produces 1 path");
        if (solution.length > 0) {
            var area = InternalClipper.area(solution[0]);
            // Intersection area should be 50*50 = 2500
            assertTrue(area == 2500 || area == -2500, "Clipper64 intersection area is 2500");
        }

        // Test Union
        clipper.clear();
        clipper.addSubjectPaths(subject);
        clipper.addClipPaths(clip);
        solution = [];
        success = clipper.execute(ClipType.Union, FillRule.NonZero, solution);
        assertTrue(success, "Clipper64 union executes");
        assertTrue(solution.length == 1, "Clipper64 union produces 1 path");
        if (solution.length > 0) {
            var area = InternalClipper.area(solution[0]);
            // Union area should be 100*100 + 100*100 - 50*50 = 17500
            var absArea = area < 0 ? -area : area;
            assertTrue(absArea == 17500, "Clipper64 union area is 17500");
        }

        // Test Difference (Subject - Clip)
        clipper.clear();
        clipper.addSubjectPaths(subject);
        clipper.addClipPaths(clip);
        solution = [];
        success = clipper.execute(ClipType.Difference, FillRule.NonZero, solution);
        assertTrue(success, "Clipper64 difference executes");
        assertTrue(solution.length == 1, "Clipper64 difference produces 1 path");
        if (solution.length > 0) {
            var area = InternalClipper.area(solution[0]);
            // Difference area should be 100*100 - 50*50 = 7500
            var absArea = area < 0 ? -area : area;
            assertTrue(absArea == 7500, "Clipper64 difference area is 7500");
        }

        // Test XOR
        clipper.clear();
        clipper.addSubjectPaths(subject);
        clipper.addClipPaths(clip);
        solution = [];
        success = clipper.execute(ClipType.Xor, FillRule.NonZero, solution);
        assertTrue(success, "Clipper64 xor executes");
        // XOR should produce 2 L-shaped regions
        assertTrue(solution.length == 2, "Clipper64 xor produces 2 paths");
        if (solution.length == 2) {
            var totalArea = InternalClipper.area(solution[0]) + InternalClipper.area(solution[1]);
            var absArea = totalArea < 0 ? -totalArea : totalArea;
            // XOR area should be (100*100 - 50*50) + (100*100 - 50*50) = 15000
            assertTrue(absArea == 15000, "Clipper64 xor total area is 15000");
        }

        trace("Clipper64 tests complete.");
    }

    static function testClipperOffset():Void {
        trace("Testing ClipperOffset...");

        // Create a simple square (0,0) to (100,100)
        var subject:Paths64 = [[
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ]];

        // Test inflate (positive delta)
        var offset = new ClipperOffset();
        offset.addPaths(subject, JoinType.Miter, EndType.Polygon);
        var solution:Paths64 = [];
        offset.execute(10.0, solution);

        assertTrue(solution.length == 1, "ClipperOffset inflate produces 1 path");
        if (solution.length > 0) {
            var area = InternalClipper.area(solution[0]);
            var absArea = Math.abs(area);
            // Original area: 100*100 = 10000
            // Inflated by 10 with miter: 120*120 = 14400
            assertTrue(absArea > 14000 && absArea < 15000, "ClipperOffset inflate area is correct");
        }

        // Test deflate (negative delta)
        offset.clear();
        offset.addPaths(subject, JoinType.Miter, EndType.Polygon);
        solution = [];
        offset.execute(-10.0, solution);

        assertTrue(solution.length == 1, "ClipperOffset deflate produces 1 path");
        if (solution.length > 0) {
            var area = InternalClipper.area(solution[0]);
            var absArea = Math.abs(area);
            // Original area: 100*100 = 10000
            // Deflated by 10: approx 80*80 = 6400
            assertTrue(absArea < 10000 && absArea > 5000, "ClipperOffset deflate area is reasonable");
        }

        // Test round join
        offset.clear();
        offset.addPaths(subject, JoinType.Round, EndType.Polygon);
        solution = [];
        offset.execute(10.0, solution);

        assertTrue(solution.length == 1, "ClipperOffset round join produces 1 path");
        if (solution.length > 0) {
            // Round joins produce more vertices than miter
            assertTrue(solution[0].length > 4, "ClipperOffset round join has more than 4 vertices");
        }

        // Test bevel join
        offset.clear();
        offset.addPaths(subject, JoinType.Bevel, EndType.Polygon);
        solution = [];
        offset.execute(10.0, solution);

        assertTrue(solution.length == 1, "ClipperOffset bevel join produces 1 path");
        if (solution.length > 0) {
            // Bevel joins add extra vertices at corners
            assertTrue(solution[0].length >= 4, "ClipperOffset bevel join has at least 4 vertices");
        }

        // Test ellipse helper
        var center = new Point64(50, 50);
        var ellipsePath = ClipperOffset.ellipse(center, 25.0, 25.0);
        assertTrue(ellipsePath.length > 8, "ClipperOffset ellipse has multiple vertices");
        var ellipseArea = InternalClipper.area(ellipsePath);
        var absEllipseArea = Math.abs(ellipseArea);
        // Area of circle with radius 25: pi * 25^2 ≈ 1963
        assertTrue(absEllipseArea > 1800 && absEllipseArea < 2100, "ClipperOffset ellipse area is approximately correct");

        trace("ClipperOffset tests complete.");
    }

    static function testRectClip():Void {
        trace("Testing RectClip...");

        // Create a square (0,0) to (200,200)
        var subject:Paths64 = [[
            new Point64(0, 0),
            new Point64(200, 0),
            new Point64(200, 200),
            new Point64(0, 200)
        ]];

        // Clip with a rect (50,50) to (150,150)
        var clipRect = new Rect64(50, 50, 150, 150);
        var rectClip = new RectClip64(clipRect);
        var solution = rectClip.execute(subject);

        assertTrue(solution.length == 1, "RectClip64 produces 1 path");
        if (solution.length > 0) {
            var area = InternalClipper.area(solution[0]);
            var absArea = Math.abs(area);
            // Clipped area should be 100*100 = 10000
            assertTrue(absArea == 10000, "RectClip64 area is 10000");
        }

        // Test with polygon completely inside rect
        var smallSquare:Paths64 = [[
            new Point64(60, 60),
            new Point64(140, 60),
            new Point64(140, 140),
            new Point64(60, 140)
        ]];
        solution = rectClip.execute(smallSquare);
        assertTrue(solution.length == 1, "RectClip64 inside polygon produces 1 path");
        if (solution.length > 0) {
            var area = InternalClipper.area(solution[0]);
            var absArea = Math.abs(area);
            // Inside polygon should be unchanged: 80*80 = 6400
            assertTrue(absArea == 6400, "RectClip64 inside polygon area is 6400");
        }

        // Test with polygon completely outside rect
        var outsideSquare:Paths64 = [[
            new Point64(200, 200),
            new Point64(300, 200),
            new Point64(300, 300),
            new Point64(200, 300)
        ]];
        solution = rectClip.execute(outsideSquare);
        assertTrue(solution.length == 0, "RectClip64 outside polygon produces 0 paths");

        // Test with multiple polygons
        var twoSquares:Paths64 = [
            [
                new Point64(0, 0),
                new Point64(100, 0),
                new Point64(100, 100),
                new Point64(0, 100)
            ],
            [
                new Point64(100, 100),
                new Point64(200, 100),
                new Point64(200, 200),
                new Point64(100, 200)
            ]
        ];
        solution = rectClip.execute(twoSquares);
        assertTrue(solution.length == 2, "RectClip64 two squares produces 2 paths");

        // Test RectClipLines64
        var openPath:Paths64 = [[
            new Point64(0, 100),
            new Point64(200, 100)
        ]];
        var rectClipLines = new RectClipLines64(clipRect);
        var lineSolution = rectClipLines.execute(openPath);
        assertTrue(lineSolution.length == 1, "RectClipLines64 produces 1 path");
        if (lineSolution.length > 0) {
            // Line clipped from (50,100) to (150,100)
            assertTrue(lineSolution[0].length == 2, "RectClipLines64 line has 2 points");
        }

        // Test diagonal line crossing the rect
        var diagonalPath:Paths64 = [[
            new Point64(0, 0),
            new Point64(200, 200)
        ]];
        lineSolution = rectClipLines.execute(diagonalPath);
        assertTrue(lineSolution.length == 1, "RectClipLines64 diagonal produces 1 path");
        if (lineSolution.length > 0) {
            assertTrue(lineSolution[0].length == 2, "RectClipLines64 diagonal has 2 points");
        }

        // Test line completely outside
        var outsideLine:Paths64 = [[
            new Point64(0, 0),
            new Point64(40, 0)
        ]];
        lineSolution = rectClipLines.execute(outsideLine);
        assertTrue(lineSolution.length == 0, "RectClipLines64 outside line produces 0 paths");

        trace("RectClip tests complete.");
    }

    static function testMinkowski():Void {
        trace("Testing Minkowski...");

        // Create a small square pattern (10x10 centered at origin)
        var pattern:Path64 = [
            new Point64(-5, -5),
            new Point64(5, -5),
            new Point64(5, 5),
            new Point64(-5, 5)
        ];

        // Create a path (a simple line from (0,0) to (100,0))
        var path:Path64 = [
            new Point64(0, 0),
            new Point64(100, 0)
        ];

        // Minkowski Sum with closed=false (open path)
        var sumResult = ClipperMinkowski.sum(pattern, path, false);
        assertTrue(sumResult.length > 0, "Minkowski sum produces paths");

        // The result should be a rectangle-ish shape around the line
        // Width should be roughly 110 (100 + 2*5), height should be roughly 10 (2*5)
        var totalArea:Float = 0;
        for (p in sumResult) {
            totalArea += Math.abs(InternalClipper.area(p));
        }
        // Expected area: approximately 100*10 + some extra from the ends
        assertTrue(totalArea > 900 && totalArea < 1500, "Minkowski sum area is reasonable");

        // Minkowski Sum with closed path (square around square)
        var squarePath:Path64 = [
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ];
        sumResult = ClipperMinkowski.sum(pattern, squarePath, true);
        assertTrue(sumResult.length > 0, "Minkowski sum closed produces paths");

        // The result should be a larger square (110x110)
        totalArea = 0;
        for (p in sumResult) {
            totalArea += Math.abs(InternalClipper.area(p));
        }
        // The area depends on the union of quads from the Minkowski operation
        // With a 10x10 pattern around a 100x100 square, the result is complex
        // Just verify we get a reasonable non-zero area
        assertTrue(totalArea > 10000, "Minkowski sum closed area is non-trivial (got " + Std.string(totalArea) + ")");

        // Test Minkowski Difference
        var diffResult = ClipperMinkowski.diff(pattern, squarePath, true);
        assertTrue(diffResult.length > 0, "Minkowski diff produces paths");

        // Test helper functions
        var testPath:Path64 = [
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ];
        assertTrue(ClipperMinkowski.isPositive(testPath), "CCW path is positive");

        var reversed = ClipperMinkowski.reversePath(testPath);
        assertTrue(reversed.length == 4, "Reversed path has 4 points");
        assertTrue(reversed[0].x == 0 && reversed[0].y == 100, "Reversed path starts at last point");

        trace("Minkowski tests complete.");
    }

    static function testTriangulation():Void {
        trace("Testing Triangulation...");

        // Create a simple square to triangulate
        var square:Paths64 = [[
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ]];

        var result = ClipperTriangulation.triangulate(square);
        assertTrue(result.result == TriangulateResult.Success, "Triangulation succeeds on square");
        assertTrue(result.solution.length == 2, "Square triangulates to 2 triangles");

        // Verify that each triangle has 3 points
        for (tri in result.solution) {
            assertTrue(tri.length == 3, "Triangle has 3 points");
        }

        // Calculate total area of triangles - should equal square area
        var totalArea:Float = 0;
        for (tri in result.solution) {
            totalArea += Math.abs(InternalClipper.area(tri));
        }
        // Square area is 100*100 = 10000
        assertTrue(Math.abs(totalArea - 10000) < 1, "Triangulation preserves area (got " + Std.string(totalArea) + ")");

        // Test with a concave polygon (L-shape)
        var lShape:Paths64 = [[
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 50),
            new Point64(50, 50),
            new Point64(50, 100),
            new Point64(0, 100)
        ]];

        result = ClipperTriangulation.triangulate(lShape);
        assertTrue(result.result == TriangulateResult.Success, "Triangulation succeeds on L-shape");
        assertTrue(result.solution.length >= 4, "L-shape produces at least 4 triangles");

        // L-shape area: 100*100 - 50*50 = 7500
        totalArea = 0;
        for (tri in result.solution) {
            totalArea += Math.abs(InternalClipper.area(tri));
        }
        assertTrue(Math.abs(totalArea - 7500) < 1, "L-shape triangulation preserves area (got " + Std.string(totalArea) + ")");

        // Test with empty input
        var empty:Paths64 = [];
        result = ClipperTriangulation.triangulate(empty);
        assertTrue(result.result == TriangulateResult.NoPolygons, "Empty input returns NoPolygons");

        // Test with a path that's too small
        var tooSmall:Paths64 = [[
            new Point64(0, 0),
            new Point64(1, 0)
        ]];
        result = ClipperTriangulation.triangulate(tooSmall);
        assertTrue(result.result == TriangulateResult.NoPolygons, "Path with < 3 points returns NoPolygons");

        trace("Triangulation tests complete.");
    }

    static function testClipperHighLevelAPI():Void {
        trace("Testing Clipper High-Level API...");

        // Create two overlapping squares
        var subject:Paths64 = [[
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ]];

        var clip:Paths64 = [[
            new Point64(50, 50),
            new Point64(150, 50),
            new Point64(150, 150),
            new Point64(50, 150)
        ]];

        // Test intersection via high-level API
        var result = Clipper.intersect(subject, clip, FillRule.NonZero);
        assertTrue(result.length == 1, "High-level intersect produces 1 path");
        if (result.length > 0) {
            var area = Math.abs(Clipper.areaPath64(result[0]));
            assertTrue(area == 2500, "High-level intersect area is 2500");
        }

        // Test union via high-level API
        result = Clipper.unionWithClip(subject, clip, FillRule.NonZero);
        assertTrue(result.length == 1, "High-level union produces 1 path");
        if (result.length > 0) {
            var area = Math.abs(Clipper.areaPath64(result[0]));
            assertTrue(area == 17500, "High-level union area is 17500");
        }

        // Test difference via high-level API
        result = Clipper.difference(subject, clip, FillRule.NonZero);
        assertTrue(result.length == 1, "High-level difference produces 1 path");
        if (result.length > 0) {
            var area = Math.abs(Clipper.areaPath64(result[0]));
            assertTrue(area == 7500, "High-level difference area is 7500");
        }

        // Test xor via high-level API
        result = Clipper.xor(subject, clip, FillRule.NonZero);
        assertTrue(result.length == 2, "High-level xor produces 2 paths");

        // Test inflatePaths
        var square:Paths64 = [[
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ]];
        var inflated = Clipper.inflatePaths(square, 10.0, JoinType.Miter, EndType.Polygon);
        assertTrue(inflated.length == 1, "inflatePaths produces 1 path");

        // Test rectClip
        var bigSquare:Paths64 = [[
            new Point64(0, 0),
            new Point64(200, 0),
            new Point64(200, 200),
            new Point64(0, 200)
        ]];
        var clipRect = new Rect64(50, 50, 150, 150);
        var clipped = Clipper.rectClip(clipRect, bigSquare);
        assertTrue(clipped.length == 1, "rectClip produces 1 path");

        // Test helper functions
        var testPath:Path64 = [
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(0, 100)
        ];
        assertTrue(Clipper.isPositive(testPath), "isPositive returns true for CCW path");

        var reversed = Clipper.reversePath(testPath);
        assertTrue(reversed.length == 4, "reversePath preserves length");
        assertTrue(reversed[0].x == 0 && reversed[0].y == 100, "reversePath reverses correctly");

        var translated = Clipper.translatePath(testPath, 10, 20);
        assertTrue(translated[0].x == 10 && translated[0].y == 20, "translatePath works correctly");

        var bounds = Clipper.getBoundsPath64(testPath);
        assertTrue(bounds.left == 0 && bounds.top == 0 && bounds.right == 100 && bounds.bottom == 100, "getBoundsPath64 returns correct bounds");

        // Test ellipse
        var ellipsePath = Clipper.ellipse(new Point64(50, 50), 25.0, 25.0);
        assertTrue(ellipsePath.length > 8, "ellipse generates multiple points");

        // Test stripDuplicates
        var pathWithDupes:Path64 = [
            new Point64(0, 0),
            new Point64(0, 0),
            new Point64(100, 0),
            new Point64(100, 100),
            new Point64(100, 100),
            new Point64(0, 100)
        ];
        var stripped = Clipper.stripDuplicates(pathWithDupes, true);
        assertTrue(stripped.length == 4, "stripDuplicates removes duplicates");

        trace("Clipper High-Level API tests complete.");
    }

    static function testPooling():Void {
        TestPooling.run();
        passed += TestPooling.passed;
        failed += TestPooling.failed;
    }
}
