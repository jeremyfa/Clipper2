package clipper2;

import haxe.Int64;
import clipper2.internal.ClipperCore;
import clipper2.ClipperEngine;
import clipper2.ClipperOffset;
import clipper2.ClipperRectClip;
import clipper2.ClipperMinkowski;
import clipper2.ClipperTriangulation;

/**
 * High-level static API for common polygon clipping and offsetting operations.
 * This module provides simple functions that cover most polygon boolean and
 * offsetting needs while avoiding the inherent complexities of other modules.
 */
class Clipper {
    // =========================================================================
    // Boolean Operations
    // =========================================================================

    /**
     * Computes the intersection of subject and clip paths.
     */
    public static function intersect(subject:Paths64, clip:Paths64, fillRule:FillRule):Paths64 {
        return booleanOp(ClipType.Intersection, subject, clip, fillRule);
    }

    /**
     * Computes the intersection of subject and clip paths (floating-point).
     */
    public static function intersectD(subject:PathsD, clip:PathsD, fillRule:FillRule, precision:Int = 2):PathsD {
        return booleanOpD(ClipType.Intersection, subject, clip, fillRule, precision);
    }

    /**
     * Computes the union of subject paths.
     */
    public static function union(subject:Paths64, fillRule:FillRule):Paths64 {
        return booleanOp(ClipType.Union, subject, null, fillRule);
    }

    /**
     * Computes the union of subject and clip paths.
     */
    public static function unionWithClip(subject:Paths64, clip:Paths64, fillRule:FillRule):Paths64 {
        return booleanOp(ClipType.Union, subject, clip, fillRule);
    }

    /**
     * Computes the union of subject paths (floating-point).
     */
    public static function unionD(subject:PathsD, fillRule:FillRule):PathsD {
        return booleanOpD(ClipType.Union, subject, null, fillRule);
    }

    /**
     * Computes the union of subject and clip paths (floating-point).
     */
    public static function unionWithClipD(subject:PathsD, clip:PathsD, fillRule:FillRule, precision:Int = 2):PathsD {
        return booleanOpD(ClipType.Union, subject, clip, fillRule, precision);
    }

    /**
     * Computes the difference of subject and clip paths (subject - clip).
     */
    public static function difference(subject:Paths64, clip:Paths64, fillRule:FillRule):Paths64 {
        return booleanOp(ClipType.Difference, subject, clip, fillRule);
    }

    /**
     * Computes the difference of subject and clip paths (floating-point).
     */
    public static function differenceD(subject:PathsD, clip:PathsD, fillRule:FillRule, precision:Int = 2):PathsD {
        return booleanOpD(ClipType.Difference, subject, clip, fillRule, precision);
    }

    /**
     * Computes the XOR (symmetric difference) of subject and clip paths.
     */
    public static function xor(subject:Paths64, clip:Paths64, fillRule:FillRule):Paths64 {
        return booleanOp(ClipType.Xor, subject, clip, fillRule);
    }

    /**
     * Computes the XOR of subject and clip paths (floating-point).
     */
    public static function xorD(subject:PathsD, clip:PathsD, fillRule:FillRule, precision:Int = 2):PathsD {
        return booleanOpD(ClipType.Xor, subject, clip, fillRule, precision);
    }

    /**
     * Performs a boolean operation on subject and clip paths.
     */
    public static function booleanOp(clipType:ClipType, subject:Null<Paths64>, clip:Null<Paths64>, fillRule:FillRule):Paths64 {
        var solution = new Paths64();
        if (subject == null) return solution;
        var c = new Clipper64();
        c.addSubjectPaths(subject);
        if (clip != null)
            c.addClipPaths(clip);
        c.execute(clipType, fillRule, solution);
        return solution;
    }

    /**
     * Performs a boolean operation on subject and clip paths (floating-point).
     */
    public static function booleanOpD(clipType:ClipType, subject:PathsD, clip:Null<PathsD>, fillRule:FillRule, precision:Int = 2):PathsD {
        var solution = new PathsD();
        var c = new ClipperD(precision);
        c.addSubjectPathsD(subject);
        if (clip != null)
            c.addClipPathsD(clip);
        c.executeD(clipType, fillRule, solution);
        return solution;
    }

    // =========================================================================
    // Offsetting (Inflate/Deflate)
    // =========================================================================

    /**
     * Inflates or deflates paths by the given delta.
     */
    public static function inflatePaths(paths:Paths64, delta:Float, joinType:JoinType, endType:EndType, miterLimit:Float = 2.0, arcTolerance:Float = 0.0):Paths64 {
        var co = new ClipperOffset(miterLimit, arcTolerance);
        co.addPaths(paths, joinType, endType);
        var solution = new Paths64();
        co.execute(delta, solution);
        return solution;
    }

    /**
     * Inflates or deflates paths by the given delta (floating-point).
     */
    public static function inflatePathsD(paths:PathsD, delta:Float, joinType:JoinType, endType:EndType, miterLimit:Float = 2.0, precision:Int = 2, arcTolerance:Float = 0.0):PathsD {
        InternalClipper.checkPrecision(precision);
        var scale = Math.pow(10, precision);
        var tmp = scalePaths64(paths, scale);
        var co = new ClipperOffset(miterLimit, scale * arcTolerance);
        co.addPaths(tmp, joinType, endType);
        co.execute(delta * scale, tmp);
        return scalePathsD(tmp, 1 / scale);
    }

    // =========================================================================
    // Rectangle Clipping
    // =========================================================================

    /**
     * Clips paths to the given rectangle.
     */
    public static function rectClip(rect:Rect64, paths:Paths64):Paths64 {
        if (rect.isEmpty() || paths.length == 0) return new Paths64();
        var rc = new RectClip64(rect);
        return rc.execute(paths);
    }

    /**
     * Clips a single path to the given rectangle.
     */
    public static function rectClipPath(rect:Rect64, path:Path64):Paths64 {
        if (rect.isEmpty() || path.length == 0) return new Paths64();
        return rectClip(rect, [path]);
    }

    /**
     * Clips paths to the given rectangle (floating-point).
     */
    public static function rectClipD(rect:RectD, paths:PathsD, precision:Int = 2):PathsD {
        InternalClipper.checkPrecision(precision);
        if (rect.isEmpty() || paths.length == 0) return new PathsD();
        var scale = Math.pow(10, precision);
        var r = scaleRect(rect, scale);
        var tmpPath = scalePaths64(paths, scale);
        var rc = new RectClip64(r);
        tmpPath = rc.execute(tmpPath);
        return scalePathsD(tmpPath, 1 / scale);
    }

    /**
     * Clips lines (open paths) to the given rectangle.
     */
    public static function rectClipLines(rect:Rect64, paths:Paths64):Paths64 {
        if (rect.isEmpty() || paths.length == 0) return new Paths64();
        var rc = new RectClipLines64(rect);
        return rc.execute(paths);
    }

    /**
     * Clips lines to the given rectangle (floating-point).
     */
    public static function rectClipLinesD(rect:RectD, paths:PathsD, precision:Int = 2):PathsD {
        InternalClipper.checkPrecision(precision);
        if (rect.isEmpty() || paths.length == 0) return new PathsD();
        var scale = Math.pow(10, precision);
        var r = scaleRect(rect, scale);
        var tmpPath = scalePaths64(paths, scale);
        var rc = new RectClipLines64(r);
        tmpPath = rc.execute(tmpPath);
        return scalePathsD(tmpPath, 1 / scale);
    }

    // =========================================================================
    // Minkowski Operations
    // =========================================================================

    /**
     * Computes the Minkowski sum of pattern and path.
     */
    public static function minkowskiSum(pattern:Path64, path:Path64, isClosed:Bool):Paths64 {
        return ClipperMinkowski.sum(pattern, path, isClosed);
    }

    /**
     * Computes the Minkowski sum (floating-point).
     */
    public static function minkowskiSumD(pattern:PathD, path:PathD, isClosed:Bool, decimalPlaces:Int = 2):PathsD {
        return ClipperMinkowski.sumD(pattern, path, isClosed, decimalPlaces);
    }

    /**
     * Computes the Minkowski difference of pattern and path.
     */
    public static function minkowskiDiff(pattern:Path64, path:Path64, isClosed:Bool):Paths64 {
        return ClipperMinkowski.diff(pattern, path, isClosed);
    }

    /**
     * Computes the Minkowski difference (floating-point).
     */
    public static function minkowskiDiffD(pattern:PathD, path:PathD, isClosed:Bool, decimalPlaces:Int = 2):PathsD {
        return ClipperMinkowski.diffD(pattern, path, isClosed, decimalPlaces);
    }

    // =========================================================================
    // Area Calculations
    // =========================================================================

    /**
     * Calculates the signed area of a path using the Shoelace formula.
     */
    public static function areaPath64(path:Path64):Float {
        var a:Float = 0.0;
        var cnt = path.length;
        if (cnt < 3) return 0.0;
        var prevPt = path[cnt - 1];
        for (pt in path) {
            a += InternalClipper.toFloat(prevPt.y + pt.y) * InternalClipper.toFloat(prevPt.x - pt.x);
            prevPt = pt;
        }
        return a * 0.5;
    }

    /**
     * Calculates the signed area of multiple paths.
     */
    public static function areaPaths64(paths:Paths64):Float {
        var a:Float = 0.0;
        for (path in paths)
            a += areaPath64(path);
        return a;
    }

    /**
     * Calculates the signed area of a path (floating-point).
     */
    public static function areaPathD(path:PathD):Float {
        var a:Float = 0.0;
        var cnt = path.length;
        if (cnt < 3) return 0.0;
        var prevPt = path[cnt - 1];
        for (pt in path) {
            a += (prevPt.y + pt.y) * (prevPt.x - pt.x);
            prevPt = pt;
        }
        return a * 0.5;
    }

    /**
     * Calculates the signed area of multiple paths (floating-point).
     */
    public static function areaPathsD(paths:PathsD):Float {
        var a:Float = 0.0;
        for (path in paths)
            a += areaPathD(path);
        return a;
    }

    /**
     * Returns true if the path has positive (counter-clockwise) area.
     */
    public static inline function isPositive(poly:Path64):Bool {
        return areaPath64(poly) >= 0;
    }

    /**
     * Returns true if the path has positive (counter-clockwise) area (floating-point).
     */
    public static inline function isPositiveD(poly:PathD):Bool {
        return areaPathD(poly) >= 0;
    }

    // =========================================================================
    // Path Transformations
    // =========================================================================

    /**
     * Translates a path by dx, dy.
     */
    public static function translatePath(path:Path64, dx:Int64, dy:Int64):Path64 {
        var result = new Path64();
        #if clipper_usingz
        for (pt in path)
            result.push(new Point64(pt.x + dx, pt.y + dy, pt.z));
        #else
        for (pt in path)
            result.push(new Point64(pt.x + dx, pt.y + dy));
        #end
        return result;
    }

    /**
     * Translates multiple paths by dx, dy.
     */
    public static function translatePaths(paths:Paths64, dx:Int64, dy:Int64):Paths64 {
        var result = new Paths64();
        for (path in paths)
            result.push(translatePath(path, dx, dy));
        return result;
    }

    /**
     * Translates a path by dx, dy (floating-point).
     */
    public static function translatePathD(path:PathD, dx:Float, dy:Float):PathD {
        var result = new PathD();
        #if clipper_usingz
        for (pt in path)
            result.push(new PointD(pt.x + dx, pt.y + dy, pt.z));
        #else
        for (pt in path)
            result.push(new PointD(pt.x + dx, pt.y + dy));
        #end
        return result;
    }

    /**
     * Translates multiple paths by dx, dy (floating-point).
     */
    public static function translatePathsD(paths:PathsD, dx:Float, dy:Float):PathsD {
        var result = new PathsD();
        for (path in paths)
            result.push(translatePathD(path, dx, dy));
        return result;
    }

    /**
     * Returns a reversed copy of the path.
     */
    public static function reversePath(path:Path64):Path64 {
        var result = new Path64();
        var i = path.length - 1;
        while (i >= 0) {
            result.push(path[i]);
            i--;
        }
        return result;
    }

    /**
     * Returns a reversed copy of the path (floating-point).
     */
    public static function reversePathD(path:PathD):PathD {
        var result = new PathD();
        var i = path.length - 1;
        while (i >= 0) {
            result.push(path[i]);
            i--;
        }
        return result;
    }

    /**
     * Returns reversed copies of all paths.
     */
    public static function reversePaths(paths:Paths64):Paths64 {
        var result = new Paths64();
        for (path in paths)
            result.push(reversePath(path));
        return result;
    }

    /**
     * Returns reversed copies of all paths (floating-point).
     */
    public static function reversePathsD(paths:PathsD):PathsD {
        var result = new PathsD();
        for (path in paths)
            result.push(reversePathD(path));
        return result;
    }

    // =========================================================================
    // Scaling and Conversion
    // =========================================================================

    /**
     * Scales a path by the given factor.
     */
    public static function scalePath(path:Path64, scale:Float):Path64 {
        if (InternalClipper.isAlmostZero(scale - 1)) return path;
        var result = new Path64();
        #if clipper_usingz
        for (pt in path)
            result.push(new Point64(Std.int(InternalClipper.toFloat(pt.x) * scale), Std.int(InternalClipper.toFloat(pt.y) * scale), pt.z));
        #else
        for (pt in path)
            result.push(new Point64(Std.int(InternalClipper.toFloat(pt.x) * scale), Std.int(InternalClipper.toFloat(pt.y) * scale)));
        #end
        return result;
    }

    /**
     * Scales multiple paths by the given factor.
     */
    public static function scalePaths(paths:Paths64, scale:Float):Paths64 {
        if (InternalClipper.isAlmostZero(scale - 1)) return paths;
        var result = new Paths64();
        for (path in paths)
            result.push(scalePath(path, scale));
        return result;
    }

    /**
     * Scales a PathD to Path64 with the given scale.
     */
    public static function scalePath64(path:PathD, scale:Float):Path64 {
        var result = new Path64();
        #if clipper_usingz
        for (pt in path)
            result.push(new Point64(Std.int(pt.x * scale), Std.int(pt.y * scale), pt.z));
        #else
        for (pt in path)
            result.push(new Point64(Std.int(pt.x * scale), Std.int(pt.y * scale)));
        #end
        return result;
    }

    /**
     * Scales PathsD to Paths64 with the given scale.
     */
    public static function scalePaths64(paths:PathsD, scale:Float):Paths64 {
        var result = new Paths64();
        for (path in paths)
            result.push(scalePath64(path, scale));
        return result;
    }

    /**
     * Scales a Path64 to PathD with the given scale.
     */
    public static function scalePathD(path:Path64, scale:Float):PathD {
        var result = new PathD();
        #if clipper_usingz
        for (pt in path)
            result.push(new PointD(InternalClipper.toFloat(pt.x) * scale, InternalClipper.toFloat(pt.y) * scale, pt.z));
        #else
        for (pt in path)
            result.push(new PointD(InternalClipper.toFloat(pt.x) * scale, InternalClipper.toFloat(pt.y) * scale));
        #end
        return result;
    }

    /**
     * Scales Paths64 to PathsD with the given scale.
     */
    public static function scalePathsD(paths:Paths64, scale:Float):PathsD {
        var result = new PathsD();
        for (path in paths)
            result.push(scalePathD(path, scale));
        return result;
    }

    /**
     * Scales a RectD to Rect64.
     */
    public static function scaleRect(rect:RectD, scale:Float):Rect64 {
        return new Rect64(
            Std.int(rect.left * scale),
            Std.int(rect.top * scale),
            Std.int(rect.right * scale),
            Std.int(rect.bottom * scale)
        );
    }

    /**
     * Converts PathD to Path64 without scaling.
     */
    public static function pathDToPath64(path:PathD):Path64 {
        var result = new Path64();
        #if clipper_usingz
        for (pt in path)
            result.push(new Point64(Std.int(pt.x), Std.int(pt.y), pt.z));
        #else
        for (pt in path)
            result.push(new Point64(Std.int(pt.x), Std.int(pt.y)));
        #end
        return result;
    }

    /**
     * Converts PathsD to Paths64 without scaling.
     */
    public static function pathsDToPaths64(paths:PathsD):Paths64 {
        var result = new Paths64();
        for (path in paths)
            result.push(pathDToPath64(path));
        return result;
    }

    /**
     * Converts Path64 to PathD without scaling.
     */
    public static function path64ToPathD(path:Path64):PathD {
        var result = new PathD();
        #if clipper_usingz
        for (pt in path)
            result.push(new PointD(InternalClipper.toFloat(pt.x), InternalClipper.toFloat(pt.y), pt.z));
        #else
        for (pt in path)
            result.push(new PointD(InternalClipper.toFloat(pt.x), InternalClipper.toFloat(pt.y)));
        #end
        return result;
    }

    /**
     * Converts Paths64 to PathsD without scaling.
     */
    public static function paths64ToPathsD(paths:Paths64):PathsD {
        var result = new PathsD();
        for (path in paths)
            result.push(path64ToPathD(path));
        return result;
    }

    // =========================================================================
    // Bounds
    // =========================================================================

    /**
     * Gets the bounding rectangle of a path.
     */
    public static function getBoundsPath64(path:Path64):Rect64 {
        var result = Rect64.createInvalid();
        for (pt in path) {
            if (pt.x < result.left) result.left = pt.x;
            if (pt.x > result.right) result.right = pt.x;
            if (pt.y < result.top) result.top = pt.y;
            if (pt.y > result.bottom) result.bottom = pt.y;
        }
        return result.isValid() ? result : new Rect64();
    }

    /**
     * Gets the bounding rectangle of multiple paths.
     */
    public static function getBoundsPaths64(paths:Paths64):Rect64 {
        var result = Rect64.createInvalid();
        for (path in paths) {
            for (pt in path) {
                if (pt.x < result.left) result.left = pt.x;
                if (pt.x > result.right) result.right = pt.x;
                if (pt.y < result.top) result.top = pt.y;
                if (pt.y > result.bottom) result.bottom = pt.y;
            }
        }
        return result.isValid() ? result : new Rect64();
    }

    /**
     * Gets the bounding rectangle of a path (floating-point).
     */
    public static function getBoundsPathD(path:PathD):RectD {
        var result = RectD.createInvalid();
        for (pt in path) {
            if (pt.x < result.left) result.left = pt.x;
            if (pt.x > result.right) result.right = pt.x;
            if (pt.y < result.top) result.top = pt.y;
            if (pt.y > result.bottom) result.bottom = pt.y;
        }
        return result.isValid() ? result : new RectD();
    }

    /**
     * Gets the bounding rectangle of multiple paths (floating-point).
     */
    public static function getBoundsPathsD(paths:PathsD):RectD {
        var result = RectD.createInvalid();
        for (path in paths) {
            for (pt in path) {
                if (pt.x < result.left) result.left = pt.x;
                if (pt.x > result.right) result.right = pt.x;
                if (pt.y < result.top) result.top = pt.y;
                if (pt.y > result.bottom) result.bottom = pt.y;
            }
        }
        return result.isValid() ? result : new RectD();
    }

    // =========================================================================
    // Helper Functions
    // =========================================================================

    /**
     * Creates a path from an array of integers [x1, y1, x2, y2, ...].
     */
    public static function makePathInt(arr:Array<Int>):Path64 {
        var len = Std.int(arr.length / 2);
        var result = new Path64();
        for (i in 0...len)
            result.push(new Point64(arr[i * 2], arr[i * 2 + 1]));
        return result;
    }

    /**
     * Creates a path from an array of floats [x1, y1, x2, y2, ...].
     */
    public static function makePathFloat(arr:Array<Float>):PathD {
        var len = Std.int(arr.length / 2);
        var result = new PathD();
        for (i in 0...len)
            result.push(new PointD(arr[i * 2], arr[i * 2 + 1]));
        return result;
    }

    #if clipper_usingz
    /**
     * Creates a Path64 from an array of integers [x1, y1, z1, x2, y2, z2, ...].
     */
    public static function makePathZ(arr:Array<Int>):Path64 {
        var len = Std.int(arr.length / 3);
        var result = new Path64();
        for (i in 0...len)
            result.push(new Point64(arr[i * 3], arr[i * 3 + 1], arr[i * 3 + 2]));
        return result;
    }

    /**
     * Creates a PathD from an array of floats [x1, y1, z1, x2, y2, z2, ...].
     */
    public static function makePathZD(arr:Array<Float>):PathD {
        var len = Std.int(arr.length / 3);
        var result = new PathD();
        for (i in 0...len)
            result.push(new PointD(arr[i * 3], arr[i * 3 + 1], Std.int(arr[i * 3 + 2])));
        return result;
    }
    #end

    /**
     * Calculates the squared distance between two points.
     */
    public static inline function sqr(val:Float):Float {
        return val * val;
    }

    /**
     * Calculates the squared distance between two Point64 values.
     */
    public static function distanceSqr(pt1:Point64, pt2:Point64):Float {
        return sqr(InternalClipper.toFloat(pt1.x - pt2.x)) + sqr(InternalClipper.toFloat(pt1.y - pt2.y));
    }

    /**
     * Calculates the midpoint between two Point64 values.
     */
    public static function midPoint(pt1:Point64, pt2:Point64):Point64 {
        return new Point64((pt1.x + pt2.x) / 2, (pt1.y + pt2.y) / 2);
    }

    /**
     * Calculates the midpoint between two PointD values.
     */
    public static function midPointD(pt1:PointD, pt2:PointD):PointD {
        return new PointD((pt1.x + pt2.x) / 2, (pt1.y + pt2.y) / 2);
    }

    /**
     * Tests if a point is near equal to another point within a squared distance tolerance.
     */
    public static inline function pointsNearEqual(pt1:PointD, pt2:PointD, distanceSqrd:Float):Bool {
        return sqr(pt1.x - pt2.x) + sqr(pt1.y - pt2.y) < distanceSqrd;
    }

    /**
     * Strips near-duplicate points from a path.
     */
    public static function stripNearDuplicates(path:PathD, minEdgeLenSqrd:Float, isClosedPath:Bool):PathD {
        var cnt = path.length;
        var result = new PathD();
        if (cnt == 0) return result;
        var lastPt = path[0];
        result.push(lastPt);
        for (i in 1...cnt) {
            if (!pointsNearEqual(lastPt, path[i], minEdgeLenSqrd)) {
                lastPt = path[i];
                result.push(lastPt);
            }
        }
        if (isClosedPath && result.length > 1 && pointsNearEqual(lastPt, result[0], minEdgeLenSqrd)) {
            result.pop();
        }
        return result;
    }

    /**
     * Strips duplicate points from a path.
     */
    public static function stripDuplicates(path:Path64, isClosedPath:Bool):Path64 {
        var cnt = path.length;
        var result = new Path64();
        if (cnt == 0) return result;
        var lastPt = path[0];
        result.push(lastPt);
        for (i in 1...cnt) {
            if (lastPt != path[i]) {
                lastPt = path[i];
                result.push(lastPt);
            }
        }
        if (isClosedPath && result.length > 1 && lastPt == result[0]) {
            result.pop();
        }
        return result;
    }

    /**
     * Returns perpendicular distance squared from a point to a line.
     */
    public static function perpendicDistFromLineSqrd(pt:Point64, line1:Point64, line2:Point64):Float {
        var a = InternalClipper.toFloat(pt.x - line1.x);
        var b = InternalClipper.toFloat(pt.y - line1.y);
        var c = InternalClipper.toFloat(line2.x - line1.x);
        var d = InternalClipper.toFloat(line2.y - line1.y);
        if (c == 0 && d == 0) return 0;
        return sqr(a * d - c * b) / (c * c + d * d);
    }

    /**
     * Returns perpendicular distance squared from a point to a line (floating-point).
     */
    public static function perpendicDistFromLineSqrdD(pt:PointD, line1:PointD, line2:PointD):Float {
        var a = pt.x - line1.x;
        var b = pt.y - line1.y;
        var c = line2.x - line1.x;
        var d = line2.y - line1.y;
        if (c == 0 && d == 0) return 0;
        return sqr(a * d - c * b) / (c * c + d * d);
    }

    /**
     * Tests if a point is inside a polygon.
     */
    public static function pointInPolygon(pt:Point64, polygon:Path64):PointInPolygonResult {
        return InternalClipper.pointInPolygon(pt, polygon);
    }

    /**
     * Generates an ellipse path.
     */
    public static function ellipse(center:Point64, radiusX:Float, radiusY:Float = 0, steps:Int = 0):Path64 {
        if (radiusX <= 0) return new Path64();
        if (radiusY <= 0) radiusY = radiusX;
        if (steps <= 2)
            steps = Std.int(Math.ceil(Math.PI * Math.sqrt((radiusX + radiusY) / 2)));

        var si = Math.sin(2 * Math.PI / steps);
        var co = Math.cos(2 * Math.PI / steps);
        var dx = co, dy = si;
        var result = new Path64();
        result.push(new Point64(center.x + Std.int(radiusX), center.y));
        for (i in 1...steps) {
            result.push(new Point64(center.x + Std.int(radiusX * dx), center.y + Std.int(radiusY * dy)));
            var x = dx * co - dy * si;
            dy = dy * co + dx * si;
            dx = x;
        }
        return result;
    }

    /**
     * Generates an ellipse path (floating-point).
     */
    public static function ellipseD(center:PointD, radiusX:Float, radiusY:Float = 0, steps:Int = 0):PathD {
        if (radiusX <= 0) return new PathD();
        if (radiusY <= 0) radiusY = radiusX;
        if (steps <= 2)
            steps = Std.int(Math.ceil(Math.PI * Math.sqrt((radiusX + radiusY) / 2)));

        var si = Math.sin(2 * Math.PI / steps);
        var co = Math.cos(2 * Math.PI / steps);
        var dx = co, dy = si;
        var result = new PathD();
        result.push(new PointD(center.x + radiusX, center.y));
        for (i in 1...steps) {
            result.push(new PointD(center.x + radiusX * dx, center.y + radiusY * dy));
            var x = dx * co - dy * si;
            dy = dy * co + dx * si;
            dx = x;
        }
        return result;
    }

    /**
     * Trims collinear points from a path.
     */
    public static function trimCollinear(path:Path64, isOpen:Bool = false):Path64 {
        var len = path.length;
        var i = 0;
        if (!isOpen) {
            while (i < len - 1 && InternalClipper.isCollinear(path[len - 1], path[i], path[i + 1])) i++;
            while (i < len - 1 && InternalClipper.isCollinear(path[len - 2], path[len - 1], path[i])) len--;
        }

        if (len - i < 3) {
            if (!isOpen || len < 2 || path[0] == path[1])
                return new Path64();
            return path;
        }

        var result = new Path64();
        var last = path[i];
        result.push(last);
        i++;
        while (i < len - 1) {
            if (!InternalClipper.isCollinear(last, path[i], path[i + 1])) {
                last = path[i];
                result.push(last);
            }
            i++;
        }

        if (isOpen)
            result.push(path[len - 1]);
        else if (!InternalClipper.isCollinear(last, path[len - 1], result[0]))
            result.push(path[len - 1]);
        else {
            while (result.length > 2 && InternalClipper.isCollinear(result[result.length - 1], result[result.length - 2], result[0])) {
                result.pop();
            }
            if (result.length < 3)
                result = new Path64();
        }
        return result;
    }

    // =========================================================================
    // Triangulation
    // =========================================================================

    /**
     * Triangulates paths using Constrained Delaunay Triangulation.
     */
    public static function triangulate(paths:Paths64, useDelaunay:Bool = true):{result:TriangulateResult, solution:Paths64} {
        return ClipperTriangulation.triangulate(paths, useDelaunay);
    }
}
