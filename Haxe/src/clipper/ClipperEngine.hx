package clipper;

import clipper.ClipperCore;

// ============================================================================
// Internal enums
// ============================================================================

enum abstract VertexFlags(Int) to Int from Int {
    var None = 0;
    var OpenStart = 1;
    var OpenEnd = 2;
    var LocalMax = 4;
    var LocalMin = 8;

    @:op(A | B) static function or(a:VertexFlags, b:VertexFlags):VertexFlags;
    @:op(A & B) static function and(a:VertexFlags, b:VertexFlags):VertexFlags;
}

enum abstract JoinWith(Int) to Int {
    var None = 0;
    var Left = 1;
    var Right = 2;
}

enum abstract HorzPosition(Int) to Int {
    var Bottom = 0;
    var Middle = 1;
    var Top = 2;
}

// ============================================================================
// Vertex - pre-clipping data structure
// ============================================================================

class Vertex {
    public var pt:Point64;
    public var next:Null<Vertex>;
    public var prev:Null<Vertex>;
    public var flags:VertexFlags;

    public function new(pt:Point64, flags:VertexFlags, prev:Null<Vertex>) {
        this.pt = pt;
        this.flags = flags;
        this.next = null;
        this.prev = prev;
    }
}

// ============================================================================
// LocalMinima - marks local minima in paths
// ============================================================================

class LocalMinima {
    public var vertex:Vertex;
    public var polytype:PathType;
    public var isOpen:Bool;

    public function new(vertex:Vertex, polytype:PathType, isOpen:Bool = false) {
        this.vertex = vertex;
        this.polytype = polytype;
        this.isOpen = isOpen;
    }

    public static function compare(lm1:LocalMinima, lm2:LocalMinima):Int {
        // Sort descending by Y (highest Y first = bottom first)
        // For descending: if lm1.y > lm2.y, lm1 comes first (return -1)
        if (lm1.vertex.pt.y > lm2.vertex.pt.y) return -1;
        if (lm1.vertex.pt.y < lm2.vertex.pt.y) return 1;
        return 0;
    }
}

// ============================================================================
// IntersectNode - represents two intersecting edges
// ============================================================================

class IntersectNode {
    public var pt:Point64;
    public var edge1:Active;
    public var edge2:Active;

    public function new(pt:Point64, edge1:Active, edge2:Active) {
        this.pt = pt;
        this.edge1 = edge1;
        this.edge2 = edge2;
    }

    public static function compare(a:IntersectNode, b:IntersectNode):Int {
        if (a.pt.y != b.pt.y) return (a.pt.y > b.pt.y) ? -1 : 1;
        if (a.pt.x == b.pt.x) return 0;
        return (a.pt.x < b.pt.x) ? -1 : 1;
    }
}

// ============================================================================
// OutPt - vertex data structure for clipping solutions
// ============================================================================

class OutPt {
    public var pt:Point64;
    public var next:Null<OutPt>;
    public var prev:OutPt;
    public var outrec:OutRec;
    public var horz:Null<HorzSegment>;

    public function new(pt:Point64, outrec:OutRec) {
        this.pt = pt;
        this.outrec = outrec;
        this.next = this;
        this.prev = this;
        this.horz = null;
    }
}

// ============================================================================
// OutRec - path data structure for clipping solutions
// ============================================================================

class OutRec {
    public var idx:Int;
    public var outPtCount:Int;
    public var owner:Null<OutRec>;
    public var frontEdge:Null<Active>;
    public var backEdge:Null<Active>;
    public var pts:Null<OutPt>;
    public var polypath:Null<PolyPathBase>;
    public var bounds:Rect64;
    public var path:Path64;
    public var isOpen:Bool;
    public var splits:Null<Array<Int>>;
    public var recursiveSplit:Null<OutRec>;

    public function new() {
        idx = 0;
        outPtCount = 0;
        owner = null;
        frontEdge = null;
        backEdge = null;
        pts = null;
        polypath = null;
        bounds = new Rect64();
        path = new Path64();
        isOpen = false;
        splits = null;
        recursiveSplit = null;
    }
}

// ============================================================================
// HorzSegment - horizontal segment for optimization
// ============================================================================

class HorzSegment {
    public var leftOp:Null<OutPt>;
    public var rightOp:Null<OutPt>;
    public var leftToRight:Bool;

    public function new(op:OutPt) {
        leftOp = op;
        rightOp = null;
        leftToRight = true;
    }
}

// ============================================================================
// HorzJoin - joins for horizontal segments
// ============================================================================

class HorzJoin {
    public var op1:Null<OutPt>;
    public var op2:Null<OutPt>;

    public function new(ltor:OutPt, rtol:OutPt) {
        op1 = ltor;
        op2 = rtol;
    }
}

// ============================================================================
// Active - active edge in the scanline algorithm
// ============================================================================

class Active {
    public var bot:Point64;
    public var top:Point64;
    public var curX:ClipperInt64;
    public var dx:Float;
    public var windDx:Int;
    public var windCount:Int;
    public var windCount2:Int;
    public var outrec:Null<OutRec>;

    public var prevInAEL:Null<Active>;
    public var nextInAEL:Null<Active>;
    public var prevInSEL:Null<Active>;
    public var nextInSEL:Null<Active>;
    public var jump:Null<Active>;
    public var vertexTop:Null<Vertex>;
    public var localMin:LocalMinima;
    public var isLeftBound:Bool;
    public var joinWith:JoinWith;

    public function new() {
        bot = new Point64(0, 0);
        top = new Point64(0, 0);
        curX = ClipperInt64.ofInt(0);
        dx = 0.0;
        windDx = 0;
        windCount = 0;
        windCount2 = 0;
        outrec = null;
        prevInAEL = null;
        nextInAEL = null;
        prevInSEL = null;
        nextInSEL = null;
        jump = null;
        vertexTop = null;
        localMin = null;
        isLeftBound = false;
        joinWith = JoinWith.None;
    }
}

// ============================================================================
// ClipperBase - base class for Clipper64 and ClipperD
// ============================================================================

class ClipperBase {
    private var _cliptype:ClipType;
    private var _fillrule:FillRule;
    private var _actives:Null<Active>;
    private var _sel:Null<Active>;
    private var _minimaList:Array<LocalMinima>;
    private var _intersectList:Array<IntersectNode>;
    private var _vertexList:Array<Vertex>;
    private var _outrecList:Array<OutRec>;
    private var _scanlineList:Array<ClipperInt64>;
    private var _horzSegList:Array<HorzSegment>;
    private var _horzJoinList:Array<HorzJoin>;
    private var _currentLocMin:Int;
    private var _currentBotY:ClipperInt64;
    private var _isSortedMinimaList:Bool;
    private var _hasOpenPaths:Bool;
    public var _using_polytree:Bool;
    public var _succeeded:Bool;
    public var preserveCollinear:Bool;
    public var reverseSolution:Bool;

    #if clipper_usingz
    public var defaultZ:ClipperInt64;
    private var _zCallback:Null<(Point64, Point64, Point64, Point64, Point64) -> Void>;
    #end

    public function new() {
        _minimaList = new Array<LocalMinima>();
        _intersectList = new Array<IntersectNode>();
        _vertexList = new Array<Vertex>();
        _outrecList = new Array<OutRec>();
        _scanlineList = new Array<ClipperInt64>();
        _horzSegList = new Array<HorzSegment>();
        _horzJoinList = new Array<HorzJoin>();
        _cliptype = ClipType.NoClip;
        _fillrule = FillRule.EvenOdd;
        _actives = null;
        _sel = null;
        _currentLocMin = 0;
        _currentBotY = ClipperInt64.ofInt(0);
        _isSortedMinimaList = false;
        _hasOpenPaths = false;
        _using_polytree = false;
        _succeeded = true;
        preserveCollinear = true;
        reverseSolution = false;
        #if clipper_usingz
        defaultZ = ClipperInt64.ofInt(0);
        _zCallback = null;
        #end
    }

    // Static helper functions
    private static inline function isOdd(val:Int):Bool {
        return (val & 1) != 0;
    }

    private static inline function isHotEdge(ae:Active):Bool {
        return ae.outrec != null;
    }

    private static inline function isOpen(ae:Active):Bool {
        return ae.localMin.isOpen;
    }

    private static inline function isOpenEndVertex(v:Vertex):Bool {
        return (v.flags & (VertexFlags.OpenStart | VertexFlags.OpenEnd)) != VertexFlags.None;
    }

    private static inline function isOpenEnd(ae:Active):Bool {
        return ae.localMin.isOpen && isOpenEndVertex(ae.vertexTop);
    }

    private static function getPrevHotEdge(ae:Active):Null<Active> {
        var prev = ae.prevInAEL;
        while (prev != null && (isOpen(prev) || !isHotEdge(prev)))
            prev = prev.prevInAEL;
        return prev;
    }

    private static inline function isFront(ae:Active):Bool {
        return ae == ae.outrec.frontEdge;
    }

    private static inline function getDx(pt1:Point64, pt2:Point64):Float {
        var dy = InternalClipper.toFloat(pt2.y) - InternalClipper.toFloat(pt1.y);
        if (dy != 0)
            return (InternalClipper.toFloat(pt2.x) - InternalClipper.toFloat(pt1.x)) / dy;
        return if (pt2.x > pt1.x) Math.NEGATIVE_INFINITY else Math.POSITIVE_INFINITY;
    }

    private static function topX(ae:Active, currentY:ClipperInt64):ClipperInt64 {
        if (currentY == ae.top.y || ae.top.x == ae.bot.x) return ae.top.x;
        if (currentY == ae.bot.y) return ae.bot.x;
        return ae.bot.x + InternalClipper.roundToEvenInt64(ae.dx * InternalClipper.toFloat(currentY - ae.bot.y));
    }

    private static inline function isHorizontal(ae:Active):Bool {
        return ae.top.y == ae.bot.y;
    }

    private static inline function isHeadingRightHorz(ae:Active):Bool {
        return Math.isNaN(ae.dx) ? false : ae.dx == Math.NEGATIVE_INFINITY;
    }

    private static inline function isHeadingLeftHorz(ae:Active):Bool {
        return Math.isNaN(ae.dx) ? false : ae.dx == Math.POSITIVE_INFINITY;
    }

    private static inline function getPolyType(ae:Active):PathType {
        return ae.localMin.polytype;
    }

    private static inline function isSamePolyType(ae1:Active, ae2:Active):Bool {
        return ae1.localMin.polytype == ae2.localMin.polytype;
    }

    private static inline function setDx(ae:Active):Void {
        ae.dx = getDx(ae.bot, ae.top);
    }

    private static inline function nextVertex(ae:Active):Vertex {
        return if (ae.windDx > 0) ae.vertexTop.next else ae.vertexTop.prev;
    }

    private static inline function prevPrevVertex(ae:Active):Vertex {
        return if (ae.windDx > 0) ae.vertexTop.prev.prev else ae.vertexTop.next.next;
    }

    private static inline function isMaximaVertex(vertex:Vertex):Bool {
        return (vertex.flags & VertexFlags.LocalMax) != VertexFlags.None;
    }

    private static inline function isMaxima(ae:Active):Bool {
        return isMaximaVertex(ae.vertexTop);
    }

    private static function getMaximaPair(ae:Active):Null<Active> {
        var ae2 = ae.nextInAEL;
        while (ae2 != null) {
            if (ae2.vertexTop == ae.vertexTop) return ae2;
            ae2 = ae2.nextInAEL;
        }
        return null;
    }

    private static function getCurrYMaximaVertex_Open(ae:Active):Null<Vertex> {
        var result = ae.vertexTop;
        if (ae.windDx > 0) {
            while (result.next.pt.y == result.pt.y &&
                   ((result.flags & (VertexFlags.OpenEnd | VertexFlags.LocalMax)) == VertexFlags.None))
                result = result.next;
        } else {
            while (result.prev.pt.y == result.pt.y &&
                   ((result.flags & (VertexFlags.OpenEnd | VertexFlags.LocalMax)) == VertexFlags.None))
                result = result.prev;
        }
        if (!isMaximaVertex(result)) result = null;
        return result;
    }

    private static function getCurrYMaximaVertex(ae:Active):Null<Vertex> {
        var result = ae.vertexTop;
        if (ae.windDx > 0) {
            while (result.next.pt.y == result.pt.y) result = result.next;
        } else {
            while (result.prev.pt.y == result.pt.y) result = result.prev;
        }
        if (!isMaximaVertex(result)) result = null;
        return result;
    }

    private static inline function setSides(outrec:OutRec, startEdge:Active, endEdge:Active):Void {
        outrec.frontEdge = startEdge;
        outrec.backEdge = endEdge;
    }

    private static function swapOutrecs(ae1:Active, ae2:Active):Void {
        var or1 = ae1.outrec;
        var or2 = ae2.outrec;
        if (or1 == or2) {
            var ae = or1.frontEdge;
            or1.frontEdge = or1.backEdge;
            or1.backEdge = ae;
            return;
        }

        if (or1 != null) {
            if (ae1 == or1.frontEdge)
                or1.frontEdge = ae2;
            else
                or1.backEdge = ae2;
        }

        if (or2 != null) {
            if (ae2 == or2.frontEdge)
                or2.frontEdge = ae1;
            else
                or2.backEdge = ae1;
        }

        ae1.outrec = or2;
        ae2.outrec = or1;
    }

    private static function setOwner(outrec:OutRec, newOwner:OutRec):Void {
        while (newOwner.owner != null && newOwner.owner.pts == null)
            newOwner.owner = newOwner.owner.owner;

        var tmp = newOwner;
        while (tmp != null && tmp != outrec)
            tmp = tmp.owner;
        if (tmp != null)
            newOwner.owner = outrec.owner;
        outrec.owner = newOwner;
    }

    private static function areaOutPt(op:OutPt):Float {
        var area = 0.0;
        var op2 = op;
        do {
            area += (InternalClipper.toFloat(op2.prev.pt.y) + InternalClipper.toFloat(op2.pt.y)) *
                    (InternalClipper.toFloat(op2.prev.pt.x) - InternalClipper.toFloat(op2.pt.x));
            op2 = op2.next;
        } while (op2 != op);
        return area * 0.5;
    }

    private static inline function areaTriangle(pt1:Point64, pt2:Point64, pt3:Point64):Float {
        return (InternalClipper.toFloat(pt3.y) + InternalClipper.toFloat(pt1.y)) * (InternalClipper.toFloat(pt3.x) - InternalClipper.toFloat(pt1.x)) +
               (InternalClipper.toFloat(pt1.y) + InternalClipper.toFloat(pt2.y)) * (InternalClipper.toFloat(pt1.x) - InternalClipper.toFloat(pt2.x)) +
               (InternalClipper.toFloat(pt2.y) + InternalClipper.toFloat(pt3.y)) * (InternalClipper.toFloat(pt2.x) - InternalClipper.toFloat(pt3.x));
    }

    private static function getRealOutRec(outRec:Null<OutRec>):Null<OutRec> {
        while (outRec != null && outRec.pts == null)
            outRec = outRec.owner;
        return outRec;
    }

    private static function isValidOwner(outRec:Null<OutRec>, testOwner:Null<OutRec>):Bool {
        while (testOwner != null && testOwner != outRec)
            testOwner = testOwner.owner;
        return testOwner == null;
    }

    private static function uncoupleOutRec(ae:Active):Void {
        var outrec = ae.outrec;
        if (outrec == null) return;
        outrec.frontEdge.outrec = null;
        outrec.backEdge.outrec = null;
        outrec.frontEdge = null;
        outrec.backEdge = null;
    }

    private static inline function outrecIsAscending(hotEdge:Active):Bool {
        return hotEdge == hotEdge.outrec.frontEdge;
    }

    private static function swapFrontBackSides(outrec:OutRec):Void {
        var ae2 = outrec.frontEdge;
        outrec.frontEdge = outrec.backEdge;
        outrec.backEdge = ae2;
        outrec.pts = outrec.pts.next;
    }

    private static inline function edgesAdjacentInAEL(inode:IntersectNode):Bool {
        return inode.edge1.nextInAEL == inode.edge2 || inode.edge1.prevInAEL == inode.edge2;
    }

    private static inline function isJoined(e:Active):Bool {
        return e.joinWith != JoinWith.None;
    }

    // Add methods for path building
    private static function addLocMin(vert:Vertex, polytype:PathType, isOpen:Bool, minimaList:Array<LocalMinima>):Void {
        if ((vert.flags & VertexFlags.LocalMin) != VertexFlags.None) return;
        vert.flags = vert.flags | VertexFlags.LocalMin;
        var lm = new LocalMinima(vert, polytype, isOpen);
        minimaList.push(lm);
    }

    private static function addPathsToVertexList(paths:Paths64, polytype:PathType, isOpen:Bool,
                                                   minimaList:Array<LocalMinima>, vertexList:Array<Vertex>):Void {
        for (path in paths) {
            var v0:Null<Vertex> = null;
            var prev_v:Null<Vertex> = null;
            var curr_v:Vertex;

            for (pt in path) {
                if (v0 == null) {
                    v0 = new Vertex(pt, VertexFlags.None, null);
                    vertexList.push(v0);
                    prev_v = v0;
                } else if (prev_v.pt != pt) {
                    curr_v = new Vertex(pt, VertexFlags.None, prev_v);
                    vertexList.push(curr_v);
                    prev_v.next = curr_v;
                    prev_v = curr_v;
                }
            }

            if (prev_v == null || prev_v.prev == null) continue;
            if (!isOpen && prev_v.pt == v0.pt) prev_v = prev_v.prev;
            prev_v.next = v0;
            v0.prev = prev_v;
            if (!isOpen && prev_v.next == prev_v) continue;

            var going_up:Bool;
            if (isOpen) {
                curr_v = v0.next;
                while (curr_v != v0 && curr_v.pt.y == v0.pt.y)
                    curr_v = curr_v.next;
                going_up = curr_v.pt.y <= v0.pt.y;
                if (going_up) {
                    v0.flags = VertexFlags.OpenStart;
                    addLocMin(v0, polytype, true, minimaList);
                } else {
                    v0.flags = VertexFlags.OpenStart | VertexFlags.LocalMax;
                }
            } else {
                prev_v = v0.prev;
                while (prev_v != v0 && prev_v.pt.y == v0.pt.y)
                    prev_v = prev_v.prev;
                if (prev_v == v0) continue;
                going_up = prev_v.pt.y > v0.pt.y;
            }

            var going_up0 = going_up;
            prev_v = v0;
            curr_v = v0.next;
            while (curr_v != v0) {
                if (curr_v.pt.y > prev_v.pt.y && going_up) {
                    prev_v.flags = prev_v.flags | VertexFlags.LocalMax;
                    going_up = false;
                } else if (curr_v.pt.y < prev_v.pt.y && !going_up) {
                    going_up = true;
                    addLocMin(prev_v, polytype, isOpen, minimaList);
                }
                prev_v = curr_v;
                curr_v = curr_v.next;
            }

            if (isOpen) {
                prev_v.flags = prev_v.flags | VertexFlags.OpenEnd;
                if (going_up)
                    prev_v.flags = prev_v.flags | VertexFlags.LocalMax;
                else
                    addLocMin(prev_v, polytype, isOpen, minimaList);
            } else if (going_up != going_up0) {
                if (going_up0) addLocMin(prev_v, polytype, false, minimaList);
                else prev_v.flags = prev_v.flags | VertexFlags.LocalMax;
            }
        }
    }

    // Instance methods
    private function clearSolutionOnly():Void {
        while (_actives != null) deleteFromAEL(_actives);
        _scanlineList.resize(0);
        disposeIntersectNodes();
        _outrecList.resize(0);
        _horzSegList.resize(0);
        _horzJoinList.resize(0);
    }

    public function clear():Void {
        clearSolutionOnly();
        _minimaList.resize(0);
        _vertexList.resize(0);
        _currentLocMin = 0;
        _isSortedMinimaList = false;
        _hasOpenPaths = false;
    }

    private function reset():Void {
        if (!_isSortedMinimaList) {
            _minimaList.sort(LocalMinima.compare);
            _isSortedMinimaList = true;
        }

        var i = _minimaList.length - 1;
        while (i >= 0) {
            _scanlineList.push(_minimaList[i].vertex.pt.y);
            i--;
        }

        _currentBotY = ClipperInt64.ofInt(0);
        _currentLocMin = 0;
        _actives = null;
        _sel = null;
        _succeeded = true;
    }

    private function insertScanline(y:ClipperInt64):Void {
        var lo = 0;
        var hi = _scanlineList.length;
        while (lo < hi) {
            var mid = (lo + hi) >>> 1;
            if (_scanlineList[mid] < y)
                lo = mid + 1;
            else if (_scanlineList[mid] > y)
                hi = mid;
            else
                return;
        }
        _scanlineList.insert(lo, y);
    }

    private function popScanline():{y:ClipperInt64, success:Bool} {
        var cnt = _scanlineList.length - 1;
        if (cnt < 0) {
            return {y: ClipperInt64.ofInt(0), success: false};
        }

        var y = _scanlineList[cnt];
        _scanlineList.pop();
        cnt--;
        while (cnt >= 0 && y == _scanlineList[cnt]) {
            _scanlineList.pop();
            cnt--;
        }
        return {y: y, success: true};
    }

    private inline function hasLocMinAtY(y:ClipperInt64):Bool {
        return _currentLocMin < _minimaList.length && _minimaList[_currentLocMin].vertex.pt.y == y;
    }

    private inline function popLocalMinima():LocalMinima {
        return _minimaList[_currentLocMin++];
    }

    public function addSubject(path:Path64):Void {
        addPath(path, PathType.Subject);
    }

    public function addOpenSubject(path:Path64):Void {
        addPath(path, PathType.Subject, true);
    }

    public function addClip(path:Path64):Void {
        addPath(path, PathType.Clip);
    }

    private function addPath(path:Path64, polytype:PathType, isOpen:Bool = false):Void {
        var tmp:Paths64 = [path];
        addPaths(tmp, polytype, isOpen);
    }

    private function addPaths(paths:Paths64, polytype:PathType, isOpen:Bool = false):Void {
        if (isOpen) _hasOpenPaths = true;
        _isSortedMinimaList = false;
        addPathsToVertexList(paths, polytype, isOpen, _minimaList, _vertexList);
    }

    private function deleteFromAEL(ae:Active):Void {
        var prev = ae.prevInAEL;
        var next = ae.nextInAEL;
        if (prev == null && next == null && ae != _actives) return;
        if (prev != null)
            prev.nextInAEL = next;
        else
            _actives = next;
        if (next != null)
            next.prevInAEL = prev;
    }

    private function disposeIntersectNodes():Void {
        _intersectList.resize(0);
    }

    // Wind count methods
    private function isContributingClosed(ae:Active):Bool {
        switch (_fillrule) {
            case FillRule.Positive:
                if (ae.windCount != 1) return false;
            case FillRule.Negative:
                if (ae.windCount != -1) return false;
            case FillRule.NonZero:
                if (Std.int(Math.abs(ae.windCount)) != 1) return false;
            default:
        }

        switch (_cliptype) {
            case ClipType.Intersection:
                return switch (_fillrule) {
                    case FillRule.Positive: ae.windCount2 > 0;
                    case FillRule.Negative: ae.windCount2 < 0;
                    default: ae.windCount2 != 0;
                };

            case ClipType.Union:
                return switch (_fillrule) {
                    case FillRule.Positive: ae.windCount2 <= 0;
                    case FillRule.Negative: ae.windCount2 >= 0;
                    default: ae.windCount2 == 0;
                };

            case ClipType.Difference:
                var result = switch (_fillrule) {
                    case FillRule.Positive: ae.windCount2 <= 0;
                    case FillRule.Negative: ae.windCount2 >= 0;
                    default: ae.windCount2 == 0;
                };
                return (getPolyType(ae) == PathType.Subject) ? result : !result;

            case ClipType.Xor:
                return true;

            default:
                return false;
        }
    }

    private function isContributingOpen(ae:Active):Bool {
        var isInClip:Bool, isInSubj:Bool;
        switch (_fillrule) {
            case FillRule.Positive:
                isInSubj = ae.windCount > 0;
                isInClip = ae.windCount2 > 0;
            case FillRule.Negative:
                isInSubj = ae.windCount < 0;
                isInClip = ae.windCount2 < 0;
            default:
                isInSubj = ae.windCount != 0;
                isInClip = ae.windCount2 != 0;
        }

        return switch (_cliptype) {
            case ClipType.Intersection: isInClip;
            case ClipType.Union: !isInSubj && !isInClip;
            default: !isInClip;
        };
    }

    private function setWindCountForClosedPathEdge(ae:Active):Void {
        var ae2 = ae.prevInAEL;
        var pt = getPolyType(ae);
        while (ae2 != null && (getPolyType(ae2) != pt || isOpen(ae2))) ae2 = ae2.prevInAEL;

        if (ae2 == null) {
            ae.windCount = ae.windDx;
            ae2 = _actives;
        } else if (_fillrule == FillRule.EvenOdd) {
            ae.windCount = ae.windDx;
            ae.windCount2 = ae2.windCount2;
            ae2 = ae2.nextInAEL;
        } else {
            if (ae2.windCount * ae2.windDx < 0) {
                if (Std.int(Math.abs(ae2.windCount)) > 1) {
                    if (ae2.windDx * ae.windDx < 0)
                        ae.windCount = ae2.windCount;
                    else
                        ae.windCount = ae2.windCount + ae.windDx;
                } else
                    ae.windCount = (isOpen(ae) ? 1 : ae.windDx);
            } else {
                if (ae2.windDx * ae.windDx < 0)
                    ae.windCount = ae2.windCount;
                else
                    ae.windCount = ae2.windCount + ae.windDx;
            }

            ae.windCount2 = ae2.windCount2;
            ae2 = ae2.nextInAEL;
        }

        if (_fillrule == FillRule.EvenOdd)
            while (ae2 != ae) {
                if (getPolyType(ae2) != pt && !isOpen(ae2))
                    ae.windCount2 = (ae.windCount2 == 0 ? 1 : 0);
                ae2 = ae2.nextInAEL;
            }
        else
            while (ae2 != ae) {
                if (getPolyType(ae2) != pt && !isOpen(ae2))
                    ae.windCount2 += ae2.windDx;
                ae2 = ae2.nextInAEL;
            }
    }

    private function setWindCountForOpenPathEdge(ae:Active):Void {
        var ae2 = _actives;
        if (_fillrule == FillRule.EvenOdd) {
            var cnt1 = 0, cnt2 = 0;
            while (ae2 != ae) {
                if (getPolyType(ae2) == PathType.Clip)
                    cnt2++;
                else if (!isOpen(ae2))
                    cnt1++;
                ae2 = ae2.nextInAEL;
            }

            ae.windCount = isOdd(cnt1) ? 1 : 0;
            ae.windCount2 = isOdd(cnt2) ? 1 : 0;
        } else {
            while (ae2 != ae) {
                if (getPolyType(ae2) == PathType.Clip)
                    ae.windCount2 += ae2.windDx;
                else if (!isOpen(ae2))
                    ae.windCount += ae2.windDx;
                ae2 = ae2.nextInAEL;
            }
        }
    }

    private static function isValidAelOrder(resident:Active, newcomer:Active):Bool {
        if (newcomer.curX != resident.curX)
            return newcomer.curX > resident.curX;

        var d = InternalClipper.crossProductSign(resident.top, newcomer.bot, newcomer.top);
        if (d != 0) return (d < 0);

        if (!isMaxima(resident) && (resident.top.y > newcomer.top.y)) {
            return InternalClipper.crossProductSign(newcomer.bot,
                resident.top, nextVertex(resident).pt) <= 0;
        }

        if (!isMaxima(newcomer) && (newcomer.top.y > resident.top.y)) {
            return InternalClipper.crossProductSign(newcomer.bot,
                newcomer.top, nextVertex(newcomer).pt) >= 0;
        }

        var y = newcomer.bot.y;
        var newcomerIsLeft = newcomer.isLeftBound;

        if (resident.bot.y != y || resident.localMin.vertex.pt.y != y)
            return newcomer.isLeftBound;
        if (resident.isLeftBound != newcomerIsLeft)
            return newcomerIsLeft;
        if (InternalClipper.isCollinear(prevPrevVertex(resident).pt,
                resident.bot, resident.top)) return true;
        return (InternalClipper.crossProductSign(prevPrevVertex(resident).pt,
            newcomer.bot, prevPrevVertex(newcomer).pt) > 0) == newcomerIsLeft;
    }

    private function insertLeftEdge(ae:Active):Void {
        if (_actives == null) {
            ae.prevInAEL = null;
            ae.nextInAEL = null;
            _actives = ae;
        } else if (!isValidAelOrder(_actives, ae)) {
            ae.prevInAEL = null;
            ae.nextInAEL = _actives;
            _actives.prevInAEL = ae;
            _actives = ae;
        } else {
            var ae2 = _actives;
            while (ae2.nextInAEL != null && isValidAelOrder(ae2.nextInAEL, ae))
                ae2 = ae2.nextInAEL;
            if (ae2.joinWith == JoinWith.Right) ae2 = ae2.nextInAEL;
            ae.nextInAEL = ae2.nextInAEL;
            if (ae2.nextInAEL != null) ae2.nextInAEL.prevInAEL = ae;
            ae.prevInAEL = ae2;
            ae2.nextInAEL = ae;
        }
    }

    private static function insertRightEdge(ae:Active, ae2:Active):Void {
        ae2.nextInAEL = ae.nextInAEL;
        if (ae.nextInAEL != null) ae.nextInAEL.prevInAEL = ae2;
        ae2.prevInAEL = ae;
        ae.nextInAEL = ae2;
    }

    private function insertLocalMinimaIntoAEL(botY:ClipperInt64):Void {
        while (hasLocMinAtY(botY)) {
            var localMinima = popLocalMinima();
            var leftBound:Null<Active>;
            if ((localMinima.vertex.flags & VertexFlags.OpenStart) != VertexFlags.None) {
                leftBound = null;
            } else {
                leftBound = new Active();
                leftBound.bot = localMinima.vertex.pt;
                leftBound.curX = localMinima.vertex.pt.x;
                leftBound.windDx = -1;
                leftBound.vertexTop = localMinima.vertex.prev;
                leftBound.top = localMinima.vertex.prev.pt;
                leftBound.outrec = null;
                leftBound.localMin = localMinima;
                setDx(leftBound);
            }

            var rightBound:Null<Active>;
            if ((localMinima.vertex.flags & VertexFlags.OpenEnd) != VertexFlags.None) {
                rightBound = null;
            } else {
                rightBound = new Active();
                rightBound.bot = localMinima.vertex.pt;
                rightBound.curX = localMinima.vertex.pt.x;
                rightBound.windDx = 1;
                rightBound.vertexTop = localMinima.vertex.next;
                rightBound.top = localMinima.vertex.next.pt;
                rightBound.outrec = null;
                rightBound.localMin = localMinima;
                setDx(rightBound);
            }

            if (leftBound != null && rightBound != null) {
                if (isHorizontal(leftBound)) {
                    if (isHeadingRightHorz(leftBound)) {
                        var tmp = leftBound;
                        leftBound = rightBound;
                        rightBound = tmp;
                    }
                } else if (isHorizontal(rightBound)) {
                    if (isHeadingLeftHorz(rightBound)) {
                        var tmp = leftBound;
                        leftBound = rightBound;
                        rightBound = tmp;
                    }
                } else if (leftBound.dx < rightBound.dx) {
                    var tmp = leftBound;
                    leftBound = rightBound;
                    rightBound = tmp;
                }
            } else if (leftBound == null) {
                leftBound = rightBound;
                rightBound = null;
            }

            var contributing:Bool;
            leftBound.isLeftBound = true;
            insertLeftEdge(leftBound);

            if (isOpen(leftBound)) {
                setWindCountForOpenPathEdge(leftBound);
                contributing = isContributingOpen(leftBound);
            } else {
                setWindCountForClosedPathEdge(leftBound);
                contributing = isContributingClosed(leftBound);
            }

            if (rightBound != null) {
                rightBound.windCount = leftBound.windCount;
                rightBound.windCount2 = leftBound.windCount2;
                insertRightEdge(leftBound, rightBound);

                if (contributing) {
                    addLocalMinPoly(leftBound, rightBound, leftBound.bot, true);
                    if (!isHorizontal(leftBound))
                        checkJoinLeft(leftBound, leftBound.bot);
                }

                while (rightBound.nextInAEL != null &&
                       isValidAelOrder(rightBound.nextInAEL, rightBound)) {
                    intersectEdges(rightBound, rightBound.nextInAEL, rightBound.bot);
                    swapPositionsInAEL(rightBound, rightBound.nextInAEL);
                }

                if (isHorizontal(rightBound))
                    pushHorz(rightBound);
                else {
                    checkJoinRight(rightBound, rightBound.bot);
                    insertScanline(rightBound.top.y);
                }
            } else if (contributing)
                startOpenPath(leftBound, leftBound.bot);

            if (isHorizontal(leftBound))
                pushHorz(leftBound);
            else
                insertScanline(leftBound.top.y);
        }
    }

    private function pushHorz(ae:Active):Void {
        ae.nextInSEL = _sel;
        _sel = ae;
    }

    private function popHorz():{ae:Null<Active>, success:Bool} {
        var ae = _sel;
        if (_sel == null) return {ae: null, success: false};
        _sel = _sel.nextInSEL;
        return {ae: ae, success: true};
    }

    private function newOutRec():OutRec {
        var idx = _outrecList.length;
        var result = new OutRec();
        result.idx = idx;
        _outrecList.push(result);
        return result;
    }

    private function addLocalMinPoly(ae1:Active, ae2:Active, pt:Point64, isNew:Bool = false):OutPt {
        var outrec = newOutRec();
        ae1.outrec = outrec;
        ae2.outrec = outrec;

        if (isOpen(ae1)) {
            outrec.owner = null;
            outrec.isOpen = true;
            if (ae1.windDx > 0)
                setSides(outrec, ae1, ae2);
            else
                setSides(outrec, ae2, ae1);
        } else {
            outrec.isOpen = false;
            var prevHotEdge = getPrevHotEdge(ae1);
            if (prevHotEdge != null) {
                if (_using_polytree)
                    setOwner(outrec, prevHotEdge.outrec);
                outrec.owner = prevHotEdge.outrec;
                if (outrecIsAscending(prevHotEdge) == isNew)
                    setSides(outrec, ae2, ae1);
                else
                    setSides(outrec, ae1, ae2);
            } else {
                outrec.owner = null;
                if (isNew)
                    setSides(outrec, ae1, ae2);
                else
                    setSides(outrec, ae2, ae1);
            }
        }

        var op = new OutPt(pt, outrec);
        outrec.pts = op;
        outrec.outPtCount = 1;
        return op;
    }

    private function addLocalMaxPoly(ae1:Active, ae2:Active, pt:Point64):Null<OutPt> {
        if (isJoined(ae1)) split(ae1, pt);
        if (isJoined(ae2)) split(ae2, pt);

        if (isFront(ae1) == isFront(ae2)) {
            if (isOpenEnd(ae1))
                swapFrontBackSides(ae1.outrec);
            else if (isOpenEnd(ae2))
                swapFrontBackSides(ae2.outrec);
            else {
                _succeeded = false;
                return null;
            }
        }

        var result = addOutPt(ae1, pt);
        if (ae1.outrec == ae2.outrec) {
            var outrec = ae1.outrec;
            outrec.pts = result;

            if (_using_polytree) {
                var e = getPrevHotEdge(ae1);
                if (e == null)
                    outrec.owner = null;
                else
                    setOwner(outrec, e.outrec);
            }
            uncoupleOutRec(ae1);
        } else if (isOpen(ae1)) {
            if (ae1.windDx < 0)
                joinOutrecPaths(ae1, ae2);
            else
                joinOutrecPaths(ae2, ae1);
        } else if (ae1.outrec.idx < ae2.outrec.idx)
            joinOutrecPaths(ae1, ae2);
        else
            joinOutrecPaths(ae2, ae1);
        return result;
    }

    private static function joinOutrecPaths(ae1:Active, ae2:Active):Void {
        var p1Start = ae1.outrec.pts;
        var p2Start = ae2.outrec.pts;
        var p1End = p1Start.next;
        var p2End = p2Start.next;
        if (isFront(ae1)) {
            p2End.prev = p1Start;
            p1Start.next = p2End;
            p2Start.next = p1End;
            p1End.prev = p2Start;
            ae1.outrec.pts = p2Start;
            ae1.outrec.frontEdge = ae2.outrec.frontEdge;
            if (ae1.outrec.frontEdge != null)
                ae1.outrec.frontEdge.outrec = ae1.outrec;
        } else {
            p1End.prev = p2Start;
            p2Start.next = p1End;
            p1Start.next = p2End;
            p2End.prev = p1Start;

            ae1.outrec.backEdge = ae2.outrec.backEdge;
            if (ae1.outrec.backEdge != null)
                ae1.outrec.backEdge.outrec = ae1.outrec;
        }

        ae2.outrec.frontEdge = null;
        ae2.outrec.backEdge = null;
        ae2.outrec.pts = null;
        ae1.outrec.outPtCount += ae2.outrec.outPtCount;
        setOwner(ae2.outrec, ae1.outrec);

        if (isOpenEnd(ae1)) {
            ae2.outrec.pts = ae1.outrec.pts;
            ae1.outrec.pts = null;
        }

        ae1.outrec = null;
        ae2.outrec = null;
    }

    private function addOutPt(ae:Active, pt:Point64):OutPt {
        var outrec = ae.outrec;
        var toFront = isFront(ae);
        var opFront = outrec.pts;
        var opBack = opFront.next;

        if (toFront && pt == opFront.pt)
            return opFront;
        if (!toFront && pt == opBack.pt)
            return opBack;

        var newOp = new OutPt(pt, outrec);
        opBack.prev = newOp;
        newOp.prev = opFront;
        newOp.next = opBack;
        opFront.next = newOp;
        if (toFront) outrec.pts = newOp;
        outrec.outPtCount++;
        return newOp;
    }

    private function startOpenPath(ae:Active, pt:Point64):OutPt {
        var outrec = newOutRec();
        outrec.isOpen = true;
        if (ae.windDx > 0) {
            outrec.frontEdge = ae;
            outrec.backEdge = null;
        } else {
            outrec.frontEdge = null;
            outrec.backEdge = ae;
        }

        ae.outrec = outrec;
        var op = new OutPt(pt, outrec);
        outrec.pts = op;
        return op;
    }

    private function updateEdgeIntoAEL(ae:Active):Void {
        ae.bot = ae.top;
        ae.vertexTop = nextVertex(ae);
        ae.top = ae.vertexTop.pt;
        ae.curX = ae.bot.x;
        setDx(ae);

        if (isJoined(ae)) split(ae, ae.bot);

        if (isHorizontal(ae)) {
            if (!isOpen(ae)) trimHorz(ae, preserveCollinear);
            return;
        }
        insertScanline(ae.top.y);

        checkJoinLeft(ae, ae.bot);
        checkJoinRight(ae, ae.bot, true);
    }

    private static function findEdgeWithMatchingLocMin(e:Active):Null<Active> {
        var result = e.nextInAEL;
        while (result != null) {
            if (result.localMin == e.localMin) return result;
            if (!isHorizontal(result) && e.bot != result.bot) result = null;
            else result = result.nextInAEL;
        }
        result = e.prevInAEL;
        while (result != null) {
            if (result.localMin == e.localMin) return result;
            if (!isHorizontal(result) && e.bot != result.bot) return null;
            result = result.prevInAEL;
        }
        return result;
    }

    private function intersectEdges(ae1:Active, ae2:Active, pt:Point64):Void {
        var resultOp:Null<OutPt> = null;

        // MANAGE OPEN PATH INTERSECTIONS SEPARATELY
        if (_hasOpenPaths && (isOpen(ae1) || isOpen(ae2))) {
            if (isOpen(ae1) && isOpen(ae2)) return;
            if (isOpen(ae2)) {
                var tmp = ae1;
                ae1 = ae2;
                ae2 = tmp;
            }
            if (isJoined(ae2)) split(ae2, pt);

            if (_cliptype == ClipType.Union) {
                if (!isHotEdge(ae2)) return;
            } else if (ae2.localMin.polytype == PathType.Subject) return;

            switch (_fillrule) {
                case FillRule.Positive:
                    if (ae2.windCount != 1) return;
                case FillRule.Negative:
                    if (ae2.windCount != -1) return;
                default:
                    if (Std.int(Math.abs(ae2.windCount)) != 1) return;
            }

            if (isHotEdge(ae1)) {
                resultOp = addOutPt(ae1, pt);
                if (isFront(ae1))
                    ae1.outrec.frontEdge = null;
                else
                    ae1.outrec.backEdge = null;
                ae1.outrec = null;
            } else if (pt == ae1.localMin.vertex.pt && !isOpenEndVertex(ae1.localMin.vertex)) {
                var ae3 = findEdgeWithMatchingLocMin(ae1);
                if (ae3 != null && isHotEdge(ae3)) {
                    ae1.outrec = ae3.outrec;
                    if (ae1.windDx > 0)
                        setSides(ae3.outrec, ae1, ae3);
                    else
                        setSides(ae3.outrec, ae3, ae1);
                    return;
                }

                resultOp = startOpenPath(ae1, pt);
            } else
                resultOp = startOpenPath(ae1, pt);

            return;
        }

        // MANAGING CLOSED PATHS FROM HERE ON
        if (isJoined(ae1)) split(ae1, pt);
        if (isJoined(ae2)) split(ae2, pt);

        // UPDATE WINDING COUNTS
        var oldE1WindCount:Int, oldE2WindCount:Int;
        if (ae1.localMin.polytype == ae2.localMin.polytype) {
            if (_fillrule == FillRule.EvenOdd) {
                oldE1WindCount = ae1.windCount;
                ae1.windCount = ae2.windCount;
                ae2.windCount = oldE1WindCount;
            } else {
                if (ae1.windCount + ae2.windDx == 0)
                    ae1.windCount = -ae1.windCount;
                else
                    ae1.windCount += ae2.windDx;
                if (ae2.windCount - ae1.windDx == 0)
                    ae2.windCount = -ae2.windCount;
                else
                    ae2.windCount -= ae1.windDx;
            }
        } else {
            if (_fillrule != FillRule.EvenOdd)
                ae1.windCount2 += ae2.windDx;
            else
                ae1.windCount2 = (ae1.windCount2 == 0 ? 1 : 0);
            if (_fillrule != FillRule.EvenOdd)
                ae2.windCount2 -= ae1.windDx;
            else
                ae2.windCount2 = (ae2.windCount2 == 0 ? 1 : 0);
        }

        switch (_fillrule) {
            case FillRule.Positive:
                oldE1WindCount = ae1.windCount;
                oldE2WindCount = ae2.windCount;
            case FillRule.Negative:
                oldE1WindCount = -ae1.windCount;
                oldE2WindCount = -ae2.windCount;
            default:
                oldE1WindCount = Std.int(Math.abs(ae1.windCount));
                oldE2WindCount = Std.int(Math.abs(ae2.windCount));
        }

        var e1WindCountIs0or1 = oldE1WindCount == 0 || oldE1WindCount == 1;
        var e2WindCountIs0or1 = oldE2WindCount == 0 || oldE2WindCount == 1;

        if ((!isHotEdge(ae1) && !e1WindCountIs0or1) ||
            (!isHotEdge(ae2) && !e2WindCountIs0or1)) return;

        // NOW PROCESS THE INTERSECTION
        if (isHotEdge(ae1) && isHotEdge(ae2)) {
            if ((oldE1WindCount != 0 && oldE1WindCount != 1) || (oldE2WindCount != 0 && oldE2WindCount != 1) ||
                (ae1.localMin.polytype != ae2.localMin.polytype && _cliptype != ClipType.Xor)) {
                resultOp = addLocalMaxPoly(ae1, ae2, pt);
            } else if (isFront(ae1) || (ae1.outrec == ae2.outrec)) {
                resultOp = addLocalMaxPoly(ae1, ae2, pt);
                addLocalMinPoly(ae1, ae2, pt);
            } else {
                resultOp = addOutPt(ae1, pt);
                addOutPt(ae2, pt);
                swapOutrecs(ae1, ae2);
            }
        } else if (isHotEdge(ae1)) {
            resultOp = addOutPt(ae1, pt);
            swapOutrecs(ae1, ae2);
        } else if (isHotEdge(ae2)) {
            resultOp = addOutPt(ae2, pt);
            swapOutrecs(ae1, ae2);
        } else {
            var e1Wc2:Int, e2Wc2:Int;
            switch (_fillrule) {
                case FillRule.Positive:
                    e1Wc2 = ae1.windCount2;
                    e2Wc2 = ae2.windCount2;
                case FillRule.Negative:
                    e1Wc2 = -ae1.windCount2;
                    e2Wc2 = -ae2.windCount2;
                default:
                    e1Wc2 = Std.int(Math.abs(ae1.windCount2));
                    e2Wc2 = Std.int(Math.abs(ae2.windCount2));
            }

            if (!isSamePolyType(ae1, ae2)) {
                resultOp = addLocalMinPoly(ae1, ae2, pt);
            } else if (oldE1WindCount == 1 && oldE2WindCount == 1) {
                resultOp = null;
                switch (_cliptype) {
                    case ClipType.Union:
                        if (e1Wc2 > 0 && e2Wc2 > 0) return;
                        resultOp = addLocalMinPoly(ae1, ae2, pt);

                    case ClipType.Difference:
                        if (((getPolyType(ae1) == PathType.Clip) && (e1Wc2 > 0) && (e2Wc2 > 0)) ||
                            ((getPolyType(ae1) == PathType.Subject) && (e1Wc2 <= 0) && (e2Wc2 <= 0))) {
                            resultOp = addLocalMinPoly(ae1, ae2, pt);
                        }

                    case ClipType.Xor:
                        resultOp = addLocalMinPoly(ae1, ae2, pt);

                    default:
                        if (e1Wc2 <= 0 || e2Wc2 <= 0) return;
                        resultOp = addLocalMinPoly(ae1, ae2, pt);
                }
            }
        }
    }

    private function swapPositionsInAEL(ae1:Active, ae2:Active):Void {
        var next = ae2.nextInAEL;
        if (next != null) next.prevInAEL = ae1;
        var prev = ae1.prevInAEL;
        if (prev != null) prev.nextInAEL = ae2;
        ae2.prevInAEL = prev;
        ae2.nextInAEL = ae1;
        ae1.prevInAEL = ae2;
        ae1.nextInAEL = next;
        if (ae2.prevInAEL == null) _actives = ae2;
    }

    private function split(e:Active, currPt:Point64):Void {
        if (e.joinWith == JoinWith.Right) {
            e.joinWith = JoinWith.None;
            e.nextInAEL.joinWith = JoinWith.None;
            addLocalMinPoly(e, e.nextInAEL, currPt, true);
        } else {
            e.joinWith = JoinWith.None;
            e.prevInAEL.joinWith = JoinWith.None;
            addLocalMinPoly(e.prevInAEL, e, currPt, true);
        }
    }

    private function checkJoinLeft(e:Active, pt:Point64, checkCurrX:Bool = false):Void {
        var prev = e.prevInAEL;
        if (prev == null ||
            !isHotEdge(e) || !isHotEdge(prev) ||
            isHorizontal(e) || isHorizontal(prev) ||
            isOpen(e) || isOpen(prev)) return;
        if ((pt.y < e.top.y + 2 || pt.y < prev.top.y + 2) &&
            ((e.bot.y > pt.y) || (prev.bot.y > pt.y))) return;

        if (checkCurrX) {
            if (perpendicDistFromLineSqrd(pt, prev.bot, prev.top) > 0.25) return;
        } else if (e.curX != prev.curX) return;
        if (!InternalClipper.isCollinear(e.top, pt, prev.top)) return;

        if (e.outrec.idx == prev.outrec.idx)
            addLocalMaxPoly(prev, e, pt);
        else if (e.outrec.idx < prev.outrec.idx)
            joinOutrecPaths(e, prev);
        else
            joinOutrecPaths(prev, e);
        prev.joinWith = JoinWith.Right;
        e.joinWith = JoinWith.Left;
    }

    private function checkJoinRight(e:Active, pt:Point64, checkCurrX:Bool = false):Void {
        var next = e.nextInAEL;
        if (next == null ||
            !isHotEdge(e) || !isHotEdge(next) ||
            isHorizontal(e) || isHorizontal(next) ||
            isOpen(e) || isOpen(next)) return;
        if ((pt.y < e.top.y + 2 || pt.y < next.top.y + 2) &&
            ((e.bot.y > pt.y) || (next.bot.y > pt.y))) return;

        if (checkCurrX) {
            if (perpendicDistFromLineSqrd(pt, next.bot, next.top) > 0.25) return;
        } else if (e.curX != next.curX) return;
        if (!InternalClipper.isCollinear(e.top, pt, next.top)) return;

        if (e.outrec.idx == next.outrec.idx)
            addLocalMaxPoly(e, next, pt);
        else if (e.outrec.idx < next.outrec.idx)
            joinOutrecPaths(e, next);
        else
            joinOutrecPaths(next, e);
        e.joinWith = JoinWith.Right;
        next.joinWith = JoinWith.Left;
    }

    private static function perpendicDistFromLineSqrd(pt:Point64, line1:Point64, line2:Point64):Float {
        var dx = InternalClipper.toFloat(line2.x) - InternalClipper.toFloat(line1.x);
        var dy = InternalClipper.toFloat(line2.y) - InternalClipper.toFloat(line1.y);
        if (dx == 0 && dy == 0) return 0;
        var t = ((InternalClipper.toFloat(pt.x) - InternalClipper.toFloat(line1.x)) * dx + (InternalClipper.toFloat(pt.y) - InternalClipper.toFloat(line1.y)) * dy) / (dx * dx + dy * dy);
        var closestX = InternalClipper.toFloat(line1.x) + t * dx;
        var closestY = InternalClipper.toFloat(line1.y) + t * dy;
        var distX = InternalClipper.toFloat(pt.x) - closestX;
        var distY = InternalClipper.toFloat(pt.y) - closestY;
        return distX * distX + distY * distY;
    }

    private static function trimHorz(horzEdge:Active, preserveCollinear:Bool):Void {
        var wasTrimmed = false;
        var pt = nextVertex(horzEdge).pt;

        while (pt.y == horzEdge.top.y) {
            if (preserveCollinear &&
                (pt.x < horzEdge.top.x) != (horzEdge.bot.x < horzEdge.top.x))
                break;

            horzEdge.vertexTop = nextVertex(horzEdge);
            horzEdge.top = pt;
            wasTrimmed = true;
            if (isMaxima(horzEdge)) break;
            pt = nextVertex(horzEdge).pt;
        }
        if (wasTrimmed) setDx(horzEdge);
    }

    private function addToHorzSegList(op:OutPt):Void {
        if (op.outrec.isOpen) return;
        _horzSegList.push(new HorzSegment(op));
    }

    private static function getLastOp(hotEdge:Active):OutPt {
        var outrec = hotEdge.outrec;
        return (hotEdge == outrec.frontEdge) ?
            outrec.pts : outrec.pts.next;
    }

    private static function resetHorzDirection(horz:Active, vertexMax:Null<Vertex>):{leftX:ClipperInt64, rightX:ClipperInt64, isLeftToRight:Bool} {
        if (horz.bot.x == horz.top.x) {
            var ae = horz.nextInAEL;
            while (ae != null && ae.vertexTop != vertexMax)
                ae = ae.nextInAEL;
            return {leftX: horz.curX, rightX: horz.curX, isLeftToRight: ae != null};
        }

        if (horz.curX < horz.top.x) {
            return {leftX: horz.curX, rightX: horz.top.x, isLeftToRight: true};
        }
        return {leftX: horz.top.x, rightX: horz.curX, isLeftToRight: false};
    }

    private function doHorizontal(horz:Active):Void {
        var horzIsOpen = isOpen(horz);
        var Y = horz.bot.y;

        var vertex_max = horzIsOpen ?
            getCurrYMaximaVertex_Open(horz) :
            getCurrYMaximaVertex(horz);

        var horzDir = resetHorzDirection(horz, vertex_max);
        var isLeftToRight = horzDir.isLeftToRight;
        var leftX = horzDir.leftX;
        var rightX = horzDir.rightX;

        if (isHotEdge(horz)) {
            var op = addOutPt(horz, new Point64(horz.curX, Y));
            addToHorzSegList(op);
        }

        while (true) {
            var ae = isLeftToRight ? horz.nextInAEL : horz.prevInAEL;

            while (ae != null) {
                if (ae.vertexTop == vertex_max) {
                    if (isHotEdge(horz) && isJoined(ae)) split(ae, ae.top);

                    if (isHotEdge(horz)) {
                        while (horz.vertexTop != vertex_max) {
                            addOutPt(horz, horz.top);
                            updateEdgeIntoAEL(horz);
                        }
                        if (isLeftToRight)
                            addLocalMaxPoly(horz, ae, horz.top);
                        else
                            addLocalMaxPoly(ae, horz, horz.top);
                    }
                    deleteFromAEL(ae);
                    deleteFromAEL(horz);
                    return;
                }

                var pt:Point64;
                if (vertex_max != horz.vertexTop || isOpenEnd(horz)) {
                    if ((isLeftToRight && ae.curX > rightX) ||
                        (!isLeftToRight && ae.curX < leftX)) break;

                    if (ae.curX == horz.top.x && !isHorizontal(ae)) {
                        pt = nextVertex(horz).pt;

                        if (isOpen(ae) && !isSamePolyType(ae, horz) && !isHotEdge(ae)) {
                            if ((isLeftToRight && (topX(ae, pt.y) > pt.x)) ||
                                (!isLeftToRight && (topX(ae, pt.y) < pt.x))) break;
                        } else if ((isLeftToRight && (topX(ae, pt.y) >= pt.x)) ||
                            (!isLeftToRight && (topX(ae, pt.y) <= pt.x))) break;
                    }
                }

                pt = new Point64(ae.curX, Y);

                if (isLeftToRight) {
                    intersectEdges(horz, ae, pt);
                    swapPositionsInAEL(horz, ae);
                    checkJoinLeft(ae, pt);
                    horz.curX = ae.curX;
                    ae = horz.nextInAEL;
                } else {
                    intersectEdges(ae, horz, pt);
                    swapPositionsInAEL(ae, horz);
                    checkJoinRight(ae, pt);
                    horz.curX = ae.curX;
                    ae = horz.prevInAEL;
                }

                if (isHotEdge(horz))
                    addToHorzSegList(getLastOp(horz));
            }

            if (horzIsOpen && isOpenEnd(horz)) {
                if (isHotEdge(horz)) {
                    addOutPt(horz, horz.top);
                    if (isFront(horz))
                        horz.outrec.frontEdge = null;
                    else
                        horz.outrec.backEdge = null;
                    horz.outrec = null;
                }
                deleteFromAEL(horz);
                return;
            }
            if (nextVertex(horz).pt.y != horz.top.y)
                break;

            if (isHotEdge(horz))
                addOutPt(horz, horz.top);

            updateEdgeIntoAEL(horz);

            var newHorzDir = resetHorzDirection(horz, vertex_max);
            isLeftToRight = newHorzDir.isLeftToRight;
            leftX = newHorzDir.leftX;
            rightX = newHorzDir.rightX;
        }

        if (isHotEdge(horz)) {
            var op = addOutPt(horz, horz.top);
            addToHorzSegList(op);
        }

        updateEdgeIntoAEL(horz);
    }

    private function doTopOfScanbeam(y:ClipperInt64):Void {
        _sel = null;
        var ae = _actives;
        while (ae != null) {
            if (ae.top.y == y) {
                ae.curX = ae.top.x;
                if (isMaxima(ae)) {
                    ae = doMaxima(ae);
                    continue;
                }

                if (isHotEdge(ae))
                    addOutPt(ae, ae.top);
                updateEdgeIntoAEL(ae);
                if (isHorizontal(ae))
                    pushHorz(ae);
            } else
                ae.curX = topX(ae, y);

            ae = ae.nextInAEL;
        }
    }

    private function doMaxima(ae:Active):Null<Active> {
        var prevE = ae.prevInAEL;
        var nextE = ae.nextInAEL;

        if (isOpenEnd(ae)) {
            if (isHotEdge(ae)) addOutPt(ae, ae.top);
            if (isHorizontal(ae)) return nextE;
            if (isHotEdge(ae)) {
                if (isFront(ae))
                    ae.outrec.frontEdge = null;
                else
                    ae.outrec.backEdge = null;
                ae.outrec = null;
            }
            deleteFromAEL(ae);
            return nextE;
        }

        var maxPair = getMaximaPair(ae);
        if (maxPair == null) return nextE;

        if (isJoined(ae)) split(ae, ae.top);
        if (isJoined(maxPair)) split(maxPair, maxPair.top);

        while (nextE != maxPair) {
            intersectEdges(ae, nextE, ae.top);
            swapPositionsInAEL(ae, nextE);
            nextE = ae.nextInAEL;
        }

        if (isOpen(ae)) {
            if (isHotEdge(ae))
                addLocalMaxPoly(ae, maxPair, ae.top);
            deleteFromAEL(maxPair);
            deleteFromAEL(ae);
            return (prevE != null ? prevE.nextInAEL : _actives);
        }

        if (isHotEdge(ae))
            addLocalMaxPoly(ae, maxPair, ae.top);

        deleteFromAEL(ae);
        deleteFromAEL(maxPair);
        return (prevE != null ? prevE.nextInAEL : _actives);
    }

    private function adjustCurrXAndCopyToSEL(topY:ClipperInt64):Void {
        var ae = _actives;
        _sel = ae;
        while (ae != null) {
            ae.prevInSEL = ae.prevInAEL;
            ae.nextInSEL = ae.nextInAEL;
            ae.jump = ae.nextInSEL;
            ae.curX = topX(ae, topY);
            ae = ae.nextInAEL;
        }
    }

    private function doIntersections(topY:ClipperInt64):Void {
        if (!buildIntersectList(topY)) return;
        processIntersectList();
        disposeIntersectNodes();
    }

    private function addNewIntersectNode(ae1:Active, ae2:Active, topY:ClipperInt64):Void {
        var ipResult = InternalClipper.getLineIntersectPt64(ae1.bot, ae1.top, ae2.bot, ae2.top);
        var ip:Point64;
        if (!ipResult.success)
            ip = new Point64(ae1.curX, topY);
        else
            ip = ipResult.ip;

        if (ip.y > _currentBotY || ip.y < topY) {
            var absDx1 = Math.abs(ae1.dx);
            var absDx2 = Math.abs(ae2.dx);
            if (absDx1 > 100 && absDx2 > 100) {
                if (absDx1 > absDx2)
                    ip = InternalClipper.getClosestPtOnSegment(ip, ae1.bot, ae1.top);
                else
                    ip = InternalClipper.getClosestPtOnSegment(ip, ae2.bot, ae2.top);
            } else if (absDx1 > 100) {
                ip = InternalClipper.getClosestPtOnSegment(ip, ae1.bot, ae1.top);
            } else if (absDx2 > 100) {
                ip = InternalClipper.getClosestPtOnSegment(ip, ae2.bot, ae2.top);
            } else {
                if (ip.y < topY)
                    ip = new Point64(ip.x, topY);
                else
                    ip = new Point64(ip.x, _currentBotY);
                if (absDx1 < absDx2)
                    ip = new Point64(topX(ae1, ip.y), ip.y);
                else
                    ip = new Point64(topX(ae2, ip.y), ip.y);
            }
        }
        _intersectList.push(new IntersectNode(ip, ae1, ae2));
    }

    private static function extractFromSEL(ae:Active):Null<Active> {
        var res = ae.nextInSEL;
        if (res != null)
            res.prevInSEL = ae.prevInSEL;
        ae.prevInSEL.nextInSEL = res;
        return res;
    }

    private static function insert1Before2InSEL(ae1:Active, ae2:Active):Void {
        ae1.prevInSEL = ae2.prevInSEL;
        if (ae1.prevInSEL != null)
            ae1.prevInSEL.nextInSEL = ae1;
        ae1.nextInSEL = ae2;
        ae2.prevInSEL = ae1;
    }

    private function buildIntersectList(topY:ClipperInt64):Bool {
        if (_actives == null || _actives.nextInAEL == null) return false;

        adjustCurrXAndCopyToSEL(topY);

        var left = _sel;

        while (left.jump != null) {
            var prevBase:Null<Active> = null;
            while (left != null && left.jump != null) {
                var currBase = left;
                var right = left.jump;
                var lEnd = right;
                var rEnd = right.jump;
                left.jump = rEnd;
                while (left != lEnd && right != rEnd) {
                    if (right.curX < left.curX) {
                        var tmp = right.prevInSEL;
                        while (true) {
                            addNewIntersectNode(tmp, right, topY);
                            if (tmp == left) break;
                            tmp = tmp.prevInSEL;
                        }

                        tmp = right;
                        right = extractFromSEL(tmp);
                        lEnd = right;
                        insert1Before2InSEL(tmp, left);
                        if (left != currBase) continue;
                        currBase = tmp;
                        currBase.jump = rEnd;
                        if (prevBase == null) _sel = currBase;
                        else prevBase.jump = currBase;
                    } else left = left.nextInSEL;
                }

                prevBase = currBase;
                left = rEnd;
            }
            left = _sel;
        }

        return _intersectList.length > 0;
    }

    private function processIntersectList():Void {
        _intersectList.sort(IntersectNode.compare);

        var i = 0;
        while (i < _intersectList.length) {
            if (!edgesAdjacentInAEL(_intersectList[i])) {
                var j = i + 1;
                while (!edgesAdjacentInAEL(_intersectList[j])) j++;
                var tmp = _intersectList[j];
                _intersectList[j] = _intersectList[i];
                _intersectList[i] = tmp;
            }

            var node = _intersectList[i];
            intersectEdges(node.edge1, node.edge2, node.pt);
            swapPositionsInAEL(node.edge1, node.edge2);

            node.edge1.curX = node.pt.x;
            node.edge2.curX = node.pt.x;
            checkJoinLeft(node.edge2, node.pt, true);
            checkJoinRight(node.edge1, node.pt, true);
            i++;
        }
    }

    // Execute the clipping operation
    private function executeInternal(clipType:ClipType, fillRule:FillRule):Void {
        if (clipType == ClipType.NoClip) return;
        _fillrule = fillRule;
        _cliptype = clipType;
        reset();

        var result = popScanline();
        if (!result.success) return;
        var y = result.y;

        while (_succeeded) {
            insertLocalMinimaIntoAEL(y);
            var horzResult = popHorz();
            while (horzResult.success) {
                doHorizontal(horzResult.ae);
                horzResult = popHorz();
            }
            if (_horzSegList.length > 0) {
                convertHorzSegsToJoins();
                _horzSegList.resize(0);
            }
            _currentBotY = y;
            result = popScanline();
            if (!result.success)
                break;
            y = result.y;
            doIntersections(y);
            doTopOfScanbeam(y);
            horzResult = popHorz();
            while (horzResult.success) {
                doHorizontal(horzResult.ae);
                horzResult = popHorz();
            }
        }
        if (_succeeded) processHorzJoins();
    }

    // Horizontal segment processing
    private static function setHorzSegHeadingForward(hs:HorzSegment, opP:OutPt, opN:OutPt):Bool {
        if (opP.pt.x == opN.pt.x) return false;
        if (opP.pt.x < opN.pt.x) {
            hs.leftOp = opP;
            hs.rightOp = opN;
            hs.leftToRight = true;
        } else {
            hs.leftOp = opN;
            hs.rightOp = opP;
            hs.leftToRight = false;
        }
        return true;
    }

    private static function updateHorzSegment(hs:HorzSegment):Bool {
        var op = hs.leftOp;
        var outrec = getRealOutRec(op.outrec);
        var outrecHasEdges = outrec.frontEdge != null;
        var curr_y = op.pt.y;
        var opP = op, opN = op;
        if (outrecHasEdges) {
            var opA = outrec.pts, opZ = opA.next;
            while (opP != opZ && opP.prev.pt.y == curr_y)
                opP = opP.prev;
            while (opN != opA && opN.next.pt.y == curr_y)
                opN = opN.next;
        } else {
            while (opP.prev != opN && opP.prev.pt.y == curr_y)
                opP = opP.prev;
            while (opN.next != opP && opN.next.pt.y == curr_y)
                opN = opN.next;
        }
        var result = setHorzSegHeadingForward(hs, opP, opN) && hs.leftOp.horz == null;

        if (result)
            hs.leftOp.horz = hs;
        else
            hs.rightOp = null;
        return result;
    }

    private static function horzSegSort(hs1:HorzSegment, hs2:HorzSegment):Int {
        if (hs1 == null || hs2 == null) return 0;
        if (hs1.rightOp == null) {
            return hs2.rightOp == null ? 0 : 1;
        }
        if (hs2.rightOp == null)
            return -1;
        return if (hs1.leftOp.pt.x < hs2.leftOp.pt.x) -1 else if (hs1.leftOp.pt.x > hs2.leftOp.pt.x) 1 else 0;
    }

    private function duplicateOp(op:OutPt, insertAfter:Bool):OutPt {
        var result = new OutPt(op.pt, op.outrec);
        if (insertAfter) {
            result.next = op.next;
            result.next.prev = result;
            result.prev = op;
            op.next = result;
        } else {
            result.prev = op.prev;
            result.prev.next = result;
            result.next = op;
            op.prev = result;
        }
        return result;
    }

    private function convertHorzSegsToJoins():Void {
        var k = 0;
        for (hs in _horzSegList) {
            if (updateHorzSegment(hs)) k++;
        }
        if (k < 2) return;
        _horzSegList.sort(horzSegSort);

        var i = 0;
        while (i < k - 1) {
            var hs1 = _horzSegList[i];
            var j = i + 1;
            while (j < k) {
                var hs2 = _horzSegList[j];
                if ((hs2.leftOp.pt.x >= hs1.rightOp.pt.x) ||
                    (hs2.leftToRight == hs1.leftToRight) ||
                    (hs2.rightOp.pt.x <= hs1.leftOp.pt.x)) {
                    j++;
                    continue;
                }
                var curr_y = hs1.leftOp.pt.y;
                if (hs1.leftToRight) {
                    while (hs1.leftOp.next.pt.y == curr_y &&
                        hs1.leftOp.next.pt.x <= hs2.leftOp.pt.x)
                        hs1.leftOp = hs1.leftOp.next;
                    while (hs2.leftOp.prev.pt.y == curr_y &&
                        hs2.leftOp.prev.pt.x <= hs1.leftOp.pt.x)
                        hs2.leftOp = hs2.leftOp.prev;
                    _horzJoinList.push(new HorzJoin(
                        duplicateOp(hs1.leftOp, true),
                        duplicateOp(hs2.leftOp, false)));
                } else {
                    while (hs1.leftOp.prev.pt.y == curr_y &&
                        hs1.leftOp.prev.pt.x <= hs2.leftOp.pt.x)
                        hs1.leftOp = hs1.leftOp.prev;
                    while (hs2.leftOp.next.pt.y == curr_y &&
                        hs2.leftOp.next.pt.x <= hs1.leftOp.pt.x)
                        hs2.leftOp = hs2.leftOp.next;
                    _horzJoinList.push(new HorzJoin(
                        duplicateOp(hs2.leftOp, true),
                        duplicateOp(hs1.leftOp, false)));
                }
                j++;
            }
            i++;
        }
    }

    private static function fixOutRecPts(outrec:OutRec):Void {
        var op = outrec.pts;
        do {
            op.outrec = outrec;
            op = op.next;
        } while (op != outrec.pts);
    }

    private static function moveSplits(fromOr:OutRec, toOr:OutRec):Void {
        if (fromOr.splits == null) return;
        if (toOr.splits == null) toOr.splits = new Array<Int>();
        for (i in fromOr.splits)
            if (i != toOr.idx)
                toOr.splits.push(i);
        fromOr.splits = null;
    }

    private static function ptsReallyClose(pt1:Point64, pt2:Point64):Bool {
        return (Std.int(Math.abs(InternalClipper.toFloat(pt1.x - pt2.x))) < 2) &&
               (Std.int(Math.abs(InternalClipper.toFloat(pt1.y - pt2.y))) < 2);
    }

    private static function isVerySmallTriangle(op:OutPt):Bool {
        return op.next.next == op.prev &&
            (ptsReallyClose(op.prev.pt, op.next.pt) ||
                ptsReallyClose(op.pt, op.next.pt) ||
                ptsReallyClose(op.pt, op.prev.pt));
    }

    private static function isValidClosedPath(op:Null<OutPt>):Bool {
        return (op != null && op.next != op &&
            (op.next != op.prev || !isVerySmallTriangle(op)));
    }

    private static function disposeOutPt(op:OutPt):Null<OutPt> {
        var result = (op.next == op ? null : op.next);
        op.prev.next = op.next;
        op.next.prev = op.prev;
        return result;
    }

    private static function path1InsidePath2(op1:OutPt, op2:OutPt):Bool {
        var pip = PointInPolygonResult.IsOn;
        var op = op1;
        do {
            switch (pointInOpPolygon(op.pt, op2)) {
                case PointInPolygonResult.IsOutside:
                    if (pip == PointInPolygonResult.IsOutside) return false;
                    pip = PointInPolygonResult.IsOutside;
                case PointInPolygonResult.IsInside:
                    if (pip == PointInPolygonResult.IsInside) return true;
                    pip = PointInPolygonResult.IsInside;
                default:
            }
            op = op.next;
        } while (op != op1);
        return InternalClipper.path2ContainsPath1(getCleanPath(op1), getCleanPath(op2));
    }

    private static function pointInOpPolygon(pt:Point64, op:OutPt):PointInPolygonResult {
        if (op == op.next || op.prev == op.next)
            return PointInPolygonResult.IsOutside;

        var op2 = op;
        do {
            if (op.pt.y != pt.y) break;
            op = op.next;
        } while (op != op2);
        if (op.pt.y == pt.y)
            return PointInPolygonResult.IsOutside;

        var isAbove = op.pt.y < pt.y, startingAbove = isAbove;
        var val = 0;

        op2 = op.next;
        while (op2 != op) {
            if (isAbove)
                while (op2 != op && op2.pt.y < pt.y) op2 = op2.next;
            else
                while (op2 != op && op2.pt.y > pt.y) op2 = op2.next;
            if (op2 == op) break;

            if (op2.pt.y == pt.y) {
                if (op2.pt.x == pt.x || (op2.pt.y == op2.prev.pt.y &&
                    (pt.x < op2.prev.pt.x) != (pt.x < op2.pt.x)))
                    return PointInPolygonResult.IsOn;
                op2 = op2.next;
                if (op2 == op) break;
                continue;
            }

            if (op2.pt.x <= pt.x || op2.prev.pt.x <= pt.x) {
                if ((op2.prev.pt.x < pt.x && op2.pt.x < pt.x))
                    val = 1 - val;
                else {
                    var d = InternalClipper.crossProductSign(op2.prev.pt, op2.pt, pt);
                    if (d == 0) return PointInPolygonResult.IsOn;
                    if ((d < 0) == isAbove) val = 1 - val;
                }
            }
            isAbove = !isAbove;
            op2 = op2.next;
        }

        if (isAbove == startingAbove) return val == 0 ? PointInPolygonResult.IsOutside : PointInPolygonResult.IsInside;
        {
            var d = InternalClipper.crossProductSign(op2.prev.pt, op2.pt, pt);
            if (d == 0) return PointInPolygonResult.IsOn;
            if ((d < 0) == isAbove) val = 1 - val;
        }

        return val == 0 ? PointInPolygonResult.IsOutside : PointInPolygonResult.IsInside;
    }

    private static function getCleanPath(op:OutPt):Path64 {
        var result = new Path64();
        var op2 = op;
        while (op2.next != op &&
            ((op2.pt.x == op2.next.pt.x && op2.pt.x == op2.prev.pt.x) ||
                (op2.pt.y == op2.next.pt.y && op2.pt.y == op2.prev.pt.y))) op2 = op2.next;
        result.push(op2.pt);
        var prevOp = op2;
        op2 = op2.next;
        while (op2 != op) {
            if ((op2.pt.x != op2.next.pt.x || op2.pt.x != prevOp.pt.x) &&
                (op2.pt.y != op2.next.pt.y || op2.pt.y != prevOp.pt.y)) {
                result.push(op2.pt);
                prevOp = op2;
            }
            op2 = op2.next;
        }
        return result;
    }

    private function processHorzJoins():Void {
        for (j in _horzJoinList) {
            var or1 = getRealOutRec(j.op1.outrec);
            var or2 = getRealOutRec(j.op2.outrec);

            var op1b = j.op1.next;
            var op2b = j.op2.prev;
            j.op1.next = j.op2;
            j.op2.prev = j.op1;
            op1b.prev = op2b;
            op2b.next = op1b;

            if (or1 == or2) {
                or2 = newOutRec();
                or2.pts = op1b;
                fixOutRecPts(or2);

                if (or1.pts.outrec == or2) {
                    or1.pts = j.op1;
                    or1.pts.outrec = or1;
                }

                if (_using_polytree) {
                    if (path1InsidePath2(or1.pts, or2.pts)) {
                        var tmp = or2.pts;
                        or2.pts = or1.pts;
                        or1.pts = tmp;
                        fixOutRecPts(or1);
                        fixOutRecPts(or2);
                        or2.owner = or1;
                    } else if (path1InsidePath2(or2.pts, or1.pts))
                        or2.owner = or1;
                    else
                        or2.owner = or1.owner;

                    if (or1.splits == null) or1.splits = new Array<Int>();
                    or1.splits.push(or2.idx);
                } else
                    or2.owner = or1;
            } else {
                or2.pts = null;
                if (_using_polytree) {
                    setOwner(or2, or1);
                    moveSplits(or2, or1);
                } else
                    or2.owner = or1;
            }
        }
    }

    private function cleanCollinear(outrec:Null<OutRec>):Void {
        outrec = getRealOutRec(outrec);

        if (outrec == null || outrec.isOpen) return;

        if (!isValidClosedPath(outrec.pts)) {
            outrec.pts = null;
            return;
        }

        var startOp = outrec.pts;
        var op2 = startOp;
        while (true) {
            if ((InternalClipper.isCollinear(op2.prev.pt, op2.pt, op2.next.pt)) &&
                ((op2.pt == op2.prev.pt) || (op2.pt == op2.next.pt) || !preserveCollinear ||
                (InternalClipper.dotProduct(op2.prev.pt, op2.pt, op2.next.pt) < 0))) {
                if (op2 == outrec.pts)
                    outrec.pts = op2.prev;
                op2 = disposeOutPt(op2);
                if (!isValidClosedPath(op2)) {
                    outrec.pts = null;
                    return;
                }
                startOp = op2;
                continue;
            }
            op2 = op2.next;
            if (op2 == startOp) break;
        }
        fixSelfIntersects(outrec);
    }

    private function doSplitOp(outrec:OutRec, splitOp:OutPt):Void {
        var prevOp = splitOp.prev;
        var nextNextOp = splitOp.next.next;
        outrec.pts = prevOp;

        var ipResult = InternalClipper.getLineIntersectPt64(
            prevOp.pt, splitOp.pt, splitOp.next.pt, nextNextOp.pt);
        var ip = ipResult.ip;

        var area1 = areaOutPt(prevOp);
        var absArea1 = Math.abs(area1);

        if (absArea1 < 2) {
            outrec.pts = null;
            return;
        }

        var area2 = areaTriangle(ip, splitOp.pt, splitOp.next.pt);
        var absArea2 = Math.abs(area2);

        if (ip == prevOp.pt || ip == nextNextOp.pt) {
            nextNextOp.prev = prevOp;
            prevOp.next = nextNextOp;
        } else {
            var newOp2 = new OutPt(ip, outrec);
            newOp2.prev = prevOp;
            newOp2.next = nextNextOp;
            nextNextOp.prev = newOp2;
            prevOp.next = newOp2;
        }

        if (!(absArea2 > 1) ||
            (!(absArea2 > absArea1) &&
             ((area2 > 0) != (area1 > 0)))) return;
        var newOutRec = newOutRec();
        newOutRec.owner = outrec.owner;
        splitOp.outrec = newOutRec;
        splitOp.next.outrec = newOutRec;

        var newOp = new OutPt(ip, newOutRec);
        newOp.prev = splitOp.next;
        newOp.next = splitOp;
        newOutRec.pts = newOp;
        splitOp.prev = newOp;
        splitOp.next.next = newOp;

        if (!_using_polytree) return;
        if (path1InsidePath2(prevOp, newOp)) {
            if (newOutRec.splits == null) newOutRec.splits = new Array<Int>();
            newOutRec.splits.push(outrec.idx);
        } else {
            if (outrec.splits == null) outrec.splits = new Array<Int>();
            outrec.splits.push(newOutRec.idx);
        }
    }

    private function fixSelfIntersects(outrec:OutRec):Void {
        var op2 = outrec.pts;
        if (op2.prev == op2.next.next)
            return;
        while (true) {
            if (InternalClipper.segsIntersect(op2.prev.pt,
                    op2.pt, op2.next.pt, op2.next.next.pt)) {
                if (InternalClipper.segsIntersect(op2.prev.pt,
                        op2.pt, op2.next.next.pt, op2.next.next.next.pt)) {
                    op2 = duplicateOp(op2, false);
                    op2.pt = op2.next.next.next.pt;
                    op2 = op2.next;
                } else {
                    if (op2 == outrec.pts || op2.next == outrec.pts)
                        outrec.pts = outrec.pts.prev;
                    doSplitOp(outrec, op2);
                    if (outrec.pts == null) return;
                    op2 = outrec.pts;
                    if (op2.prev == op2.next.next) break;
                    continue;
                }
            }

            op2 = op2.next;
            if (op2 == outrec.pts) break;
        }
    }

    private function buildPath(op:Null<OutPt>, reverse:Bool, isOpen:Bool, path:Path64):Bool {
        if (op == null || op.next == op || (!isOpen && op.next == op.prev)) return false;
        path.resize(0);

        var lastPt:Point64;
        var op2:OutPt;
        if (reverse) {
            lastPt = op.pt;
            op2 = op.prev;
        } else {
            op = op.next;
            lastPt = op.pt;
            op2 = op.next;
        }
        path.push(lastPt);

        while (op2 != op) {
            if (op2.pt != lastPt) {
                lastPt = op2.pt;
                path.push(lastPt);
            }
            if (reverse)
                op2 = op2.prev;
            else
                op2 = op2.next;
        }

        return path.length != 3 || isOpen || !isVerySmallTriangle(op2);
    }

    private function buildPaths(solutionClosed:Paths64, solutionOpen:Paths64):Bool {
        solutionClosed.resize(0);
        solutionOpen.resize(0);

        var i = 0;
        while (i < _outrecList.length) {
            var outrec = _outrecList[i++];
            if (outrec.pts == null) continue;

            var path = new Path64();
            if (outrec.isOpen) {
                if (buildPath(outrec.pts, reverseSolution, true, path))
                    solutionOpen.push(path);
            } else {
                cleanCollinear(outrec);
                if (buildPath(outrec.pts, reverseSolution, false, path))
                    solutionClosed.push(path);
            }
        }
        return true;
    }

    private function checkBounds(outrec:OutRec):Bool {
        if (outrec.pts == null) return false;
        if (!outrec.bounds.isEmpty()) return true;
        cleanCollinear(outrec);
        if (outrec.pts == null ||
            !buildPath(outrec.pts, reverseSolution, false, outrec.path))
            return false;
        outrec.bounds = InternalClipper.getBounds(outrec.path);
        return true;
    }

    private function checkSplitOwner(outrec:OutRec, splits:Array<Int>):Bool {
        var i = 0;
        while (i < splits.length) {
            var split = _outrecList[splits[i]];
            if (split.pts == null && split.splits != null &&
                checkSplitOwner(outrec, split.splits)) return true;
            split = getRealOutRec(split);
            if (split == null || split == outrec || split.recursiveSplit == outrec) {
                i++;
                continue;
            }
            split.recursiveSplit = outrec;

            if (split.splits != null && checkSplitOwner(outrec, split.splits)) return true;

            if (!checkBounds(split) ||
                !split.bounds.containsRect(outrec.bounds) ||
                !path1InsidePath2(outrec.pts, split.pts)) {
                i++;
                continue;
            }

            if (!isValidOwner(outrec, split))
                split.owner = outrec.owner;

            outrec.owner = split;
            return true;
        }
        return false;
    }

    private function recursiveCheckOwners(outrec:OutRec, polypath:PolyPathBase):Void {
        if (outrec.polypath != null || outrec.bounds.isEmpty()) return;

        while (outrec.owner != null) {
            if (outrec.owner.splits != null &&
                checkSplitOwner(outrec, outrec.owner.splits)) break;
            if (outrec.owner.pts != null && checkBounds(outrec.owner) &&
                path1InsidePath2(outrec.pts, outrec.owner.pts)) break;
            outrec.owner = outrec.owner.owner;
        }

        if (outrec.owner != null) {
            if (outrec.owner.polypath == null)
                recursiveCheckOwners(outrec.owner, polypath);
            outrec.polypath = outrec.owner.polypath.addChild(outrec.path);
        } else
            outrec.polypath = polypath.addChild(outrec.path);
    }

    private function buildTree(polytree:PolyPathBase, openPaths:Paths64):Void {
        polytree.clear();
        openPaths.resize(0);

        var i = 0;
        while (i < _outrecList.length) {
            var outrec = _outrecList[i++];
            if (outrec.pts == null) continue;

            if (outrec.isOpen) {
                var open_path = new Path64();
                if (buildPath(outrec.pts, reverseSolution, true, open_path))
                    openPaths.push(open_path);
                continue;
            }
            if (checkBounds(outrec))
                recursiveCheckOwners(outrec, polytree);
        }
    }

    public function getBounds():Rect64 {
        var bounds = Rect64.createInvalid();
        for (t in _vertexList) {
            var v = t;
            do {
                if (v.pt.x < bounds.left) bounds.left = v.pt.x;
                if (v.pt.x > bounds.right) bounds.right = v.pt.x;
                if (v.pt.y < bounds.top) bounds.top = v.pt.y;
                if (v.pt.y > bounds.bottom) bounds.bottom = v.pt.y;
                v = v.next;
            } while (v != t);
        }
        return bounds.isEmpty() ? new Rect64(0, 0, 0, 0) : bounds;
    }
}

// ============================================================================
// Clipper64 - Integer-based polygon clipping
// ============================================================================

class Clipper64 extends ClipperBase {
    public function new() {
        super();
    }

    public function addSubjectPaths(paths:Paths64):Void {
        addPaths(paths, PathType.Subject);
    }

    public function addOpenSubjectPaths(paths:Paths64):Void {
        addPaths(paths, PathType.Subject, true);
    }

    public function addClipPaths(paths:Paths64):Void {
        addPaths(paths, PathType.Clip);
    }

    public function execute(clipType:ClipType, fillRule:FillRule, solutionClosed:Paths64, ?solutionOpen:Paths64):Bool {
        solutionClosed.resize(0);
        if (solutionOpen != null) solutionOpen.resize(0);

        try {
            executeInternal(clipType, fillRule);
            buildPaths(solutionClosed, solutionOpen != null ? solutionOpen : new Paths64());
        } catch (e:Dynamic) {
            _succeeded = false;
        }

        clearSolutionOnly();
        return _succeeded;
    }

    public function executeTree(clipType:ClipType, fillRule:FillRule, polytree:PolyTree64, ?openPaths:Paths64):Bool {
        polytree.clear();
        if (openPaths != null) openPaths.resize(0);
        _using_polytree = true;

        try {
            executeInternal(clipType, fillRule);
            buildTree(polytree, openPaths != null ? openPaths : new Paths64());
        } catch (e:Dynamic) {
            _succeeded = false;
        }

        clearSolutionOnly();
        return _succeeded;
    }

    #if clipper_usingz
    public var zCallback(get, set):Null<(Point64, Point64, Point64, Point64, Point64) -> Void>;
    function get_zCallback() return _zCallback;
    function set_zCallback(value) return _zCallback = value;
    #end
}

// ============================================================================
// ClipperD - Floating-point polygon clipping with decimal precision
// ============================================================================

class ClipperD extends ClipperBase {
    private static inline var precision_range_error = "Error: Precision is out of range.";

    private var _scale:Float;
    private var _invScale:Float;

    public function new(roundingDecimalPrecision:Int = 2) {
        super();
        if (roundingDecimalPrecision < -8 || roundingDecimalPrecision > 8)
            throw precision_range_error;
        _scale = Math.pow(10, roundingDecimalPrecision);
        _invScale = 1 / _scale;
    }

    public function addPathD(path:PathD, polytype:PathType, isOpen:Bool = false):Void {
        addPath(scalePathTo64(path), polytype, isOpen);
    }

    public function addPathsD(paths:PathsD, polytype:PathType, isOpen:Bool = false):Void {
        addPaths(scalePathsTo64(paths), polytype, isOpen);
    }

    public function addSubjectD(path:PathD):Void {
        addPathD(path, PathType.Subject);
    }

    public function addOpenSubjectD(path:PathD):Void {
        addPathD(path, PathType.Subject, true);
    }

    public function addClipD(path:PathD):Void {
        addPathD(path, PathType.Clip);
    }

    public function addSubjectPathsD(paths:PathsD):Void {
        addPathsD(paths, PathType.Subject);
    }

    public function addOpenSubjectPathsD(paths:PathsD):Void {
        addPathsD(paths, PathType.Subject, true);
    }

    public function addClipPathsD(paths:PathsD):Void {
        addPathsD(paths, PathType.Clip);
    }

    public function executeD(clipType:ClipType, fillRule:FillRule, solutionClosed:PathsD, ?solutionOpen:PathsD):Bool {
        var solClosed64 = new Paths64();
        var solOpen64 = new Paths64();

        solutionClosed.resize(0);
        if (solutionOpen != null) solutionOpen.resize(0);

        var success = true;
        try {
            executeInternal(clipType, fillRule);
            buildPaths(solClosed64, solOpen64);
        } catch (e:Dynamic) {
            success = false;
        }

        clearSolutionOnly();
        if (!success) return false;

        for (path in solClosed64)
            solutionClosed.push(scalePathToD(path));
        if (solutionOpen != null) {
            for (path in solOpen64)
                solutionOpen.push(scalePathToD(path));
        }

        return true;
    }

    public function executeTreeD(clipType:ClipType, fillRule:FillRule, polytree:PolyTreeD, ?openPaths:PathsD):Bool {
        polytree.clear();
        if (openPaths != null) openPaths.resize(0);
        polytree.scale = _scale;
        _using_polytree = true;

        var oPaths = new Paths64();
        var success = true;
        try {
            executeInternal(clipType, fillRule);
            buildTree(polytree, oPaths);
        } catch (e:Dynamic) {
            success = false;
        }

        clearSolutionOnly();
        if (!success) return false;

        if (openPaths != null && oPaths.length > 0) {
            for (path in oPaths)
                openPaths.push(scalePathToD(path));
        }

        return true;
    }

    private function scalePathTo64(path:PathD):Path64 {
        var result = new Path64();
        for (pt in path) {
            result.push(new Point64(
                InternalClipper.roundToInt64(pt.x * _scale),
                InternalClipper.roundToInt64(pt.y * _scale)
            ));
        }
        return result;
    }

    private function scalePathsTo64(paths:PathsD):Paths64 {
        var result = new Paths64();
        for (path in paths)
            result.push(scalePathTo64(path));
        return result;
    }

    private function scalePathToD(path:Path64):PathD {
        var result = new PathD();
        for (pt in path) {
            result.push(new PointD(
                InternalClipper.toFloat(pt.x) * _invScale,
                InternalClipper.toFloat(pt.y) * _invScale
            ));
        }
        return result;
    }
}

// ============================================================================
// PolyPathBase - Abstract base class for polygon tree nodes
// ============================================================================

class PolyPathBase {
    public var _parent:Null<PolyPathBase>;
    public var _childs:Array<PolyPathBase>;

    public function new(?parent:PolyPathBase) {
        _parent = parent;
        _childs = new Array<PolyPathBase>();
    }

    public var isHole(get, never):Bool;
    function get_isHole():Bool {
        var lvl = level;
        return lvl != 0 && (lvl & 1) == 0;
    }

    public var level(get, never):Int;
    function get_level():Int {
        var result = 0;
        var pp = _parent;
        while (pp != null) {
            result++;
            pp = pp._parent;
        }
        return result;
    }

    public var count(get, never):Int;
    function get_count():Int {
        return _childs.length;
    }

    public function addChild(p:Path64):PolyPathBase {
        return null;
    }

    public function clear():Void {
        _childs.resize(0);
    }

    public function child(index:Int):PolyPathBase {
        if (index < 0 || index >= _childs.length)
            throw "Invalid index";
        return _childs[index];
    }

    public function iterator():Iterator<PolyPathBase> {
        return _childs.iterator();
    }
}

// ============================================================================
// PolyPath64 - Integer-based polygon node
// ============================================================================

class PolyPath64 extends PolyPathBase {
    public var polygon:Null<Path64>;

    public function new(?parent:PolyPathBase) {
        super(parent);
        polygon = null;
    }

    override public function addChild(p:Path64):PolyPathBase {
        var newChild = new PolyPath64(this);
        newChild.polygon = p;
        _childs.push(newChild);
        return newChild;
    }

    public function getChild(index:Int):PolyPath64 {
        if (index < 0 || index >= _childs.length)
            throw "Invalid index";
        return cast(_childs[index], PolyPath64);
    }

    public function area():Float {
        var result = if (polygon == null) 0.0 else ClipperLib.area(polygon);
        for (child in _childs) {
            result += cast(child, PolyPath64).area();
        }
        return result;
    }
}

// ============================================================================
// PolyPathD - Floating-point polygon node
// ============================================================================

class PolyPathD extends PolyPathBase {
    public var scale:Float;
    public var polygon:Null<PathD>;

    public function new(?parent:PolyPathBase) {
        super(parent);
        scale = 1.0;
        polygon = null;
    }

    override public function addChild(p:Path64):PolyPathBase {
        var newChild = new PolyPathD(this);
        newChild.scale = scale;
        newChild.polygon = scalePathD(p);
        _childs.push(newChild);
        return newChild;
    }

    public function addChildD(p:PathD):PolyPathBase {
        var newChild = new PolyPathD(this);
        newChild.scale = scale;
        newChild.polygon = p;
        _childs.push(newChild);
        return newChild;
    }

    public function getChild(index:Int):PolyPathD {
        if (index < 0 || index >= _childs.length)
            throw "Invalid index";
        return cast(_childs[index], PolyPathD);
    }

    public function area():Float {
        var result = if (polygon == null) 0.0 else ClipperLib.areaD(polygon);
        for (child in _childs) {
            result += cast(child, PolyPathD).area();
        }
        return result;
    }

    private function scalePathD(path:Path64):PathD {
        var result = new PathD();
        var invScale = 1.0 / scale;
        for (pt in path) {
            result.push(new PointD(
                InternalClipper.toFloat(pt.x) * invScale,
                InternalClipper.toFloat(pt.y) * invScale
            ));
        }
        return result;
    }
}

// ============================================================================
// PolyTree64 - Root container for PolyPath64 hierarchy
// ============================================================================

class PolyTree64 extends PolyPath64 {
    public function new() {
        super(null);
    }
}

// ============================================================================
// PolyTreeD - Root container for PolyPathD hierarchy
// ============================================================================

class PolyTreeD extends PolyPathD {
    public function new() {
        super(null);
    }
}

// ============================================================================
// ClipperLibException
// ============================================================================

class ClipperLibException {
    public var message:String;

    public function new(description:String) {
        message = description;
    }

    public function toString():String {
        return 'ClipperLibException: $message';
    }
}

// ============================================================================
// ClipperLib - Placeholder for static utility functions
// ============================================================================

class ClipperLib {
    public static function area(path:Path64):Float {
        if (path.length < 3) return 0.0;
        var a = 0.0;
        var j = path.length - 1;
        for (i in 0...path.length) {
            a += (InternalClipper.toFloat(path[j].x) + InternalClipper.toFloat(path[i].x)) * (InternalClipper.toFloat(path[j].y) - InternalClipper.toFloat(path[i].y));
            j = i;
        }
        return a * 0.5;
    }

    public static function areaD(path:PathD):Float {
        if (path.length < 3) return 0.0;
        var a = 0.0;
        var j = path.length - 1;
        for (i in 0...path.length) {
            a += (path[j].x + path[i].x) * (path[j].y - path[i].y);
            j = i;
        }
        return a * 0.5;
    }
}
