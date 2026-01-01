package clipper;

import haxe.Int64;
import clipper.internal.ClipperCore;
import clipper.ClipperEngine;

/**
 * Minkowski Sum and Difference operations.
 *
 * Minkowski Sum: For each point P in path, the pattern is translated by P.
 * The union of all these translated patterns forms the Minkowski sum.
 *
 * Minkowski Difference: Similar to sum, but subtracts pattern points from path points.
 */
class ClipperMinkowski {
    /**
     * Internal implementation of Minkowski operation.
     * Creates quads from adjacent pattern/path point pairs.
     */
    private static function minkowskiInternal(pattern:Path64, path:Path64, isSum:Bool, isClosed:Bool):Paths64 {
        var delta = isClosed ? 0 : 1;
        var patLen = pattern.length;
        var pathLen = path.length;
        var tmp = new Paths64();

        // For each point in path, translate the pattern
        for (pathPt in path) {
            var path2 = new Path64();
            if (isSum) {
                for (basePt in pattern)
                    path2.push(pathPt + basePt);
            } else {
                for (basePt in pattern)
                    path2.push(pathPt - basePt);
            }
            tmp.push(path2);
        }

        // Create quads from adjacent pattern/path combinations
        var result = new Paths64();
        var g = isClosed ? pathLen - 1 : 0;
        var h = patLen - 1;

        var i = delta;
        while (i < pathLen) {
            var j = 0;
            while (j < patLen) {
                var quad:Path64 = [tmp[g][h], tmp[i][h], tmp[i][j], tmp[g][j]];
                if (!isPositive(quad))
                    result.push(reversePath(quad));
                else
                    result.push(quad);
                h = j;
                j++;
            }
            g = i;
            i++;
        }
        return result;
    }

    /**
     * Returns true if the polygon has a positive (counter-clockwise) winding.
     */
    public static function isPositive(path:Path64):Bool {
        return InternalClipper.area(path) >= 0;
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
     * Computes the Minkowski Sum of pattern and path.
     * @param pattern The pattern polygon to add
     * @param path The path polygon
     * @param isClosed Whether the path is closed
     * @return The union of all translated patterns
     */
    public static function sum(pattern:Path64, path:Path64, isClosed:Bool):Paths64 {
        var tmp = minkowskiInternal(pattern, path, true, isClosed);
        return union(tmp);
    }

    /**
     * Computes the Minkowski Difference of pattern and path.
     * @param pattern The pattern polygon to subtract
     * @param path The path polygon
     * @param isClosed Whether the path is closed
     * @return The union of all translated patterns
     */
    public static function diff(pattern:Path64, path:Path64, isClosed:Bool):Paths64 {
        var tmp = minkowskiInternal(pattern, path, false, isClosed);
        return union(tmp);
    }

    /**
     * Computes the Minkowski Sum for floating-point paths.
     * @param pattern The pattern polygon to add
     * @param path The path polygon
     * @param isClosed Whether the path is closed
     * @param decimalPlaces Decimal precision for scaling (default 2)
     * @return The union of all translated patterns
     */
    public static function sumD(pattern:PathD, path:PathD, isClosed:Bool, decimalPlaces:Int = 2):PathsD {
        var scale = Math.pow(10, decimalPlaces);
        var tmp = minkowskiInternal(scalePath64(pattern, scale), scalePath64(path, scale), true, isClosed);
        var unioned = union(tmp);
        return scalePathsD(unioned, 1.0 / scale);
    }

    /**
     * Computes the Minkowski Difference for floating-point paths.
     * @param pattern The pattern polygon to subtract
     * @param path The path polygon
     * @param isClosed Whether the path is closed
     * @param decimalPlaces Decimal precision for scaling (default 2)
     * @return The union of all translated patterns
     */
    public static function diffD(pattern:PathD, path:PathD, isClosed:Bool, decimalPlaces:Int = 2):PathsD {
        var scale = Math.pow(10, decimalPlaces);
        var tmp = minkowskiInternal(scalePath64(pattern, scale), scalePath64(path, scale), false, isClosed);
        var unioned = union(tmp);
        return scalePathsD(unioned, 1.0 / scale);
    }

    // Helper functions for scaling

    /**
     * Scales a PathD to Path64 by multiplying coordinates by scale.
     */
    private static function scalePath64(path:PathD, scale:Float):Path64 {
        var result = new Path64();
        for (pt in path) {
            result.push(new Point64(Std.int(pt.x * scale), Std.int(pt.y * scale)));
        }
        return result;
    }

    /**
     * Scales Paths64 to PathsD by multiplying coordinates by scale.
     */
    private static function scalePathsD(paths:Paths64, scale:Float):PathsD {
        var result = new PathsD();
        for (path in paths) {
            var pathD = new PathD();
            for (pt in path) {
                pathD.push(new PointD(InternalClipper.toFloat(pt.x) * scale, InternalClipper.toFloat(pt.y) * scale));
            }
            result.push(pathD);
        }
        return result;
    }

    /**
     * Performs a union operation on the given paths.
     */
    private static function union(paths:Paths64):Paths64 {
        var clipper = new Clipper64();
        clipper.addSubjectPaths(paths);
        var result = new Paths64();
        clipper.execute(ClipType.Union, FillRule.NonZero, result);
        return result;
    }
}
