package clipper;

// ============================================================================
// ClipperInt64 - Abstraction for 64-bit integers
// ============================================================================

#if clipper_int64_as_float64

/**
 * Float-backed implementation for better JS performance.
 * Uses native Float which is more efficient on JS target.
 */
abstract ClipperInt64(Float) from Float to Float {
    public static inline var maxValue:ClipperInt64 = 9223372036854775807.0;
    public static inline var minValue:ClipperInt64 = -9223372036854775808.0;

    public inline function new(v:Float) {
        this = v;
    }

    @:from public static inline function ofInt(v:Int):ClipperInt64 {
        return new ClipperInt64(v);
    }

    @:from public static inline function fromFloat(v:Float):ClipperInt64 {
        return new ClipperInt64(v);
    }

    public static inline function make(high:Int, low:Int):ClipperInt64 {
        var lowAsFloat:Float = if (low < 0) low + 4294967296.0 else low;
        return new ClipperInt64(high * 4294967296.0 + lowAsFloat);
    }

    public inline function toFloat():Float {
        return this;
    }

    public inline function toInt():Int {
        return Std.int(this);
    }

    public inline function getHigh():Int {
        return Std.int(this / 4294967296.0);
    }

    public inline function getLow():Int {
        var remainder = this % 4294967296.0;
        return Std.int(if (remainder < 0) remainder + 4294967296.0 else remainder);
    }

    // Arithmetic operators
    @:op(A + B) static inline function add(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return new ClipperInt64((a : Float) + (b : Float));
    }

    @:op(A - B) static inline function sub(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return new ClipperInt64((a : Float) - (b : Float));
    }

    @:op(A * B) static inline function mul(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return new ClipperInt64((a : Float) * (b : Float));
    }

    @:op(A / B) static inline function div(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        var result = (a : Float) / (b : Float);
        return new ClipperInt64(result >= 0 ? Math.floor(result) : Math.ceil(result));
    }

    @:op(A % B) static inline function mod(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return new ClipperInt64((a : Float) % (b : Float));
    }

    @:op(-A) static inline function neg(a:ClipperInt64):ClipperInt64 {
        return new ClipperInt64(-(a : Float));
    }

    // Comparison operators
    @:op(A == B) static inline function eq(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : Float) == (b : Float);
    }

    @:op(A != B) static inline function neq(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : Float) != (b : Float);
    }

    @:op(A < B) static inline function lt(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : Float) < (b : Float);
    }

    @:op(A <= B) static inline function lte(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : Float) <= (b : Float);
    }

    @:op(A > B) static inline function gt(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : Float) > (b : Float);
    }

    @:op(A >= B) static inline function gte(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : Float) >= (b : Float);
    }

    // Int comparison operators
    @:op(A < B) static inline function ltInt(a:ClipperInt64, b:Int):Bool {
        return (a : Float) < b;
    }

    @:op(A <= B) static inline function lteInt(a:ClipperInt64, b:Int):Bool {
        return (a : Float) <= b;
    }

    @:op(A > B) static inline function gtInt(a:ClipperInt64, b:Int):Bool {
        return (a : Float) > b;
    }

    @:op(A >= B) static inline function gteInt(a:ClipperInt64, b:Int):Bool {
        return (a : Float) >= b;
    }

    @:op(A == B) static inline function eqInt(a:ClipperInt64, b:Int):Bool {
        return (a : Float) == b;
    }

    @:op(A != B) static inline function neqInt(a:ClipperInt64, b:Int):Bool {
        return (a : Float) != b;
    }

    // Helper methods
    public inline function abs():ClipperInt64 {
        return new ClipperInt64(Math.abs(this));
    }

    public static inline function min(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return new ClipperInt64(Math.min((a : Float), (b : Float)));
    }

    public static inline function max(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return new ClipperInt64(Math.max((a : Float), (b : Float)));
    }

    public inline function triSign():Int {
        return if ((this : Float) < 0) -1 else if ((this : Float) > 0) 1 else 0;
    }

    /**
     * Round to ClipperInt64 using MidpointRounding.AwayFromZero (like C#).
     */
    public static inline function roundFromFloat(value:Float):ClipperInt64 {
        var rounded = value >= 0 ? Math.floor(value + 0.5) : Math.ceil(value - 0.5);
        return new ClipperInt64(rounded);
    }

    /**
     * Round to ClipperInt64 using MidpointRounding.ToEven (banker's rounding).
     */
    public static function roundEvenFromFloat(value:Float):ClipperInt64 {
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
        return new ClipperInt64(rounded);
    }
}

#else

/**
 * Default haxe.Int64-backed implementation for full precision.
 */
abstract ClipperInt64(haxe.Int64) from haxe.Int64 to haxe.Int64 {
    public static var maxValue(get, never):ClipperInt64;
    public static var minValue(get, never):ClipperInt64;

    static inline function get_maxValue():ClipperInt64 {
        return cast haxe.Int64.make(0x7FFFFFFF, 0xFFFFFFFF);
    }

    static inline function get_minValue():ClipperInt64 {
        return cast haxe.Int64.make(0x80000000, 0x00000000);
    }

    public inline function new(v:haxe.Int64) {
        this = v;
    }

    @:from public static inline function ofInt(v:Int):ClipperInt64 {
        return cast haxe.Int64.ofInt(v);
    }

    @:from public static inline function fromFloat(v:Float):ClipperInt64 {
        return cast haxe.Int64.fromFloat(v);
    }

    public static inline function make(high:Int, low:Int):ClipperInt64 {
        return cast haxe.Int64.make(high, low);
    }

    public inline function toFloat():Float {
        var high:Float = this.high;
        var low:Float = this.low;
        var lowAsFloat = if (low < 0) low + 4294967296.0 else low;
        return high * 4294967296.0 + lowAsFloat;
    }

    public inline function toInt():Int {
        return this.low;
    }

    public inline function getHigh():Int {
        return this.high;
    }

    public inline function getLow():Int {
        return this.low;
    }

    // Arithmetic operators
    @:op(A + B) static inline function add(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return cast((a : haxe.Int64) + (b : haxe.Int64));
    }

    @:op(A - B) static inline function sub(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return cast((a : haxe.Int64) - (b : haxe.Int64));
    }

    @:op(A * B) static inline function mul(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return cast((a : haxe.Int64) * (b : haxe.Int64));
    }

    @:op(A / B) static inline function div(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return cast haxe.Int64.div((a : haxe.Int64), (b : haxe.Int64));
    }

    @:op(A % B) static inline function mod(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return cast haxe.Int64.mod((a : haxe.Int64), (b : haxe.Int64));
    }

    @:op(-A) static inline function neg(a:ClipperInt64):ClipperInt64 {
        return cast haxe.Int64.neg((a : haxe.Int64));
    }

    // Comparison operators
    @:op(A == B) static inline function eq(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : haxe.Int64) == (b : haxe.Int64);
    }

    @:op(A != B) static inline function neq(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : haxe.Int64) != (b : haxe.Int64);
    }

    @:op(A < B) static inline function lt(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : haxe.Int64) < (b : haxe.Int64);
    }

    @:op(A <= B) static inline function lte(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : haxe.Int64) <= (b : haxe.Int64);
    }

    @:op(A > B) static inline function gt(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : haxe.Int64) > (b : haxe.Int64);
    }

    @:op(A >= B) static inline function gte(a:ClipperInt64, b:ClipperInt64):Bool {
        return (a : haxe.Int64) >= (b : haxe.Int64);
    }

    // Int comparison operators
    @:op(A < B) static inline function ltInt(a:ClipperInt64, b:Int):Bool {
        return (a : haxe.Int64) < haxe.Int64.ofInt(b);
    }

    @:op(A <= B) static inline function lteInt(a:ClipperInt64, b:Int):Bool {
        return (a : haxe.Int64) <= haxe.Int64.ofInt(b);
    }

    @:op(A > B) static inline function gtInt(a:ClipperInt64, b:Int):Bool {
        return (a : haxe.Int64) > haxe.Int64.ofInt(b);
    }

    @:op(A >= B) static inline function gteInt(a:ClipperInt64, b:Int):Bool {
        return (a : haxe.Int64) >= haxe.Int64.ofInt(b);
    }

    @:op(A == B) static inline function eqInt(a:ClipperInt64, b:Int):Bool {
        return (a : haxe.Int64) == haxe.Int64.ofInt(b);
    }

    @:op(A != B) static inline function neqInt(a:ClipperInt64, b:Int):Bool {
        return (a : haxe.Int64) != haxe.Int64.ofInt(b);
    }

    // Helper methods
    public inline function abs():ClipperInt64 {
        return cast(this < haxe.Int64.ofInt(0) ? haxe.Int64.neg(this) : this);
    }

    public static inline function min(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return if ((a : haxe.Int64) < (b : haxe.Int64)) a else b;
    }

    public static inline function max(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return if ((a : haxe.Int64) > (b : haxe.Int64)) a else b;
    }

    public inline function triSign():Int {
        var zero = haxe.Int64.ofInt(0);
        return if (this < zero) -1 else if (this > zero) 1 else 0;
    }

    /**
     * Round to ClipperInt64 using MidpointRounding.AwayFromZero (like C#).
     */
    public static inline function roundFromFloat(value:Float):ClipperInt64 {
        var rounded = value >= 0 ? Math.floor(value + 0.5) : Math.ceil(value - 0.5);
        return cast haxe.Int64.fromFloat(rounded);
    }

    /**
     * Round to ClipperInt64 using MidpointRounding.ToEven (banker's rounding).
     */
    public static function roundEvenFromFloat(value:Float):ClipperInt64 {
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
        return cast haxe.Int64.fromFloat(rounded);
    }
}

#end

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
    public var x:ClipperInt64;
    public var y:ClipperInt64;
    #if clipper_usingz
    public var z:ClipperInt64;
    #end

    public inline function new(x:ClipperInt64, y:ClipperInt64 #if clipper_usingz , ?z:ClipperInt64 #end) {
        this.x = x;
        this.y = y;
        #if clipper_usingz
        this.z = z != null ? z : ClipperInt64.ofInt(0);
        #end
    }
}

/**
 * Point with 64-bit integer coordinates.
 */
abstract Point64(Point64Impl) from Point64Impl {
    public var x(get, set):ClipperInt64;
    public var y(get, set):ClipperInt64;
    #if clipper_usingz
    public var z(get, set):ClipperInt64;
    #end

    public inline function new(x:ClipperInt64, y:ClipperInt64 #if clipper_usingz , ?z:ClipperInt64 #end) {
        this = new Point64Impl(x, y #if clipper_usingz , z #end);
    }

    inline function get_x():ClipperInt64 return this.x;
    inline function set_x(value:ClipperInt64):ClipperInt64 return this.x = value;
    inline function get_y():ClipperInt64 return this.y;
    inline function set_y(value:ClipperInt64):ClipperInt64 return this.y = value;
    #if clipper_usingz
    inline function get_z():ClipperInt64 return this.z;
    inline function set_z(value:ClipperInt64):ClipperInt64 return this.z = value;
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
            ClipperInt64.roundFromFloat(pt.x.toFloat() * scale),
            ClipperInt64.roundFromFloat(pt.y.toFloat() * scale)
            #if clipper_usingz
            , ClipperInt64.roundFromFloat(pt.z.toFloat() * scale)
            #end
        );
    }

    /**
     * Create from PointD.
     */
    public static inline function fromPointD(pt:PointD):Point64 {
        return new Point64(
            ClipperInt64.roundFromFloat(pt.x),
            ClipperInt64.roundFromFloat(pt.y)
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
            ClipperInt64.roundFromFloat(pt.x * scale),
            ClipperInt64.roundFromFloat(pt.y * scale)
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
            ClipperInt64.roundFromFloat(x),
            ClipperInt64.roundFromFloat(y)
            #if clipper_usingz
            , ClipperInt64.roundFromFloat(z)
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
        return HashCode.combine(x.getHigh(), x.getLow(), y.getHigh(), y.getLow());
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
    public var z:ClipperInt64;
    #end

    public inline function new(x:Float, y:Float #if clipper_usingz , ?z:ClipperInt64 #end) {
        this.x = x;
        this.y = y;
        #if clipper_usingz
        this.z = z != null ? z : ClipperInt64.ofInt(0);
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
    public var z(get, set):ClipperInt64;
    #end

    public inline function new(x:Float, y:Float #if clipper_usingz , ?z:ClipperInt64 #end) {
        this = new PointDImpl(x, y #if clipper_usingz , z #end);
    }

    inline function get_x():Float return this.x;
    inline function set_x(value:Float):Float return this.x = value;
    inline function get_y():Float return this.y;
    inline function set_y(value:Float):Float return this.y = value;
    #if clipper_usingz
    inline function get_z():ClipperInt64 return this.z;
    inline function set_z(value:ClipperInt64):ClipperInt64 return this.z = value;
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
            pt.x.toFloat(),
            pt.y.toFloat()
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
            pt.x.toFloat() * scale,
            pt.y.toFloat() * scale
            #if clipper_usingz
            , pt.z
            #end
        );
    }

    /**
     * Create from integer coordinates.
     */
    public static inline function fromInts(x:ClipperInt64, y:ClipperInt64 #if clipper_usingz , ?z:ClipperInt64 #end):PointD {
        return new PointD(
            x.toFloat(),
            y.toFloat()
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
    public var left:ClipperInt64;
    public var top:ClipperInt64;
    public var right:ClipperInt64;
    public var bottom:ClipperInt64;

    public function new(?l:ClipperInt64, ?t:ClipperInt64, ?r:ClipperInt64, ?b:ClipperInt64) {
        left = l != null ? l : ClipperInt64.ofInt(0);
        top = t != null ? t : ClipperInt64.ofInt(0);
        right = r != null ? r : ClipperInt64.ofInt(0);
        bottom = b != null ? b : ClipperInt64.ofInt(0);
    }

    public static function createInvalid():Rect64 {
        var rect = new Rect64();
        rect.left = ClipperInt64.maxValue;
        rect.top = ClipperInt64.maxValue;
        rect.right = ClipperInt64.minValue;
        rect.bottom = ClipperInt64.minValue;
        return rect;
    }

    public static inline function copy(rec:Rect64):Rect64 {
        return new Rect64(rec.left, rec.top, rec.right, rec.bottom);
    }

    public var width(get, set):ClipperInt64;
    inline function get_width():ClipperInt64 return right - left;
    inline function set_width(value:ClipperInt64):ClipperInt64 { right = left + value; return value; }

    public var height(get, set):ClipperInt64;
    inline function get_height():ClipperInt64 return bottom - top;
    inline function set_height(value:ClipperInt64):ClipperInt64 { bottom = top + value; return value; }

    public inline function isEmpty():Bool {
        return bottom <= top || right <= left;
    }

    public inline function isValid():Bool {
        return left < ClipperInt64.maxValue;
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
        return (ClipperInt64.max(left, rec.left) <= ClipperInt64.min(right, rec.right)) &&
               (ClipperInt64.max(top, rec.top) <= ClipperInt64.min(bottom, rec.bottom));
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
    public var lo64:ClipperInt64;
    public var hi64:ClipperInt64;

    public inline function new() {
        lo64 = ClipperInt64.ofInt(0);
        hi64 = ClipperInt64.ofInt(0);
    }
}

// ============================================================================
// InternalClipper - Internal utility functions
// ============================================================================

/**
 * Internal utility functions for Clipper operations.
 */
class InternalClipper {
    public static var maxInt64(get, never):ClipperInt64;
    public static var minInt64(get, never):ClipperInt64;
    public static var maxCoord(get, never):ClipperInt64;
    public static var invalid64(get, never):ClipperInt64;

    static inline function get_maxInt64():ClipperInt64 return ClipperInt64.maxValue;
    static inline function get_minInt64():ClipperInt64 return ClipperInt64.minValue;
    static inline function get_maxCoord():ClipperInt64 return ClipperInt64.maxValue / 4;
    static inline function get_invalid64():ClipperInt64 return ClipperInt64.maxValue;

    public static var maxCoordFloat(default, never):Float = 2305843009213693951.0; // maxCoord as float
    public static var minCoordFloat(default, never):Float = -2305843009213693951.0;

    public static inline var floatingPointTolerance:Float = 1E-12;
    public static inline var defaultMinimumEdgeLength:Float = 0.1;

    static var precisionRangeError:String = "Error: Precision is out of range.";

    // Legacy helper methods that delegate to ClipperInt64
    public static inline function toFloat(v:ClipperInt64):Float {
        return v.toFloat();
    }

    public static inline function abs64(v:ClipperInt64):ClipperInt64 {
        return v.abs();
    }

    public static inline function roundToInt64(value:Float):ClipperInt64 {
        return ClipperInt64.roundFromFloat(value);
    }

    public static inline function roundToEvenInt64(value:Float):ClipperInt64 {
        return ClipperInt64.roundEvenFromFloat(value);
    }

    public static inline function triSign(x:ClipperInt64):Int {
        return x.triSign();
    }

    public static inline function min64(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return ClipperInt64.min(a, b);
    }

    public static inline function max64(a:ClipperInt64, b:ClipperInt64):ClipperInt64 {
        return ClipperInt64.max(a, b);
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
     * Cross product of three points (returns double to avoid overflow).
     */
    public static inline function crossProduct(pt1:Point64, pt2:Point64, pt3:Point64):Float {
        return (pt2.x.toFloat() - pt1.x.toFloat()) * (pt3.y.toFloat() - pt2.y.toFloat()) -
               (pt2.y.toFloat() - pt1.y.toFloat()) * (pt3.x.toFloat() - pt2.x.toFloat());
    }

    /**
     * Cross product sign with high precision (using 128-bit multiplication).
     */
    public static function crossProductSign(pt1:Point64, pt2:Point64, pt3:Point64):Int {
        var a = pt2.x - pt1.x;
        var b = pt3.y - pt2.y;
        var c = pt2.y - pt1.y;
        var d = pt3.x - pt2.x;

        var ab = multiplyUInt64(a.abs(), b.abs());
        var cd = multiplyUInt64(c.abs(), d.abs());

        var signAB = a.triSign() * b.triSign();
        var signCD = c.triSign() * d.triSign();

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
    #if clipper_int64_as_float64
    public static function multiplyUInt64(a:ClipperInt64, b:ClipperInt64):UInt128 {
        // For Float mode: use simpler multiplication
        // This may lose precision for very large values, but is acceptable for JS performance
        var result = new UInt128();
        var product = a.toFloat() * b.toFloat();
        // Store the result - for comparison purposes we just need consistent ordering
        result.lo64 = ClipperInt64.fromFloat(product % 18446744073709551616.0);
        result.hi64 = ClipperInt64.fromFloat(product / 18446744073709551616.0);
        return result;
    }
    #else
    public static function multiplyUInt64(a:ClipperInt64, b:ClipperInt64):UInt128 {
        // Use 32-bit multiplication with carry
        var aLo:ClipperInt64 = ClipperInt64.make(0, a.getLow() & 0xFFFFFFFF);
        var aHi:ClipperInt64 = ClipperInt64.make(0, a.getHigh() & 0xFFFFFFFF);
        var bLo:ClipperInt64 = ClipperInt64.make(0, b.getLow() & 0xFFFFFFFF);
        var bHi:ClipperInt64 = ClipperInt64.make(0, b.getHigh() & 0xFFFFFFFF);

        var x1 = aLo * bLo;

        // For shift operations, we need to use haxe.Int64 directly
        var x1Raw:haxe.Int64 = cast x1;
        var x1Shifted:ClipperInt64 = cast(x1Raw >>> 32);
        var x2 = aHi * bLo + x1Shifted;

        var x2Raw:haxe.Int64 = cast x2;
        var mask:haxe.Int64 = haxe.Int64.make(0, 0xFFFFFFFF);
        var x2Masked:ClipperInt64 = cast(x2Raw & mask);
        var x3 = aLo * bHi + x2Masked;

        var result = new UInt128();
        var x3Raw:haxe.Int64 = cast x3;
        var x1Raw2:haxe.Int64 = cast x1;
        result.lo64 = cast(((x3Raw & mask) << 32) | (x1Raw2 & mask));

        var x2Shifted:ClipperInt64 = cast(x2Raw >>> 32);
        var x3Shifted:ClipperInt64 = cast(x3Raw >>> 32);
        result.hi64 = aHi * bHi + x2Shifted + x3Shifted;
        return result;
    }
    #end

    /**
     * Check if products a*b and c*d are equal (using 128-bit precision).
     */
    public static function productsAreEqual(a:ClipperInt64, b:ClipperInt64, c:ClipperInt64, d:ClipperInt64):Bool {
        var absA = a.abs();
        var absB = b.abs();
        var absC = c.abs();
        var absD = d.abs();

        var mul_ab = multiplyUInt64(absA, absB);
        var mul_cd = multiplyUInt64(absC, absD);

        var sign_ab = a.triSign() * b.triSign();
        var sign_cd = c.triSign() * d.triSign();

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
        return (pt2.x.toFloat() - pt1.x.toFloat()) * (pt3.x.toFloat() - pt2.x.toFloat()) +
               (pt2.y.toFloat() - pt1.y.toFloat()) * (pt3.y.toFloat() - pt2.y.toFloat());
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
     * Check cast to ClipperInt64, returns Invalid64 if out of range.
     */
    public static inline function checkCastInt64(val:Float):ClipperInt64 {
        if (val >= maxCoordFloat || val <= minCoordFloat) return invalid64;
        return ClipperInt64.roundFromFloat(val);
    }

    /**
     * Get line intersection point (Point64 version).
     * Returns true if lines are non-parallel. ip is constrained to seg1.
     */
    public static function getLineIntersectPt64(ln1a:Point64, ln1b:Point64, ln2a:Point64, ln2b:Point64):{ip:Point64, success:Bool} {
        var dy1 = ln1b.y.toFloat() - ln1a.y.toFloat();
        var dx1 = ln1b.x.toFloat() - ln1a.x.toFloat();
        var dy2 = ln2b.y.toFloat() - ln2a.y.toFloat();
        var dx2 = ln2b.x.toFloat() - ln2a.x.toFloat();
        var det = dy1 * dx2 - dy2 * dx1;

        if (det == 0.0) {
            return {ip: new Point64(0, 0), success: false};
        }

        var t = ((ln1a.x.toFloat() - ln2a.x.toFloat()) * dy2 - (ln1a.y.toFloat() - ln2a.y.toFloat()) * dx2) / det;
        var ip:Point64;
        if (t <= 0.0) {
            ip = Point64.copy(ln1a);
        } else if (t >= 1.0) {
            ip = Point64.copy(ln1b);
        } else {
            ip = new Point64(
                ClipperInt64.fromFloat(ln1a.x.toFloat() + t * dx1),
                ClipperInt64.fromFloat(ln1a.y.toFloat() + t * dy1)
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
        var dy1 = seg1b.y.toFloat() - seg1a.y.toFloat();
        var dx1 = seg1b.x.toFloat() - seg1a.x.toFloat();
        var dy2 = seg2b.y.toFloat() - seg2a.y.toFloat();
        var dx2 = seg2b.x.toFloat() - seg2a.x.toFloat();
        var cp = dy1 * dx2 - dy2 * dx1;
        if (cp == 0) return false; // parallel segments

        if (inclusive) {
            var t = (seg1a.x.toFloat() - seg2a.x.toFloat()) * dy2 - (seg1a.y.toFloat() - seg2a.y.toFloat()) * dx2;
            if (t == 0) return true;
            if (t > 0) {
                if (cp < 0 || t > cp) return false;
            } else if (cp > 0 || t < cp) return false;

            t = (seg1a.x.toFloat() - seg2a.x.toFloat()) * dy1 - (seg1a.y.toFloat() - seg2a.y.toFloat()) * dx1;
            if (t == 0) return true;
            if (t > 0) return (cp > 0 && t <= cp);
            else return (cp < 0 && t >= cp);
        } else {
            var t = (seg1a.x.toFloat() - seg2a.x.toFloat()) * dy2 - (seg1a.y.toFloat() - seg2a.y.toFloat()) * dx2;
            if (t == 0) return false;
            if (t > 0) {
                if (cp < 0 || t >= cp) return false;
            } else if (cp > 0 || t <= cp) return false;

            t = (seg1a.x.toFloat() - seg2a.x.toFloat()) * dy1 - (seg1a.y.toFloat() - seg2a.y.toFloat()) * dx1;
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
        var dx = seg2.x.toFloat() - seg1.x.toFloat();
        var dy = seg2.y.toFloat() - seg1.y.toFloat();
        var q = ((offPt.x.toFloat() - seg1.x.toFloat()) * dx +
                 (offPt.y.toFloat() - seg1.y.toFloat()) * dy) / (dx * dx + dy * dy);
        if (q < 0) q = 0;
        else if (q > 1) q = 1;
        // Use MidpointRounding.ToEven to match C++ nearbyint behavior
        return new Point64(
            ClipperInt64.roundEvenFromFloat(seg1.x.toFloat() + q * dx),
            ClipperInt64.roundEvenFromFloat(seg1.y.toFloat() + q * dy)
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
            a += (prevPt.y.toFloat() + pt.y.toFloat()) * (prevPt.x.toFloat() - pt.x.toFloat());
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
    public static function setZ(path:Path64, z:ClipperInt64):Path64 {
        var result = new Path64();
        for (pt in path) {
            result.push(new Point64(pt.x, pt.y, z));
        }
        return result;
    }
    #end
}
