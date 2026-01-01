package clipper;

import haxe.Int64;
import clipper.internal.ClipperCore;
import clipper.ClipperEngine;

// ============================================================================
// Enums
// ============================================================================

/**
 * Join type for offset operations.
 */
enum abstract JoinType(Int) to Int {
    var Miter = 0;
    var Square = 1;
    var Bevel = 2;
    var Round = 3;
}

/**
 * End type for offset operations.
 */
enum abstract EndType(Int) to Int {
    var Polygon = 0;
    var Joined = 1;
    var Butt = 2;
    var Square = 3;
    var Round = 4;
}

// ============================================================================
// Group - Internal class for grouping paths with offset settings
// ============================================================================

private class Group {
    public var inPaths:Paths64;
    public var joinType:JoinType;
    public var endType:EndType;
    public var pathsReversed:Bool;
    public var lowestPathIdx:Int;

    public function new(paths:Paths64, joinType:JoinType, endType:EndType = EndType.Polygon) {
        this.joinType = joinType;
        this.endType = endType;

        var isJoined = (endType == EndType.Polygon) || (endType == EndType.Joined);
        inPaths = new Paths64();
        for (path in paths) {
            inPaths.push(ClipperOffset.stripDuplicates(path, isJoined));
        }

        if (endType == EndType.Polygon) {
            var info = ClipperOffset.getLowestPathInfo(inPaths);
            lowestPathIdx = info.idx;
            // the lowermost path must be an outer path, so if its orientation is negative,
            // then flag that the whole group is 'reversed' (will negate delta etc.)
            pathsReversed = (lowestPathIdx >= 0) && info.isNegArea;
        } else {
            lowestPathIdx = -1;
            pathsReversed = false;
        }
    }
}

// ============================================================================
// ClipperOffset - Polygon offset (inflate/shrink) operations
// ============================================================================

/**
 * Performs polygon offsetting (inflating/shrinking).
 */
class ClipperOffset {
    private static inline var Tolerance:Float = 1.0E-12;
    private static inline var arc_const:Float = 0.002; // 1/500

    private var _groupList:Array<Group>;
    private var pathOut:Path64;
    private var _normals:PathD;
    private var _solution:Paths64;
    private var _solutionTree:Null<PolyTree64>;

    private var _groupDelta:Float; // *0.5 for open paths; *-1.0 for negative areas
    private var _delta:Float;
    private var _mitLimSqr:Float;
    private var _stepsPerRad:Float;
    private var _stepSin:Float;
    private var _stepCos:Float;
    private var _joinType:JoinType;
    private var _endType:EndType;

    public var arcTolerance:Float;
    public var mergeGroups:Bool;
    public var miterLimit:Float;
    public var preserveCollinear:Bool;
    public var reverseSolution:Bool;

    public var deltaCallback:Null<(Path64, PathD, Int, Int) -> Float>;

    #if clipper_usingz
    public var zCallback:Null<(Point64, Point64, Point64, Point64, Point64) -> Void>;
    #end

    public function new(miterLimit:Float = 2.0, arcTolerance:Float = 0.0,
                        preserveCollinear:Bool = false, reverseSolution:Bool = false) {
        this.miterLimit = miterLimit;
        this.arcTolerance = arcTolerance;
        this.mergeGroups = true;
        this.preserveCollinear = preserveCollinear;
        this.reverseSolution = reverseSolution;

        _groupList = [];
        pathOut = new Path64();
        _normals = new PathD();
        _solution = new Paths64();
        _solutionTree = null;

        _groupDelta = 0;
        _delta = 0;
        _mitLimSqr = 0;
        _stepsPerRad = 0;
        _stepSin = 0;
        _stepCos = 0;
        _joinType = JoinType.Miter;
        _endType = EndType.Polygon;

        #if clipper_usingz
        zCallback = null;
        #end
    }

    public function clear():Void {
        _groupList = [];
    }

    public function addPath(path:Path64, joinType:JoinType, endType:EndType):Void {
        if (path.length == 0) return;
        var pp:Paths64 = [path];
        addPaths(pp, joinType, endType);
    }

    public function addPaths(paths:Paths64, joinType:JoinType, endType:EndType):Void {
        if (paths.length == 0) return;
        _groupList.push(new Group(paths, joinType, endType));
    }

    private function calcSolutionCapacity():Int {
        var result = 0;
        for (g in _groupList) {
            result += (g.endType == EndType.Joined) ? g.inPaths.length * 2 : g.inPaths.length;
        }
        return result;
    }

    private function checkPathsReversed():Bool {
        var result = false;
        for (g in _groupList) {
            if (g.endType == EndType.Polygon) {
                result = g.pathsReversed;
                break;
            }
        }
        return result;
    }

    private function executeInternal(delta:Float):Void {
        if (_groupList.length == 0) return;

        // make sure the offset delta is significant
        if (Math.abs(delta) < 0.5) {
            for (group in _groupList) {
                for (path in group.inPaths) {
                    _solution.push(path);
                }
            }
            return;
        }

        _delta = delta;
        _mitLimSqr = if (miterLimit <= 1) 2.0 else 2.0 / sqr(miterLimit);

        for (group in _groupList) {
            doGroupOffset(group);
        }

        if (_groupList.length == 0) return;

        var pathsReversed = checkPathsReversed();
        var fillRule = if (pathsReversed) FillRule.Negative else FillRule.Positive;

        // clean up self-intersections ...
        var c = new Clipper64();
        c.preserveCollinear = preserveCollinear;
        c.reverseSolution = reverseSolution != pathsReversed;
        #if clipper_usingz
        c.zCallback = zCB;
        #end
        c.addSubjectPaths(_solution);
        if (_solutionTree != null) {
            c.executeTree(ClipType.Union, fillRule, _solutionTree);
        } else {
            c.execute(ClipType.Union, fillRule, _solution);
        }
    }

    #if clipper_usingz
    private function zCB(bot1:Point64, top1:Point64, bot2:Point64, top2:Point64, ip:Point64):Void {
        if (bot1.z != 0 && ((bot1.z == bot2.z) || (bot1.z == top2.z))) {
            ip.z = bot1.z;
        } else if (bot2.z != 0 && bot2.z == top1.z) {
            ip.z = bot2.z;
        } else if (top1.z != 0 && top1.z == top2.z) {
            ip.z = top1.z;
        } else if (zCallback != null) {
            zCallback(bot1, top1, bot2, top2, ip);
        }
    }
    #end

    public function execute(delta:Float, solution:Paths64):Void {
        solution.resize(0);
        _solution = solution;
        _solutionTree = null;
        executeInternal(delta);
    }

    public function executeTree(delta:Float, solutionTree:PolyTree64):Void {
        solutionTree.clear();
        _solutionTree = solutionTree;
        _solution = new Paths64();
        executeInternal(delta);
    }

    public function executeWithCallback(deltaCallback:(Path64, PathD, Int, Int) -> Float, solution:Paths64):Void {
        this.deltaCallback = deltaCallback;
        execute(1.0, solution);
    }

    public static inline function getUnitNormal(pt1:Point64, pt2:Point64):PointD {
        var dx = InternalClipper.toFloat(pt2.x) - InternalClipper.toFloat(pt1.x);
        var dy = InternalClipper.toFloat(pt2.y) - InternalClipper.toFloat(pt1.y);
        if (dx == 0 && dy == 0) return new PointD(0, 0);

        var f = 1.0 / Math.sqrt(dx * dx + dy * dy);
        dx *= f;
        dy *= f;

        return new PointD(dy, -dx);
    }

    public static function getLowestPathInfo(paths:Paths64):{idx:Int, isNegArea:Bool} {
        var idx = -1;
        var isNegArea = false;
        var botPtX:Int64 = InternalClipper.maxInt64;
        var botPtY:Int64 = InternalClipper.minInt64;

        for (i in 0...paths.length) {
            var a:Float = Math.POSITIVE_INFINITY;
            for (pt in paths[i]) {
                if ((pt.y < botPtY) || ((pt.y == botPtY) && (pt.x >= botPtX))) continue;
                if (a == Math.POSITIVE_INFINITY) {
                    a = InternalClipper.area(paths[i]);
                    if (a == 0) break; // invalid closed path so break from inner loop
                    isNegArea = a < 0;
                }
                idx = i;
                botPtX = pt.x;
                botPtY = pt.y;
            }
        }
        return {idx: idx, isNegArea: isNegArea};
    }

    private static inline function translatePoint(pt:PointD, dx:Float, dy:Float):PointD {
        #if clipper_usingz
        return new PointD(pt.x + dx, pt.y + dy, pt.z);
        #else
        return new PointD(pt.x + dx, pt.y + dy);
        #end
    }

    private static inline function reflectPoint(pt:PointD, pivot:PointD):PointD {
        #if clipper_usingz
        return new PointD(pivot.x + (pivot.x - pt.x), pivot.y + (pivot.y - pt.y), pt.z);
        #else
        return new PointD(pivot.x + (pivot.x - pt.x), pivot.y + (pivot.y - pt.y));
        #end
    }

    private static inline function almostZero(value:Float, epsilon:Float = 0.001):Bool {
        return Math.abs(value) < epsilon;
    }

    private static inline function hypotenuse(x:Float, y:Float):Float {
        return Math.sqrt(x * x + y * y);
    }

    private static inline function normalizeVector(vec:PointD):PointD {
        var h = hypotenuse(vec.x, vec.y);
        if (almostZero(h)) return new PointD(0, 0);
        var inverseHypot = 1 / h;
        return new PointD(vec.x * inverseHypot, vec.y * inverseHypot);
    }

    private static inline function getAvgUnitVector(vec1:PointD, vec2:PointD):PointD {
        return normalizeVector(new PointD(vec1.x + vec2.x, vec1.y + vec2.y));
    }

    private inline function getPerpendic(pt:Point64, norm:PointD):Point64 {
        #if clipper_usingz
        return new Point64(
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.x) + norm.x * _groupDelta),
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.y) + norm.y * _groupDelta),
            pt.z
        );
        #else
        return new Point64(
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.x) + norm.x * _groupDelta),
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.y) + norm.y * _groupDelta)
        );
        #end
    }

    private inline function getPerpendicD(pt:Point64, norm:PointD):PointD {
        #if clipper_usingz
        return new PointD(
            InternalClipper.toFloat(pt.x) + norm.x * _groupDelta,
            InternalClipper.toFloat(pt.y) + norm.y * _groupDelta,
            pt.z
        );
        #else
        return new PointD(
            InternalClipper.toFloat(pt.x) + norm.x * _groupDelta,
            InternalClipper.toFloat(pt.y) + norm.y * _groupDelta
        );
        #end
    }

    private function doBevel(path:Path64, j:Int, k:Int):Void {
        var pt1:Point64, pt2:Point64;
        if (j == k) {
            var absDelta = Math.abs(_groupDelta);
            #if clipper_usingz
            pt1 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) - absDelta * _normals[j].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) - absDelta * _normals[j].y),
                path[j].z
            );
            pt2 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + absDelta * _normals[j].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + absDelta * _normals[j].y),
                path[j].z
            );
            #else
            pt1 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) - absDelta * _normals[j].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) - absDelta * _normals[j].y)
            );
            pt2 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + absDelta * _normals[j].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + absDelta * _normals[j].y)
            );
            #end
        } else {
            #if clipper_usingz
            pt1 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + _groupDelta * _normals[k].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + _groupDelta * _normals[k].y),
                path[j].z
            );
            pt2 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + _groupDelta * _normals[j].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + _groupDelta * _normals[j].y),
                path[j].z
            );
            #else
            pt1 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + _groupDelta * _normals[k].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + _groupDelta * _normals[k].y)
            );
            pt2 = new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + _groupDelta * _normals[j].x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + _groupDelta * _normals[j].y)
            );
            #end
        }
        pathOut.push(pt1);
        pathOut.push(pt2);
    }

    private function doSquare(path:Path64, j:Int, k:Int):Void {
        var vec:PointD;
        if (j == k) {
            vec = new PointD(_normals[j].y, -_normals[j].x);
        } else {
            vec = getAvgUnitVector(
                new PointD(-_normals[k].y, _normals[k].x),
                new PointD(_normals[j].y, -_normals[j].x)
            );
        }

        var absDelta = Math.abs(_groupDelta);
        // now offset the original vertex delta units along unit vector
        var ptQ = new PointD(InternalClipper.toFloat(path[j].x), InternalClipper.toFloat(path[j].y));
        ptQ = translatePoint(ptQ, absDelta * vec.x, absDelta * vec.y);

        // get perpendicular vertices
        var pt1 = translatePoint(ptQ, _groupDelta * vec.y, _groupDelta * -vec.x);
        var pt2 = translatePoint(ptQ, _groupDelta * -vec.y, _groupDelta * vec.x);
        // get 2 vertices along one edge offset
        var pt3 = getPerpendicD(path[k], _normals[k]);

        if (j == k) {
            var pt4 = new PointD(
                pt3.x + vec.x * _groupDelta,
                pt3.y + vec.y * _groupDelta
            );
            var result = InternalClipper.getLineIntersectPtD(pt1, pt2, pt3, pt4);
            var pt = result.ip;
            #if clipper_usingz
            pt.z = ptQ.z;
            #end
            // get the second intersect point through reflection
            pathOut.push(Point64.fromPointD(reflectPoint(pt, ptQ)));
            pathOut.push(Point64.fromPointD(pt));
        } else {
            var pt4 = getPerpendicD(path[j], _normals[k]);
            var result = InternalClipper.getLineIntersectPtD(pt1, pt2, pt3, pt4);
            var pt = result.ip;
            #if clipper_usingz
            pt.z = ptQ.z;
            #end
            pathOut.push(Point64.fromPointD(pt));
            // get the second intersect point through reflection
            pathOut.push(Point64.fromPointD(reflectPoint(pt, ptQ)));
        }
    }

    private function doMiter(path:Path64, j:Int, k:Int, cosA:Float):Void {
        var q = _groupDelta / (cosA + 1);
        #if clipper_usingz
        pathOut.push(new Point64(
            InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + (_normals[k].x + _normals[j].x) * q),
            InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + (_normals[k].y + _normals[j].y) * q),
            path[j].z
        ));
        #else
        pathOut.push(new Point64(
            InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].x) + (_normals[k].x + _normals[j].x) * q),
            InternalClipper.roundToInt64(InternalClipper.toFloat(path[j].y) + (_normals[k].y + _normals[j].y) * q)
        ));
        #end
    }

    private function doRound(path:Path64, j:Int, k:Int, angle:Float):Void {
        if (deltaCallback != null) {
            // when DeltaCallback is assigned, _groupDelta won't be constant,
            // so we'll need to do the following calculations for *every* vertex.
            var absDelta = Math.abs(_groupDelta);
            var arcTol = if (arcTolerance > 0.01) arcTolerance else absDelta * arc_const;
            var stepsPer360 = Math.PI / Math.acos(1 - arcTol / absDelta);
            _stepSin = Math.sin((2 * Math.PI) / stepsPer360);
            _stepCos = Math.cos((2 * Math.PI) / stepsPer360);
            if (_groupDelta < 0.0) _stepSin = -_stepSin;
            _stepsPerRad = stepsPer360 / (2 * Math.PI);
        }

        var pt = path[j];
        var offsetVec = new PointD(_normals[k].x * _groupDelta, _normals[k].y * _groupDelta);
        if (j == k) offsetVec.negate();

        #if clipper_usingz
        pathOut.push(new Point64(
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.x) + offsetVec.x),
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.y) + offsetVec.y),
            pt.z
        ));
        #else
        pathOut.push(new Point64(
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.x) + offsetVec.x),
            InternalClipper.roundToInt64(InternalClipper.toFloat(pt.y) + offsetVec.y)
        ));
        #end

        var steps = Std.int(Math.ceil(_stepsPerRad * Math.abs(angle)));
        for (i in 1...steps) { // ie 1 less than steps
            offsetVec = new PointD(
                offsetVec.x * _stepCos - _stepSin * offsetVec.y,
                offsetVec.x * _stepSin + offsetVec.y * _stepCos
            );
            #if clipper_usingz
            pathOut.push(new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(pt.x) + offsetVec.x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(pt.y) + offsetVec.y),
                pt.z
            ));
            #else
            pathOut.push(new Point64(
                InternalClipper.roundToInt64(InternalClipper.toFloat(pt.x) + offsetVec.x),
                InternalClipper.roundToInt64(InternalClipper.toFloat(pt.y) + offsetVec.y)
            ));
            #end
        }
        pathOut.push(getPerpendic(pt, _normals[j]));
    }

    private function buildNormals(path:Path64):Void {
        var cnt = path.length;
        _normals = new PathD();
        if (cnt == 0) return;
        for (i in 0...cnt - 1) {
            _normals.push(getUnitNormal(path[i], path[i + 1]));
        }
        _normals.push(getUnitNormal(path[cnt - 1], path[0]));
    }

    private function offsetPoint(group:Group, path:Path64, j:Int, k:Int):Int {
        if (path[j] == path[k]) return j;

        // Let A = change in angle where edges join
        // A == 0: ie no change in angle (flat join)
        // A == PI: edges 'spike'
        // sin(A) < 0: right turning
        // cos(A) < 0: change in angle is more than 90 degree
        var sinA = InternalClipper.crossProductD(_normals[j], _normals[k]);
        var cosA = InternalClipper.dotProductD(_normals[j], _normals[k]);
        if (sinA > 1.0) sinA = 1.0
        else if (sinA < -1.0) sinA = -1.0;

        if (deltaCallback != null) {
            _groupDelta = deltaCallback(path, _normals, j, k);
            if (group.pathsReversed) _groupDelta = -_groupDelta;
        }
        if (Math.abs(_groupDelta) < Tolerance) {
            pathOut.push(path[j]);
            return j;
        }

        if (cosA > -0.999 && (sinA * _groupDelta < 0)) { // test for concavity first (#593)
            // is concave
            pathOut.push(getPerpendic(path[j], _normals[k]));
            pathOut.push(path[j]); // (#405, #873, #916)
            pathOut.push(getPerpendic(path[j], _normals[j]));
        } else if ((cosA > 0.999) && (_joinType != JoinType.Round)) {
            // almost straight - less than 2.5 degree (#424, #482, #526 & #724)
            doMiter(path, j, k, cosA);
        } else {
            switch (_joinType) {
                case JoinType.Miter:
                    if (cosA > _mitLimSqr - 1) {
                        doMiter(path, j, k, cosA);
                    } else {
                        doSquare(path, j, k);
                    }
                case JoinType.Round:
                    doRound(path, j, k, Math.atan2(sinA, cosA));
                case JoinType.Bevel:
                    doBevel(path, j, k);
                default:
                    doSquare(path, j, k);
            }
        }

        return j;
    }

    private function offsetPolygon(group:Group, path:Path64):Void {
        pathOut = new Path64();
        var cnt = path.length;
        var prev = cnt - 1;
        for (i in 0...cnt) {
            prev = offsetPoint(group, path, i, prev);
        }
        _solution.push(pathOut);
    }

    private function offsetOpenJoined(group:Group, path:Path64):Void {
        offsetPolygon(group, path);
        var reversed = reversePath(path);
        buildNormals(reversed);
        offsetPolygon(group, reversed);
    }

    private function offsetOpenPath(group:Group, path:Path64):Void {
        pathOut = new Path64();
        var highI = path.length - 1;

        if (deltaCallback != null) {
            _groupDelta = deltaCallback(path, _normals, 0, 0);
        }

        // do the line start cap
        if (Math.abs(_groupDelta) < Tolerance) {
            pathOut.push(path[0]);
        } else {
            switch (_endType) {
                case EndType.Butt:
                    doBevel(path, 0, 0);
                case EndType.Round:
                    doRound(path, 0, 0, Math.PI);
                default:
                    doSquare(path, 0, 0);
            }
        }

        // offset the left side going forward
        var k = 0;
        for (i in 1...highI) {
            k = offsetPoint(group, path, i, k);
        }

        // reverse normals ...
        var i = highI;
        while (i > 0) {
            _normals[i] = new PointD(-_normals[i - 1].x, -_normals[i - 1].y);
            i--;
        }
        _normals[0] = _normals[highI];

        if (deltaCallback != null) {
            _groupDelta = deltaCallback(path, _normals, highI, highI);
        }
        // do the line end cap
        if (Math.abs(_groupDelta) < Tolerance) {
            pathOut.push(path[highI]);
        } else {
            switch (_endType) {
                case EndType.Butt:
                    doBevel(path, highI, highI);
                case EndType.Round:
                    doRound(path, highI, highI, Math.PI);
                default:
                    doSquare(path, highI, highI);
            }
        }

        // offset the left side going back
        k = highI;
        var j = highI - 1;
        while (j > 0) {
            k = offsetPoint(group, path, j, k);
            j--;
        }

        _solution.push(pathOut);
    }

    private function doGroupOffset(group:Group):Void {
        if (group.endType == EndType.Polygon) {
            // a straight path (2 points) can now also be 'polygon' offset
            // where the ends will be treated as (180 deg.) joins
            if (group.lowestPathIdx < 0) _delta = Math.abs(_delta);
            _groupDelta = if (group.pathsReversed) -_delta else _delta;
        } else {
            _groupDelta = Math.abs(_delta);
        }

        var absDelta = Math.abs(_groupDelta);

        _joinType = group.joinType;
        _endType = group.endType;

        if (group.joinType == JoinType.Round || group.endType == EndType.Round) {
            var arcTol = if (arcTolerance > 0.01) arcTolerance else absDelta * arc_const;
            var stepsPer360 = Math.PI / Math.acos(1 - arcTol / absDelta);
            _stepSin = Math.sin((2 * Math.PI) / stepsPer360);
            _stepCos = Math.cos((2 * Math.PI) / stepsPer360);
            if (_groupDelta < 0.0) _stepSin = -_stepSin;
            _stepsPerRad = stepsPer360 / (2 * Math.PI);
        }

        for (p in group.inPaths) {
            pathOut = new Path64();
            var cnt = p.length;

            if (cnt == 1) {
                var pt = p[0];

                if (deltaCallback != null) {
                    _groupDelta = deltaCallback(p, _normals, 0, 0);
                    if (group.pathsReversed) _groupDelta = -_groupDelta;
                    absDelta = Math.abs(_groupDelta);
                }

                // single vertex so build a circle or square ...
                if (group.endType == EndType.Round) {
                    var steps = Std.int(Math.ceil(_stepsPerRad * 2 * Math.PI));
                    pathOut = ellipse(pt, absDelta, absDelta, steps);
                    #if clipper_usingz
                    pathOut = InternalClipper.setZ(pathOut, pt.z);
                    #end
                } else {
                    var d = Std.int(Math.ceil(_groupDelta));
                    var r = new Rect64(
                        pt.x - Int64.ofInt(d),
                        pt.y - Int64.ofInt(d),
                        pt.x + Int64.ofInt(d),
                        pt.y + Int64.ofInt(d)
                    );
                    pathOut = r.asPath();
                    #if clipper_usingz
                    pathOut = InternalClipper.setZ(pathOut, pt.z);
                    #end
                }
                _solution.push(pathOut);
                continue; // end of offsetting a single point
            }

            if (cnt == 2 && group.endType == EndType.Joined) {
                _endType = if (group.joinType == JoinType.Round) EndType.Round else EndType.Square;
            }

            buildNormals(p);
            switch (_endType) {
                case EndType.Polygon:
                    offsetPolygon(group, p);
                case EndType.Joined:
                    offsetOpenJoined(group, p);
                default:
                    offsetOpenPath(group, p);
            }
        }
    }

    // ========================================================================
    // Static helper functions
    // ========================================================================

    public static function stripDuplicates(path:Path64, isClosedPath:Bool):Path64 {
        var cnt = path.length;
        if (cnt == 0) return new Path64();
        var result = new Path64();
        var lastPt = path[0];
        result.push(lastPt);
        for (i in 1...cnt) {
            if (path[i] != lastPt) {
                lastPt = path[i];
                result.push(lastPt);
            }
        }
        if (isClosedPath && result.length > 1 && result[result.length - 1] == result[0]) {
            result.pop();
        }
        return result;
    }

    public static function reversePath(path:Path64):Path64 {
        var result = new Path64();
        var i = path.length - 1;
        while (i >= 0) {
            result.push(path[i]);
            i--;
        }
        return result;
    }

    public static inline function sqr(val:Float):Float {
        return val * val;
    }

    public static function ellipse(center:Point64, radiusX:Float, radiusY:Float, steps:Int = 0):Path64 {
        if (radiusX <= 0) return new Path64();
        if (radiusY <= 0) radiusY = radiusX;
        if (steps <= 2) {
            steps = Std.int(Math.ceil(Math.PI * Math.sqrt((radiusX + radiusY) / 2)));
        }
        var si = Math.sin(2 * Math.PI / steps);
        var co = Math.cos(2 * Math.PI / steps);
        var dx = co;
        var dy = si;
        var result = new Path64();
        var centerX = InternalClipper.toFloat(center.x);
        var centerY = InternalClipper.toFloat(center.y);
        result.push(new Point64(
            InternalClipper.roundToInt64(centerX + radiusX),
            InternalClipper.roundToInt64(centerY)
        ));
        for (i in 1...steps) {
            result.push(new Point64(
                InternalClipper.roundToInt64(centerX + radiusX * dx),
                InternalClipper.roundToInt64(centerY + radiusY * dy)
            ));
            var x = dx * co - dy * si;
            dy = dy * co + dx * si;
            dx = x;
        }
        return result;
    }
}
