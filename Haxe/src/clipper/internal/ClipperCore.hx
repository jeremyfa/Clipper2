package clipper.internal;

import haxe.Int64;

// ============================================================================
// Enums
// ============================================================================

/**
 * Boolean clipping operation type.
 * Note: all clipping operations except for Difference are commutative.
 */
enum abstract ClipType(Int) to Int {
    var NoClip = 0;
    var Intersection = 1;
    var Union = 2;
    var Difference = 3;
    var Xor = 4;
}

/**
 * Path type for clipping operations.
 */
enum abstract PathType(Int) to Int {
    var Subject = 0;
    var Clip = 1;
}

/**
 * Polygon fill rule.
 * By far the most widely used filling rules for polygons are EvenOdd
 * and NonZero, sometimes called Alternate and Winding respectively.
 * https://en.wikipedia.org/wiki/Nonzero-rule
 */
enum abstract FillRule(Int) to Int {
    var EvenOdd = 0;
    var NonZero = 1;
    var Positive = 2;
    var Negative = 3;
}

/**
 * Result of point-in-polygon test.
 */
enum abstract PointInPolygonResult(Int) to Int {
    var IsOn = 0;
    var IsInside = 1;
    var IsOutside = 2;
}

// ============================================================================
// Point64 - 64-bit integer point
// ============================================================================

/**
 * Internal implementation class for Point64.
 */
class Point64Impl {
    public var x:Int64;
    public var y:Int64;
    #if clipper_usingz
    public var z:Int64;
    #end

    public inline function new(x:Int64, y:Int64 #if clipper_usingz , ?z:Int64 #end) {
        this.x = x;
        this.y = y;
        #if clipper_usingz
        this.z = z != null ? z : Int64.ofInt(0);
        #end
    }
}

/**
 * Point with 64-bit integer coordinates.
 */
abstract Point64(Point64Impl) from Point64Impl {
    public var x(get, set):Int64;
    public var y(get, set):Int64;
    #if clipper_usingz
    public var z(get, set):Int64;
    #end

    public inline function new(x:Int64, y:Int64 #if clipper_usingz , ?z:Int64 #end) {
        this = new Point64Impl(x, y #if clipper_usingz , z #end);
    }

    inline function get_x():Int64 return this.x;
    inline function set_x(value:Int64):Int64 return this.x = value;
    inline function get_y():Int64 return this.y;
    inline function set_y(value:Int64):Int64 return this.y = value;
    #if clipper_usingz
    inline function get_z():Int64 return this.z;
    inline function set_z(value:Int64):Int64 return this.z = value;
    #end

    /**
     * Copy constructor.
     */
    public static inline function copy(pt:Point64):Point64 {
        return new Point64(pt.x, pt.y #if clipper_usingz , pt.z #end);
    }

    /**
     * Create from Point64 with scale.
     */
    public static inline function fromScaled(pt:Point64, scale:Float):Point64 {
        return new Point64(
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.x) * scale),
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.y) * scale)
            #if clipper_usingz
            , InternalClipper.roundToInt64(InternalClipper.toFloat(pt.z) * scale)
            #end
        );
    }

    /**
     * Create from PointD.
     */
    public static inline function fromPointD(pt:PointD):Point64 {
        return new Point64(
            InternalClipper.roundToInt64(pt.x),
            InternalClipper.roundToInt64(pt.y)
            #if clipper_usingz
            , pt.z
            #end
        );
    }

    /**
     * Create from PointD with scale.
     */
    public static inline function fromPointDScaled(pt:PointD, scale:Float):Point64 {
        return new Point64(
            InternalClipper.roundToInt64(pt.x * scale),
            InternalClipper.roundToInt64(pt.y * scale)
            #if clipper_usingz
            , pt.z
            #end
        );
    }

    /**
     * Create from float coordinates.
     */
    public static inline function fromFloats(x:Float, y:Float #if clipper_usingz , z:Float = 0.0 #end):Point64 {
        return new Point64(
            InternalClipper.roundToInt64(x),
            InternalClipper.roundToInt64(y)
            #if clipper_usingz
            , InternalClipper.roundToInt64(z)
            #end
        );
    }

    @:op(A == B) public static inline function eq(lhs:Point64, rhs:Point64):Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y;
    }

    @:op(A != B) public static inline function neq(lhs:Point64, rhs:Point64):Bool {
        return lhs.x != rhs.x || lhs.y != rhs.y;
    }

    @:op(A + B) public static inline function add(lhs:Point64, rhs:Point64):Point64 {
        return new Point64(
            lhs.x + rhs.x,
            lhs.y + rhs.y
            #if clipper_usingz
            , lhs.z + rhs.z
            #end
        );
    }

    @:op(A - B) public static inline function sub(lhs:Point64, rhs:Point64):Point64 {
        return new Point64(
            lhs.x - rhs.x,
            lhs.y - rhs.y
            #if clipper_usingz
            , lhs.z - rhs.z
            #end
        );
    }

    public function toString():String {
        #if clipper_usingz
        return '${x},${y},${z} ';
        #else
        return '${x},${y} ';
        #end
    }

    public function hashCode():Int {
        var xVal:haxe.Int64 = x;
        var yVal:haxe.Int64 = y;
        return HashCode.combine(xVal.high, xVal.low, yVal.high, yVal.low);
    }
}

// ============================================================================
// PointD - Double-precision floating point
// ============================================================================

/**
 * Internal implementation class for PointD.
 */
class PointDImpl {
    public var x:Float;
    public var y:Float;
    #if clipper_usingz
    public var z:Int64;
    #end

    public inline function new(x:Float, y:Float #if clipper_usingz , ?z:Int64 #end) {
        this.x = x;
        this.y = y;
        #if clipper_usingz
        this.z = z != null ? z : Int64.ofInt(0);
        #end
    }
}

/**
 * Point with double-precision floating point coordinates.
 */
abstract PointD(PointDImpl) from PointDImpl {
    public var x(get, set):Float;
    public var y(get, set):Float;
    #if clipper_usingz
    public var z(get, set):Int64;
    #end

    public inline function new(x:Float, y:Float #if clipper_usingz , ?z:Int64 #end) {
        this = new PointDImpl(x, y #if clipper_usingz , z #end);
    }

    inline function get_x():Float return this.x;
    inline function set_x(value:Float):Float return this.x = value;
    inline function get_y():Float return this.y;
    inline function set_y(value:Float):Float return this.y = value;
    #if clipper_usingz
    inline function get_z():Int64 return this.z;
    inline function set_z(value:Int64):Int64 return this.z = value;
    #end

    /**
     * Copy constructor.
     */
    public static inline function copy(pt:PointD):PointD {
        return new PointD(pt.x, pt.y #if clipper_usingz , pt.z #end);
    }

    /**
     * Create from PointD with scale.
     */
    public static inline function fromScaled(pt:PointD, scale:Float):PointD {
        return new PointD(
            pt.x * scale,
            pt.y * scale
            #if clipper_usingz
            , pt.z
            #end
        );
    }

    /**
     * Create from Point64.
     */
    public static inline function fromPoint64(pt:Point64):PointD {
        return new PointD(
            InternalClipper.toFloat(pt.x),
            InternalClipper.toFloat(pt.y)
            #if clipper_usingz
            , pt.z
            #end
        );
    }

    /**
     * Create from Point64 with scale.
     */
    public static inline function fromPoint64Scaled(pt:Point64, scale:Float):PointD {
        return new PointD(
            InternalClipper.toFloat(pt.x) * scale,
            InternalClipper.toFloat(pt.y) * scale
            #if clipper_usingz
            , pt.z
            #end
        );
    }

    /**
     * Create from integer coordinates.
     */
    public static inline function fromInts(x:Int64, y:Int64 #if clipper_usingz , ?z:Int64 #end):PointD {
        return new PointD(
            InternalClipper.toFloat(x),
            InternalClipper.toFloat(y)
            #if clipper_usingz
            , z
            #end
        );
    }

    @:op(A == B) public static inline function eq(lhs:PointD, rhs:PointD):Bool {
        return InternalClipper.isAlmostZero(lhs.x - rhs.x) &&
               InternalClipper.isAlmostZero(lhs.y - rhs.y);
    }

    @:op(A != B) public static inline function neq(lhs:PointD, rhs:PointD):Bool {
        return !InternalClipper.isAlmostZero(lhs.x - rhs.x) ||
               !InternalClipper.isAlmostZero(lhs.y - rhs.y);
    }

    public inline function negate():Void {
        this.x = -this.x;
        this.y = -this.y;
    }

    public function toString(precision:Int = 2):String {
        var fmt = function(v:Float):String {
            var mult = Math.pow(10, precision);
            var rounded = Math.round(v * mult) / mult;
            return Std.string(rounded);
        };
        #if clipper_usingz
        return '${fmt(x)},${fmt(y)},${z}';
        #else
        return '${fmt(x)},${fmt(y)}';
        #end
    }

    public function hashCode():Int {
        // Convert floats to bits for hashing
        var xBits = Std.int(x * 1000000);
        var yBits = Std.int(y * 1000000);
        return HashCode.combine(xBits, 0, yBits, 0);
    }
}

// ============================================================================
// Rect64 - 64-bit integer rectangle
// ============================================================================

/**
 * Rectangle with 64-bit integer coordinates.
 */
class Rect64 {
    public var left:Int64;
    public var top:Int64;
    public var right:Int64;
    public var bottom:Int64;

    public function new(?l:Int64, ?t:Int64, ?r:Int64, ?b:Int64) {
        left = l != null ? l : Int64.ofInt(0);
        top = t != null ? t : Int64.ofInt(0);
        right = r != null ? r : Int64.ofInt(0);
        bottom = b != null ? b : Int64.ofInt(0);
    }

    public static function createInvalid():Rect64 {
        var rect = new Rect64();
        rect.left = InternalClipper.maxInt64;
        rect.top = InternalClipper.maxInt64;
        rect.right = InternalClipper.minInt64;
        rect.bottom = InternalClipper.minInt64;
        return rect;
    }

    public static inline function copy(rec:Rect64):Rect64 {
        return new Rect64(rec.left, rec.top, rec.right, rec.bottom);
    }

    public var width(get, set):Int64;
    inline function get_width():Int64 return right - left;
    inline function set_width(value:Int64):Int64 { right = left + value; return value; }

    public var height(get, set):Int64;
    inline function get_height():Int64 return bottom - top;
    inline function set_height(value:Int64):Int64 { bottom = top + value; return value; }

    public inline function isEmpty():Bool {
        return bottom <= top || right <= left;
    }

    public inline function isValid():Bool {
        return left < InternalClipper.maxInt64;
    }

    public inline function midPoint():Point64 {
        return new Point64((left + right) / 2, (top + bottom) / 2);
    }

    public inline function contains(pt:Point64):Bool {
        return pt.x > left && pt.x < right && pt.y > top && pt.y < bottom;
    }

    public inline function containsRect(rec:Rect64):Bool {
        return rec.left >= left && rec.right <= right &&
               rec.top >= top && rec.bottom <= bottom;
    }

    public inline function intersects(rec:Rect64):Bool {
        return (InternalClipper.max64(left, rec.left) <= InternalClipper.min64(right, rec.right)) &&
               (InternalClipper.max64(top, rec.top) <= InternalClipper.min64(bottom, rec.bottom));
    }

    public function asPath():Path64 {
        var result = new Path64();
        result.push(new Point64(left, top));
        result.push(new Point64(right, top));
        result.push(new Point64(right, bottom));
        result.push(new Point64(left, bottom));
        return result;
    }
}

// ============================================================================
// RectD - Double-precision floating point rectangle
// ============================================================================

/**
 * Rectangle with double-precision floating point coordinates.
 */
class RectD {
    public var left:Float;
    public var top:Float;
    public var right:Float;
    public var bottom:Float;

    public function new(l:Float = 0.0, t:Float = 0.0, r:Float = 0.0, b:Float = 0.0) {
        left = l;
        top = t;
        right = r;
        bottom = b;
    }

    public static function createInvalid():RectD {
        var rect = new RectD();
        rect.left = Math.POSITIVE_INFINITY;
        rect.top = Math.POSITIVE_INFINITY;
        rect.right = Math.NEGATIVE_INFINITY;
        rect.bottom = Math.NEGATIVE_INFINITY;
        return rect;
    }

    public static inline function copy(rec:RectD):RectD {
        return new RectD(rec.left, rec.top, rec.right, rec.bottom);
    }

    public var width(get, set):Float;
    inline function get_width():Float return right - left;
    inline function set_width(value:Float):Float { right = left + value; return value; }

    public var height(get, set):Float;
    inline function get_height():Float return bottom - top;
    inline function set_height(value:Float):Float { bottom = top + value; return value; }

    public inline function isEmpty():Bool {
        return bottom <= top || right <= left;
    }

    public inline function isValid():Bool {
        return left < Math.POSITIVE_INFINITY;
    }

    public inline function midPoint():PointD {
        return new PointD((left + right) / 2, (top + bottom) / 2);
    }

    public inline function contains(pt:PointD):Bool {
        return pt.x > left && pt.x < right && pt.y > top && pt.y < bottom;
    }

    public inline function containsRect(rec:RectD):Bool {
        return rec.left >= left && rec.right <= right &&
               rec.top >= top && rec.bottom <= bottom;
    }

    public inline function intersects(rec:RectD):Bool {
        return (Math.max(left, rec.left) < Math.min(right, rec.right)) &&
               (Math.max(top, rec.top) < Math.min(bottom, rec.bottom));
    }

    public function asPath():PathD {
        var result = new PathD();
        result.push(new PointD(left, top));
        result.push(new PointD(right, top));
        result.push(new PointD(right, bottom));
        result.push(new PointD(left, bottom));
        return result;
    }
}

// ============================================================================
// Path types - Arrays of points
// ============================================================================

/**
 * A single polygon path with 64-bit integer coordinates.
 */
typedef Path64 = Array<Point64>;

/**
 * Multiple polygon paths with 64-bit integer coordinates.
 */
typedef Paths64 = Array<Path64>;

/**
 * A single polygon path with double-precision floating point coordinates.
 */
typedef PathD = Array<PointD>;

/**
 * Multiple polygon paths with double-precision floating point coordinates.
 */
typedef PathsD = Array<PathD>;

// ============================================================================
// HashCode utility
// ============================================================================

/**
 * Hash code combining utility (xxHash32-inspired).
 */
class HashCode {
    static inline var PRIME1:Int = 0x9E3779B1;
    static inline var PRIME2:Int = 0x85EBCA77;
    static inline var PRIME3:Int = 0xC2B2AE3D;

    public static function combine(a:Int, b:Int, c:Int, d:Int):Int {
        var hash = PRIME1;
        hash = hash * PRIME2 + a;
        hash = hash * PRIME2 + b;
        hash = hash * PRIME2 + c;
        hash = hash * PRIME2 + d;
        hash ^= hash >>> 15;
        hash *= PRIME3;
        hash ^= hash >>> 13;
        return hash;
    }
}

// ============================================================================
// UInt128 - 128-bit unsigned integer for high precision calculations
// ============================================================================

/**
 * 128-bit unsigned integer for high precision multiplication.
 */
class UInt128 {
    public var lo64:haxe.Int64;
    public var hi64:haxe.Int64;

    public inline function new() {
        lo64 = haxe.Int64.ofInt(0);
        hi64 = haxe.Int64.ofInt(0);
    }
}

// ============================================================================
// InternalClipper - Internal utility functions
// ============================================================================

/**
 * Internal utility functions for Clipper operations.
 */
class InternalClipper {
    public static var maxInt64(default, never):Int64 = Int64.make(0x7FFFFFFF, 0xFFFFFFFF);
    public static var minInt64(default, never):Int64 = Int64.make(0x80000000, 0x00000000);

    /**
     * Convert Int64 to Float.
     */
    public static inline function toFloat(v:Int64):Float {
        // Handle sign correctly: high part is signed, low part is unsigned
        var high:Int = v.high;
        var low:Int = v.low;
        // low is unsigned, so we need to convert it properly
        var lowAsFloat:Float = if (low < 0) low + 4294967296.0 else low;
        return high * 4294967296.0 + lowAsFloat;
    }

    /**
     * Absolute value of Int64.
     */
    public static inline function abs64(v:Int64):Int64 {
        return v < Int64.ofInt(0) ? -v : v;
    }
    public static var maxCoord(default, never):Int64 = maxInt64 / 4;
    public static var maxCoordFloat(default, never):Float = 2305843009213693951.0; // maxCoord as float
    public static var minCoordFloat(default, never):Float = -2305843009213693951.0;
    public static var invalid64(default, never):Int64 = maxInt64;

    public static inline var floatingPointTolerance:Float = 1E-12;
    public static inline var defaultMinimumEdgeLength:Float = 0.1;

    static var precisionRangeError:String = "Error: Precision is out of range.";

    /**
     * Round to Int64 using MidpointRounding.AwayFromZero (like C#).
     */
    public static inline function roundToInt64(value:Float):Int64 {
        var rounded = value >= 0 ? Math.floor(value + 0.5) : Math.ceil(value - 0.5);
        return Int64.fromFloat(rounded);
    }

    /**
     * Round to Int64 using MidpointRounding.ToEven (banker's rounding).
     */
    public static function roundToEvenInt64(value:Float):Int64 {
        var rounded = Math.round(value);
        // Check if exactly at midpoint
        if (Math.abs(value - Math.floor(value) - 0.5) < 1e-10) {
            // Round to even
            var floor = Math.floor(value);
            if (Std.int(floor) % 2 == 0) {
                rounded = floor;
            } else {
                rounded = Math.ceil(value);
            }
        }
        return Int64.fromFloat(rounded);
    }

    /**
     * Check precision is within valid range.
     */
    public static inline function checkPrecision(precision:Int):Void {
        if (precision < -8 || precision > 8)
            throw precisionRangeError;
    }

    /**
     * Check if a floating point value is approximately zero.
     */
    public static inline function isAlmostZero(value:Float):Bool {
        return Math.abs(value) <= floatingPointTolerance;
    }

    /**
     * Returns -1, 0, or 1 based on sign.
     */
    public static inline function triSign(x:Int64):Int {
        return if (x < 0) -1 else if (x > 0) 1 else 0;
    }

    /**
     * Min of two Int64 values.
     */
    public static inline function min64(a:Int64, b:Int64):Int64 {
        return if (a < b) a else b;
    }

    /**
     * Max of two Int64 values.
     */
    public static inline function max64(a:Int64, b:Int64):Int64 {
        return if (a > b) a else b;
    }

    /**
     * Cross product of three points (returns double to avoid overflow).
     */
    public static inline function crossProduct(pt1:Point64, pt2:Point64, pt3:Point64):Float {
        return (toFloat(pt2.x) - toFloat(pt1.x)) * (toFloat(pt3.y) - toFloat(pt2.y)) -
               (toFloat(pt2.y) - toFloat(pt1.y)) * (toFloat(pt3.x) - toFloat(pt2.x));
    }

    /**
     * Cross product sign with high precision (using 128-bit multiplication).
     */
    public static function crossProductSign(pt1:Point64, pt2:Point64, pt3:Point64):Int {
        var a = pt2.x - pt1.x;
        var b = pt3.y - pt2.y;
        var c = pt2.y - pt1.y;
        var d = pt3.x - pt2.x;

        var ab = multiplyUInt64(abs64(a), abs64(b));
        var cd = multiplyUInt64(abs64(c), abs64(d));

        var signAB = triSign(a) * triSign(b);
        var signCD = triSign(c) * triSign(d);

        if (signAB == signCD) {
            var result:Int;
            if (ab.hi64 == cd.hi64) {
                if (ab.lo64 == cd.lo64) return 0;
                result = (ab.lo64 > cd.lo64) ? 1 : -1;
            } else {
                result = (ab.hi64 > cd.hi64) ? 1 : -1;
            }
            return (signAB > 0) ? result : -result;
        }
        return (signAB > signCD) ? 1 : -1;
    }

    /**
     * Multiply two 64-bit unsigned integers to get 128-bit result.
     */
    public static function multiplyUInt64(a:Int64, b:Int64):UInt128 {
        // Use 32-bit multiplication with carry
        var aRaw:haxe.Int64 = a;
        var bRaw:haxe.Int64 = b;
        var aLo:haxe.Int64 = haxe.Int64.make(0, aRaw.low & 0xFFFFFFFF);
        var aHi:haxe.Int64 = haxe.Int64.make(0, aRaw.high & 0xFFFFFFFF);
        var bLo:haxe.Int64 = haxe.Int64.make(0, bRaw.low & 0xFFFFFFFF);
        var bHi:haxe.Int64 = haxe.Int64.make(0, bRaw.high & 0xFFFFFFFF);

        var x1 = aLo * bLo;
        var x2 = aHi * bLo + (x1 >>> 32);
        var x3 = aLo * bHi + (x2 & haxe.Int64.make(0, 0xFFFFFFFF));

        var result = new UInt128();
        result.lo64 = ((x3 & haxe.Int64.make(0, 0xFFFFFFFF)) << 32) | (x1 & haxe.Int64.make(0, 0xFFFFFFFF));
        result.hi64 = aHi * bHi + (x2 >>> 32) + (x3 >>> 32);
        return result;
    }

    /**
     * Check if products a*b and c*d are equal (using 128-bit precision).
     */
    public static function productsAreEqual(a:Int64, b:Int64, c:Int64, d:Int64):Bool {
        var absA = abs64(a);
        var absB = abs64(b);
        var absC = abs64(c);
        var absD = abs64(d);

        var mul_ab = multiplyUInt64(absA, absB);
        var mul_cd = multiplyUInt64(absC, absD);

        var sign_ab = triSign(a) * triSign(b);
        var sign_cd = triSign(c) * triSign(d);

        return mul_ab.lo64 == mul_cd.lo64 && mul_ab.hi64 == mul_cd.hi64 && sign_ab == sign_cd;
    }

    /**
     * Check if three points are collinear.
     */
    public static inline function isCollinear(pt1:Point64, sharedPt:Point64, pt2:Point64):Bool {
        var a = sharedPt.x - pt1.x;
        var b = pt2.y - sharedPt.y;
        var c = sharedPt.y - pt1.y;
        var d = pt2.x - sharedPt.x;
        return productsAreEqual(a, b, c, d);
    }

    /**
     * Dot product of three points.
     */
    public static inline function dotProduct(pt1:Point64, pt2:Point64, pt3:Point64):Float {
        return (toFloat(pt2.x) - toFloat(pt1.x)) * (toFloat(pt3.x) - toFloat(pt2.x)) +
               (toFloat(pt2.y) - toFloat(pt1.y)) * (toFloat(pt3.y) - toFloat(pt2.y));
    }

    /**
     * Cross product of two PointD vectors.
     */
    public static inline function crossProductD(vec1:PointD, vec2:PointD):Float {
        return vec1.y * vec2.x - vec2.y * vec1.x;
    }

    /**
     * Dot product of two PointD vectors.
     */
    public static inline function dotProductD(vec1:PointD, vec2:PointD):Float {
        return vec1.x * vec2.x + vec1.y * vec2.y;
    }

    /**
     * Check cast to Int64, returns Invalid64 if out of range.
     */
    public static inline function checkCastInt64(val:Float):Int64 {
        if (val >= maxCoordFloat || val <= minCoordFloat) return invalid64;
        return roundToInt64(val);
    }

    /**
     * Get line intersection point (Point64 version).
     * Returns true if lines are non-parallel. ip is constrained to seg1.
     */
    public static function getLineIntersectPt64(ln1a:Point64, ln1b:Point64, ln2a:Point64, ln2b:Point64):{ip:Point64, success:Bool} {
        var dy1 = toFloat(ln1b.y) - toFloat(ln1a.y);
        var dx1 = toFloat(ln1b.x) - toFloat(ln1a.x);
        var dy2 = toFloat(ln2b.y) - toFloat(ln2a.y);
        var dx2 = toFloat(ln2b.x) - toFloat(ln2a.x);
        var det = dy1 * dx2 - dy2 * dx1;

        if (det == 0.0) {
            return {ip: new Point64(0, 0), success: false};
        }

        var t = ((toFloat(ln1a.x) - toFloat(ln2a.x)) * dy2 - (toFloat(ln1a.y) - toFloat(ln2a.y)) * dx2) / det;
        var ip:Point64;
        if (t <= 0.0) {
            ip = Point64.copy(ln1a);
        } else if (t >= 1.0) {
            ip = Point64.copy(ln1b);
        } else {
            ip = new Point64(
                Int64.fromFloat(toFloat(ln1a.x) + t * dx1),
                Int64.fromFloat(toFloat(ln1a.y) + t * dy1)
                #if clipper_usingz
                , 0
                #end
            );
        }
        return {ip: ip, success: true};
    }

    /**
     * Get line intersection point (PointD version).
     */
    public static function getLineIntersectPtD(ln1a:PointD, ln1b:PointD, ln2a:PointD, ln2b:PointD):{ip:PointD, success:Bool} {
        var dy1 = ln1b.y - ln1a.y;
        var dx1 = ln1b.x - ln1a.x;
        var dy2 = ln2b.y - ln2a.y;
        var dx2 = ln2b.x - ln2a.x;
        var det = dy1 * dx2 - dy2 * dx1;

        if (det == 0.0) {
            return {ip: new PointD(0, 0), success: false};
        }

        var t = ((ln1a.x - ln2a.x) * dy2 - (ln1a.y - ln2a.y) * dx2) / det;
        var ip:PointD;
        if (t <= 0.0) {
            ip = PointD.copy(ln1a);
        } else if (t >= 1.0) {
            ip = PointD.copy(ln1b);
        } else {
            ip = new PointD(
                ln1a.x + t * dx1,
                ln1a.y + t * dy1
                #if clipper_usingz
                , 0
                #end
            );
        }
        return {ip: ip, success: true};
    }

    /**
     * Check if two segments intersect.
     */
    public static function segsIntersect(seg1a:Point64, seg1b:Point64, seg2a:Point64, seg2b:Point64, inclusive:Bool = false):Bool {
        var dy1 = toFloat(seg1b.y) - toFloat(seg1a.y);
        var dx1 = toFloat(seg1b.x) - toFloat(seg1a.x);
        var dy2 = toFloat(seg2b.y) - toFloat(seg2a.y);
        var dx2 = toFloat(seg2b.x) - toFloat(seg2a.x);
        var cp = dy1 * dx2 - dy2 * dx1;
        if (cp == 0) return false; // parallel segments

        if (inclusive) {
            var t = (toFloat(seg1a.x) - toFloat(seg2a.x)) * dy2 - (toFloat(seg1a.y) - toFloat(seg2a.y)) * dx2;
            if (t == 0) return true;
            if (t > 0) {
                if (cp < 0 || t > cp) return false;
            } else if (cp > 0 || t < cp) return false;

            t = (toFloat(seg1a.x) - toFloat(seg2a.x)) * dy1 - (toFloat(seg1a.y) - toFloat(seg2a.y)) * dx1;
            if (t == 0) return true;
            if (t > 0) return (cp > 0 && t <= cp);
            else return (cp < 0 && t >= cp);
        } else {
            var t = (toFloat(seg1a.x) - toFloat(seg2a.x)) * dy2 - (toFloat(seg1a.y) - toFloat(seg2a.y)) * dx2;
            if (t == 0) return false;
            if (t > 0) {
                if (cp < 0 || t >= cp) return false;
            } else if (cp > 0 || t <= cp) return false;

            t = (toFloat(seg1a.x) - toFloat(seg2a.x)) * dy1 - (toFloat(seg1a.y) - toFloat(seg2a.y)) * dx1;
            if (t == 0) return false;
            if (t > 0) return (cp > 0 && t < cp);
            else return (cp < 0 && t > cp);
        }
    }

    /**
     * Get bounding rectangle of a path.
     */
    public static function getBounds(path:Path64):Rect64 {
        if (path.length == 0) return new Rect64();
        var result = Rect64.createInvalid();
        for (pt in path) {
            if (pt.x < result.left) result.left = pt.x;
            if (pt.x > result.right) result.right = pt.x;
            if (pt.y < result.top) result.top = pt.y;
            if (pt.y > result.bottom) result.bottom = pt.y;
        }
        return result;
    }

    /**
     * Get closest point on segment to off point.
     */
    public static function getClosestPtOnSegment(offPt:Point64, seg1:Point64, seg2:Point64):Point64 {
        if (seg1.x == seg2.x && seg1.y == seg2.y) return Point64.copy(seg1);
        var dx = toFloat(seg2.x) - toFloat(seg1.x);
        var dy = toFloat(seg2.y) - toFloat(seg1.y);
        var q = ((toFloat(offPt.x) - toFloat(seg1.x)) * dx +
                 (toFloat(offPt.y) - toFloat(seg1.y)) * dy) / (dx * dx + dy * dy);
        if (q < 0) q = 0;
        else if (q > 1) q = 1;
        // Use MidpointRounding.ToEven to match C++ nearbyint behavior
        return new Point64(
            roundToEvenInt64(toFloat(seg1.x) + q * dx),
            roundToEvenInt64(toFloat(seg1.y) + q * dy)
        );
    }

    /**
     * Point in polygon test.
     */
    public static function pointInPolygon(pt:Point64, polygon:Path64):PointInPolygonResult {
        var len = polygon.length;
        var start = 0;
        if (len < 3) return PointInPolygonResult.IsOutside;

        while (start < len && polygon[start].y == pt.y) start++;
        if (start == len) return PointInPolygonResult.IsOutside;

        var isAbove = polygon[start].y < pt.y;
        var startingAbove = isAbove;
        var val = 0;
        var i = start + 1;
        var end = len;

        while (true) {
            if (i == end) {
                if (end == 0 || start == 0) break;
                end = start;
                i = 0;
            }

            if (isAbove) {
                while (i < end && polygon[i].y < pt.y) i++;
            } else {
                while (i < end && polygon[i].y > pt.y) i++;
            }

            if (i == end) continue;

            var curr = polygon[i];
            var prev = (i > 0) ? polygon[i - 1] : polygon[len - 1];

            if (curr.y == pt.y) {
                if (curr.x == pt.x || (curr.y == prev.y &&
                    ((pt.x < prev.x) != (pt.x < curr.x))))
                    return PointInPolygonResult.IsOn;
                i++;
                if (i == start) break;
                continue;
            }

            if (pt.x < curr.x && pt.x < prev.x) {
                // we're only interested in edges crossing on the left
            } else if (pt.x > prev.x && pt.x > curr.x) {
                val = 1 - val; // toggle val
            } else {
                var cps2 = crossProductSign(prev, curr, pt);
                if (cps2 == 0) return PointInPolygonResult.IsOn;
                if ((cps2 < 0) == isAbove) val = 1 - val;
            }
            isAbove = !isAbove;
            i++;
        }

        if (isAbove == startingAbove) return val == 0 ? PointInPolygonResult.IsOutside : PointInPolygonResult.IsInside;
        if (i == len) i = 0;
        var cps = (i == 0) ?
            crossProductSign(polygon[len - 1], polygon[0], pt) :
            crossProductSign(polygon[i - 1], polygon[i], pt);

        if (cps == 0) return PointInPolygonResult.IsOn;
        if ((cps < 0) == isAbove) val = 1 - val;
        return val == 0 ? PointInPolygonResult.IsOutside : PointInPolygonResult.IsInside;
    }

    /**
     * Check if path2 contains path1.
     */
    public static function path2ContainsPath1(path1:Path64, path2:Path64):Bool {
        var pip = PointInPolygonResult.IsOn;
        for (pt in path1) {
            switch (pointInPolygon(pt, path2)) {
                case PointInPolygonResult.IsOutside:
                    if (pip == PointInPolygonResult.IsOutside) return false;
                    pip = PointInPolygonResult.IsOutside;
                case PointInPolygonResult.IsInside:
                    if (pip == PointInPolygonResult.IsInside) return true;
                    pip = PointInPolygonResult.IsInside;
                default:
            }
        }
        // since path1's location is still equivocal, check its midpoint
        var mp = getBounds(path1).midPoint();
        return pointInPolygon(mp, path2) != PointInPolygonResult.IsOutside;
    }

    /**
     * Calculate the signed area of a polygon path.
     * Returns positive for counter-clockwise paths, negative for clockwise.
     */
    public static function area(path:Path64):Float {
        var a:Float = 0.0;
        var cnt = path.length;
        if (cnt < 3) return 0.0;
        var prevPt = path[cnt - 1];
        for (pt in path) {
            a += (toFloat(prevPt.y) + toFloat(pt.y)) * (toFloat(prevPt.x) - toFloat(pt.x));
            prevPt = pt;
        }
        return a * 0.5;
    }

    /**
     * Calculate the signed area of multiple paths.
     */
    public static function areaPaths(paths:Paths64):Float {
        var a:Float = 0.0;
        for (path in paths) {
            a += area(path);
        }
        return a;
    }

    #if clipper_usingz
    /**
     * Set Z coordinate for all points in a path.
     */
    public static function setZ(path:Path64, z:Int64):Path64 {
        var result = new Path64();
        for (pt in path) {
            result.push(new Point64(pt.x, pt.y, z));
        }
        return result;
    }
    #end
}
