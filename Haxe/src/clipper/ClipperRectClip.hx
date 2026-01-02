package clipper;


import clipper.ClipperCore;

// ============================================================================
// Location enum for RectClip
// ============================================================================

private enum abstract Location(Int) to Int {
    var Left = 0;
    var Top = 1;
    var Right = 2;
    var Bottom = 3;
    var Inside = 4;
}

// ============================================================================
// OutPt2 - Output point for rectangle clipping
// ============================================================================

class OutPt2 {
    public var next:Null<OutPt2>;
    public var prev:Null<OutPt2>;
    public var pt:Point64;
    public var ownerIdx:Int;
    public var edge:Null<Array<Null<OutPt2>>>;

    public function new(pt:Point64) {
        this.pt = pt;
        this.next = null;
        this.prev = null;
        this.ownerIdx = 0;
        this.edge = null;
    }
}

// ============================================================================
// RectClip64 - Fast rectangular clipping for polygons
// ============================================================================

class RectClip64 {
    private var rect_:Rect64;
    private var mp_:Point64;
    private var rectPath_:Path64;
    private var pathBounds_:Rect64;
    private var results_:Array<Null<OutPt2>>;
    private var edges_:Array<Array<Null<OutPt2>>>;
    private var currIdx_:Int;

    public function new(rect:Rect64) {
        currIdx_ = -1;
        rect_ = rect;
        mp_ = rect.midPoint();
        rectPath_ = rect_.asPath();
        results_ = [];
        pathBounds_ = new Rect64();
        edges_ = [];
        for (i in 0...8) {
            edges_.push([]);
        }
    }

    private function add(pt:Point64, startingNewPath:Bool = false):OutPt2 {
        var currIdx = results_.length;
        var result:OutPt2;
        if (currIdx == 0 || startingNewPath) {
            result = new OutPt2(pt);
            results_.push(result);
            result.ownerIdx = currIdx;
            result.prev = result;
            result.next = result;
        } else {
            currIdx--;
            var prevOp = results_[currIdx];
            if (prevOp != null && prevOp.pt == pt) return prevOp;
            result = new OutPt2(pt);
            result.ownerIdx = currIdx;
            result.next = prevOp.next;
            prevOp.next.prev = result;
            prevOp.next = result;
            result.prev = prevOp;
            results_[currIdx] = result;
        }
        return result;
    }

    private static function path1ContainsPath2(path1:Path64, path2:Path64):Bool {
        var ioCount = 0;
        for (pt in path2) {
            var pip = InternalClipper.pointInPolygon(pt, path1);
            switch (pip) {
                case PointInPolygonResult.IsInside:
                    ioCount--;
                case PointInPolygonResult.IsOutside:
                    ioCount++;
                default:
            }
            if (ioCount > 1 || ioCount < -1) break;
        }
        return ioCount <= 0;
    }

    private static inline function isClockwise(prev:Location, curr:Location,
            prevPt:Point64, currPt:Point64, rectMidPoint:Point64):Bool {
        if (areOpposites(prev, curr))
            return InternalClipper.crossProductSign(prevPt, rectMidPoint, currPt) < 0;
        return headingClockwise(prev, curr);
    }

    private static inline function areOpposites(prev:Location, curr:Location):Bool {
        var diff = (prev : Int) - (curr : Int);
        return diff == 2 || diff == -2;
    }

    private static inline function headingClockwise(prev:Location, curr:Location):Bool {
        return ((prev : Int) + 1) % 4 == (curr : Int);
    }

    private static inline function getAdjacentLocation(loc:Location, isClockwiseDir:Bool):Location {
        var delta = if (isClockwiseDir) 1 else 3;
        return cast (((loc : Int) + delta) % 4);
    }

    private static function unlinkOp(op:OutPt2):Null<OutPt2> {
        if (op.next == op) return null;
        op.prev.next = op.next;
        op.next.prev = op.prev;
        return op.next;
    }

    private static function unlinkOpBack(op:OutPt2):Null<OutPt2> {
        if (op.next == op) return null;
        op.prev.next = op.next;
        op.next.prev = op.prev;
        return op.prev;
    }

    private static function getEdgesForPt(pt:Point64, rec:Rect64):Int {
        var result = 0;
        if (pt.x == rec.left) result = 1
        else if (pt.x == rec.right) result = 4;
        if (pt.y == rec.top) result += 2
        else if (pt.y == rec.bottom) result += 8;
        return result;
    }

    private static function isHeadingClockwise(pt1:Point64, pt2:Point64, edgeIdx:Int):Bool {
        return switch (edgeIdx) {
            case 0: pt2.y < pt1.y;
            case 1: pt2.x > pt1.x;
            case 2: pt2.y > pt1.y;
            default: pt2.x < pt1.x;
        };
    }

    private static inline function hasHorzOverlap(left1:Point64, right1:Point64,
            left2:Point64, right2:Point64):Bool {
        return (left1.x < right2.x) && (right1.x > left2.x);
    }

    private static inline function hasVertOverlap(top1:Point64, bottom1:Point64,
            top2:Point64, bottom2:Point64):Bool {
        return (top1.y < bottom2.y) && (bottom1.y > top2.y);
    }

    private static function addToEdge(edge:Array<Null<OutPt2>>, op:OutPt2):Void {
        if (op.edge != null) return;
        op.edge = edge;
        edge.push(op);
    }

    private static function uncoupleEdge(op:OutPt2):Void {
        if (op.edge == null) return;
        for (i in 0...op.edge.length) {
            var op2 = op.edge[i];
            if (op2 != op) continue;
            op.edge[i] = null;
            break;
        }
        op.edge = null;
    }

    private static function setNewOwner(op:OutPt2, newIdx:Int):Void {
        op.ownerIdx = newIdx;
        var op2 = op.next;
        while (op2 != op) {
            op2.ownerIdx = newIdx;
            op2 = op2.next;
        }
    }

    private function addCornerByLocs(prev:Location, curr:Location):Void {
        add(if (headingClockwise(prev, curr)) rectPath_[(prev : Int)] else rectPath_[(curr : Int)]);
    }

    private function addCorner(loc:Location, isClockwiseDir:Bool):Location {
        if (isClockwiseDir) {
            add(rectPath_[(loc : Int)]);
            return getAdjacentLocation(loc, true);
        } else {
            var newLoc = getAdjacentLocation(loc, false);
            add(rectPath_[(newLoc : Int)]);
            return newLoc;
        }
    }

    static function getLocation(rec:Rect64, pt:Point64):{loc:Location, isOnRect:Bool} {
        if (pt.x == rec.left && pt.y >= rec.top && pt.y <= rec.bottom) {
            return {loc: Location.Left, isOnRect: true};
        }
        if (pt.x == rec.right && pt.y >= rec.top && pt.y <= rec.bottom) {
            return {loc: Location.Right, isOnRect: true};
        }
        if (pt.y == rec.top && pt.x >= rec.left && pt.x <= rec.right) {
            return {loc: Location.Top, isOnRect: true};
        }
        if (pt.y == rec.bottom && pt.x >= rec.left && pt.x <= rec.right) {
            return {loc: Location.Bottom, isOnRect: true};
        }
        var loc:Location;
        if (pt.x < rec.left) loc = Location.Left
        else if (pt.x > rec.right) loc = Location.Right
        else if (pt.y < rec.top) loc = Location.Top
        else if (pt.y > rec.bottom) loc = Location.Bottom
        else loc = Location.Inside;
        return {loc: loc, isOnRect: false};
    }

    private static inline function isHorizontal(pt1:Point64, pt2:Point64):Bool {
        return pt1.y == pt2.y;
    }

    static function getSegmentIntersection(p1:Point64, p2:Point64, p3:Point64, p4:Point64):{ip:Point64, success:Bool} {
        var res1 = InternalClipper.crossProductSign(p1, p3, p4);
        var res2 = InternalClipper.crossProductSign(p2, p3, p4);
        if (res1 == 0) {
            if (res2 == 0) return {ip: p1, success: false}; // segments are collinear
            if (p1 == p3 || p1 == p4) return {ip: p1, success: true};
            if (isHorizontal(p3, p4)) return {ip: p1, success: (p1.x > p3.x) == (p1.x < p4.x)};
            return {ip: p1, success: (p1.y > p3.y) == (p1.y < p4.y)};
        }
        if (res2 == 0) {
            if (p2 == p3 || p2 == p4) return {ip: p2, success: true};
            if (isHorizontal(p3, p4)) return {ip: p2, success: (p2.x > p3.x) == (p2.x < p4.x)};
            return {ip: p2, success: (p2.y > p3.y) == (p2.y < p4.y)};
        }

        if ((res1 > 0) == (res2 > 0)) {
            return {ip: new Point64(0, 0), success: false};
        }

        var res3 = InternalClipper.crossProductSign(p3, p1, p2);
        var res4 = InternalClipper.crossProductSign(p4, p1, p2);
        if (res3 == 0) {
            if (p3 == p1 || p3 == p2) return {ip: p3, success: true};
            if (isHorizontal(p1, p2)) return {ip: p3, success: (p3.x > p1.x) == (p3.x < p2.x)};
            return {ip: p3, success: (p3.y > p1.y) == (p3.y < p2.y)};
        }
        if (res4 == 0) {
            if (p4 == p1 || p4 == p2) return {ip: p4, success: true};
            if (isHorizontal(p1, p2)) return {ip: p4, success: (p4.x > p1.x) == (p4.x < p2.x)};
            return {ip: p4, success: (p4.y > p1.y) == (p4.y < p2.y)};
        }
        if ((res3 > 0) == (res4 > 0)) {
            return {ip: new Point64(0, 0), success: false};
        }

        // segments must intersect to get here
        var result = InternalClipper.getLineIntersectPt64(p1, p2, p3, p4);
        return {ip: result.ip, success: result.success};
    }

    static function getIntersection(rectPath:Path64, p:Point64, p2:Point64, loc:Location):{ip:Point64, loc:Location, success:Bool} {
        var ip = new Point64(0, 0);
        switch (loc) {
            case Location.Left:
                var result = getSegmentIntersection(p, p2, rectPath[0], rectPath[3]);
                if (result.success) return {ip: result.ip, loc: loc, success: true};
                if (p.y < rectPath[0].y) {
                    result = getSegmentIntersection(p, p2, rectPath[0], rectPath[1]);
                    if (result.success) return {ip: result.ip, loc: Location.Top, success: true};
                }
                result = getSegmentIntersection(p, p2, rectPath[2], rectPath[3]);
                if (!result.success) return {ip: ip, loc: loc, success: false};
                return {ip: result.ip, loc: Location.Bottom, success: true};

            case Location.Right:
                var result = getSegmentIntersection(p, p2, rectPath[1], rectPath[2]);
                if (result.success) return {ip: result.ip, loc: loc, success: true};
                if (p.y < rectPath[0].y) {
                    result = getSegmentIntersection(p, p2, rectPath[0], rectPath[1]);
                    if (result.success) return {ip: result.ip, loc: Location.Top, success: true};
                }
                result = getSegmentIntersection(p, p2, rectPath[2], rectPath[3]);
                if (!result.success) return {ip: ip, loc: loc, success: false};
                return {ip: result.ip, loc: Location.Bottom, success: true};

            case Location.Top:
                var result = getSegmentIntersection(p, p2, rectPath[0], rectPath[1]);
                if (result.success) return {ip: result.ip, loc: loc, success: true};
                if (p.x < rectPath[0].x) {
                    result = getSegmentIntersection(p, p2, rectPath[0], rectPath[3]);
                    if (result.success) return {ip: result.ip, loc: Location.Left, success: true};
                }
                if (p.x > rectPath[1].x) {
                    result = getSegmentIntersection(p, p2, rectPath[1], rectPath[2]);
                    if (result.success) return {ip: result.ip, loc: Location.Right, success: true};
                }
                return {ip: ip, loc: loc, success: false};

            case Location.Bottom:
                var result = getSegmentIntersection(p, p2, rectPath[2], rectPath[3]);
                if (result.success) return {ip: result.ip, loc: loc, success: true};
                if (p.x < rectPath[3].x) {
                    result = getSegmentIntersection(p, p2, rectPath[0], rectPath[3]);
                    if (result.success) return {ip: result.ip, loc: Location.Left, success: true};
                }
                if (p.x > rectPath[2].x) {
                    result = getSegmentIntersection(p, p2, rectPath[1], rectPath[2]);
                    if (result.success) return {ip: result.ip, loc: Location.Right, success: true};
                }
                return {ip: ip, loc: loc, success: false};

            default: // Inside
                var result = getSegmentIntersection(p, p2, rectPath[0], rectPath[3]);
                if (result.success) return {ip: result.ip, loc: Location.Left, success: true};
                result = getSegmentIntersection(p, p2, rectPath[0], rectPath[1]);
                if (result.success) return {ip: result.ip, loc: Location.Top, success: true};
                result = getSegmentIntersection(p, p2, rectPath[1], rectPath[2]);
                if (result.success) return {ip: result.ip, loc: Location.Right, success: true};
                result = getSegmentIntersection(p, p2, rectPath[2], rectPath[3]);
                if (!result.success) return {ip: ip, loc: loc, success: false};
                return {ip: result.ip, loc: Location.Bottom, success: true};
        }
    }

    private function getNextLocation(path:Path64, loc:Location, i:Int, highI:Int):{loc:Location, i:Int} {
        switch (loc) {
            case Location.Left:
                while (i <= highI && path[i].x <= rect_.left) i++;
                if (i > highI) return {loc: loc, i: i};
                if (path[i].x >= rect_.right) loc = Location.Right
                else if (path[i].y <= rect_.top) loc = Location.Top
                else if (path[i].y >= rect_.bottom) loc = Location.Bottom
                else loc = Location.Inside;

            case Location.Top:
                while (i <= highI && path[i].y <= rect_.top) i++;
                if (i > highI) return {loc: loc, i: i};
                if (path[i].y >= rect_.bottom) loc = Location.Bottom
                else if (path[i].x <= rect_.left) loc = Location.Left
                else if (path[i].x >= rect_.right) loc = Location.Right
                else loc = Location.Inside;

            case Location.Right:
                while (i <= highI && path[i].x >= rect_.right) i++;
                if (i > highI) return {loc: loc, i: i};
                if (path[i].x <= rect_.left) loc = Location.Left
                else if (path[i].y <= rect_.top) loc = Location.Top
                else if (path[i].y >= rect_.bottom) loc = Location.Bottom
                else loc = Location.Inside;

            case Location.Bottom:
                while (i <= highI && path[i].y >= rect_.bottom) i++;
                if (i > highI) return {loc: loc, i: i};
                if (path[i].y <= rect_.top) loc = Location.Top
                else if (path[i].x <= rect_.left) loc = Location.Left
                else if (path[i].x >= rect_.right) loc = Location.Right
                else loc = Location.Inside;

            case Location.Inside:
                while (i <= highI) {
                    if (path[i].x < rect_.left) { loc = Location.Left; break; }
                    else if (path[i].x > rect_.right) { loc = Location.Right; break; }
                    else if (path[i].y > rect_.bottom) { loc = Location.Bottom; break; }
                    else if (path[i].y < rect_.top) { loc = Location.Top; break; }
                    else {
                        add(path[i]);
                        i++;
                    }
                }
        }
        return {loc: loc, i: i};
    }

    private static function startLocsAreClockwise(startLocs:Array<Location>):Bool {
        var result = 0;
        for (i in 1...startLocs.length) {
            var d = (startLocs[i] : Int) - (startLocs[i - 1] : Int);
            switch (d) {
                case -1: result -= 1;
                case 1: result += 1;
                case -3: result += 1;
                case 3: result -= 1;
                default:
            }
        }
        return result > 0;
    }

    private function executeInternal(path:Path64):Void {
        if (path.length < 3 || rect_.isEmpty()) return;
        var startLocs = new Array<Location>();

        var firstCross = Location.Inside;
        var crossingLoc = firstCross;
        var prev = firstCross;

        var highI = path.length - 1;
        var locResult = getLocation(rect_, path[highI]);
        var loc = locResult.loc;
        var i:Int;

        if (locResult.isOnRect) {
            i = highI - 1;
            while (i >= 0) {
                var prevResult = getLocation(rect_, path[i]);
                if (!prevResult.isOnRect) {
                    prev = prevResult.loc;
                    break;
                }
                i--;
            }
            if (i < 0) {
                for (pt in path) add(pt);
                return;
            }
            if (prev == Location.Inside) loc = Location.Inside;
        }
        var startingLoc = loc;

        i = 0;
        while (i <= highI) {
            prev = loc;
            var prevCrossLoc = crossingLoc;
            var nextResult = getNextLocation(path, loc, i, highI);
            loc = nextResult.loc;
            i = nextResult.i;
            if (i > highI) break;

            var prevPt = if (i == 0) path[highI] else path[i - 1];
            crossingLoc = loc;
            var intResult = getIntersection(rectPath_, path[i], prevPt, crossingLoc);

            if (!intResult.success) {
                // ie remaining outside
                if (prevCrossLoc == Location.Inside) {
                    var isClockw = isClockwise(prev, loc, prevPt, path[i], mp_);
                    while (prev != loc) {
                        startLocs.push(prev);
                        prev = getAdjacentLocation(prev, isClockw);
                    }
                    crossingLoc = prevCrossLoc; // still not crossed
                } else if (prev != Location.Inside && prev != loc) {
                    var isClockw = isClockwise(prev, loc, prevPt, path[i], mp_);
                    while (prev != loc) {
                        prev = addCorner(prev, isClockw);
                    }
                }
                i++;
                continue;
            }

            crossingLoc = intResult.loc;
            var ip = intResult.ip;

            // we must be crossing the rect boundary to get here
            if (loc == Location.Inside) { // path must be entering rect
                if (firstCross == Location.Inside) {
                    firstCross = crossingLoc;
                    startLocs.push(prev);
                } else if (prev != crossingLoc) {
                    var isClockw = isClockwise(prev, crossingLoc, prevPt, path[i], mp_);
                    while (prev != crossingLoc) {
                        prev = addCorner(prev, isClockw);
                    }
                }
            } else if (prev != Location.Inside) {
                // passing right through rect
                var tempLoc = prev;
                var ip2Result = getIntersection(rectPath_, prevPt, path[i], tempLoc);
                if (prevCrossLoc != Location.Inside && prevCrossLoc != tempLoc)
                    addCornerByLocs(prevCrossLoc, tempLoc);

                if (firstCross == Location.Inside) {
                    firstCross = tempLoc;
                    startLocs.push(prev);
                }

                loc = crossingLoc;
                add(ip2Result.ip);
                if (ip == ip2Result.ip) {
                    var ptLocResult = getLocation(rect_, path[i]);
                    loc = ptLocResult.loc;
                    addCornerByLocs(crossingLoc, loc);
                    crossingLoc = loc;
                    continue;
                }
            } else { // path must be exiting rect
                loc = crossingLoc;
                if (firstCross == Location.Inside)
                    firstCross = crossingLoc;
            }

            add(ip);
        }

        if (firstCross == Location.Inside) {
            // path never intersects
            if (startingLoc == Location.Inside) return;
            if (!pathBounds_.containsRect(rect_) || !path1ContainsPath2(path, rectPath_)) return;
            var startLocsClockwise = startLocsAreClockwise(startLocs);
            for (j in 0...4) {
                var k = if (startLocsClockwise) j else 3 - j;
                add(rectPath_[k]);
                addToEdge(edges_[k * 2], results_[0]);
            }
        } else if (loc != Location.Inside && (loc != firstCross || startLocs.length > 2)) {
            if (startLocs.length > 0) {
                prev = loc;
                for (loc2 in startLocs) {
                    if (prev == loc2) continue;
                    prev = addCorner(prev, headingClockwise(prev, loc2));
                }
                loc = prev;
            }
            if (loc != firstCross)
                addCorner(loc, headingClockwise(loc, firstCross));
        }
    }

    public function execute(paths:Paths64):Paths64 {
        var result = new Paths64();
        if (rect_.isEmpty()) return result;
        for (path in paths) {
            if (path.length < 3) continue;
            pathBounds_ = getBounds(path);
            if (!rect_.intersects(pathBounds_)) continue;
            if (rect_.containsRect(pathBounds_)) {
                result.push(path);
                continue;
            }
            executeInternal(path);
            checkEdges();
            for (i in 0...4) {
                tidyEdgePair(i, edges_[i * 2], edges_[i * 2 + 1]);
            }

            for (op in results_) {
                var tmp = getPath(op);
                if (tmp.length > 0) result.push(tmp);
            }

            results_ = [];
            for (i in 0...8) edges_[i] = [];
        }
        return result;
    }

    private static function getBounds(path:Path64):Rect64 {
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

    private function checkEdges():Void {
        for (i in 0...results_.length) {
            var op = results_[i];
            var op2 = op;
            if (op == null) continue;
            do {
                if (InternalClipper.isCollinear(op2.prev.pt, op2.pt, op2.next.pt)) {
                    if (op2 == op) {
                        op2 = unlinkOpBack(op2);
                        if (op2 == null) break;
                        op = op2.prev;
                    } else {
                        op2 = unlinkOpBack(op2);
                        if (op2 == null) break;
                    }
                } else {
                    op2 = op2.next;
                }
            } while (op2 != op);

            if (op2 == null) {
                results_[i] = null;
                continue;
            }
            results_[i] = op2;

            var edgeSet1 = getEdgesForPt(op.prev.pt, rect_);
            op2 = op;
            do {
                var edgeSet2 = getEdgesForPt(op2.pt, rect_);
                if (edgeSet2 != 0 && op2.edge == null) {
                    var combinedSet = edgeSet1 & edgeSet2;
                    for (j in 0...4) {
                        if ((combinedSet & (1 << j)) == 0) continue;
                        if (isHeadingClockwise(op2.prev.pt, op2.pt, j))
                            addToEdge(edges_[j * 2], op2);
                        else
                            addToEdge(edges_[j * 2 + 1], op2);
                    }
                }
                edgeSet1 = edgeSet2;
                op2 = op2.next;
            } while (op2 != op);
        }
    }

    private function tidyEdgePair(idx:Int, cw:Array<Null<OutPt2>>, ccw:Array<Null<OutPt2>>):Void {
        if (ccw.length == 0) return;
        var isHorz = (idx == 1) || (idx == 3);
        var cwIsTowardLarger = (idx == 1) || (idx == 2);
        var i = 0;
        var j = 0;

        while (i < cw.length) {
            var p1 = cw[i];
            if (p1 == null || p1.next == p1.prev) {
                cw[i++] = null;
                j = 0;
                continue;
            }

            var jLim = ccw.length;
            while (j < jLim && (ccw[j] == null || ccw[j].next == ccw[j].prev)) j++;

            if (j == jLim) {
                i++;
                j = 0;
                continue;
            }

            var p2:Null<OutPt2>;
            var p1a:Null<OutPt2>;
            var p2a:Null<OutPt2>;
            if (cwIsTowardLarger) {
                p1 = cw[i].prev;
                p1a = cw[i];
                p2 = ccw[j];
                p2a = ccw[j].prev;
            } else {
                p1 = cw[i];
                p1a = cw[i].prev;
                p2 = ccw[j].prev;
                p2a = ccw[j];
            }

            if ((isHorz && !hasHorzOverlap(p1.pt, p1a.pt, p2.pt, p2a.pt)) ||
                (!isHorz && !hasVertOverlap(p1.pt, p1a.pt, p2.pt, p2a.pt))) {
                j++;
                continue;
            }

            var isRejoining = cw[i].ownerIdx != ccw[j].ownerIdx;

            if (isRejoining) {
                results_[p2.ownerIdx] = null;
                setNewOwner(p2, p1.ownerIdx);
            }

            if (cwIsTowardLarger) {
                p1.next = p2;
                p2.prev = p1;
                p1a.prev = p2a;
                p2a.next = p1a;
            } else {
                p1.prev = p2;
                p2.next = p1;
                p1a.next = p2a;
                p2a.prev = p1a;
            }

            if (!isRejoining) {
                var new_idx = results_.length;
                results_.push(p1a);
                setNewOwner(p1a, new_idx);
            }

            var op:OutPt2;
            var op2:OutPt2;
            if (cwIsTowardLarger) {
                op = p2;
                op2 = p1a;
            } else {
                op = p1;
                op2 = p2a;
            }
            results_[op.ownerIdx] = op;
            results_[op2.ownerIdx] = op2;

            var opIsLarger:Bool;
            var op2IsLarger:Bool;
            if (isHorz) {
                opIsLarger = op.pt.x > op.prev.pt.x;
                op2IsLarger = op2.pt.x > op2.prev.pt.x;
            } else {
                opIsLarger = op.pt.y > op.prev.pt.y;
                op2IsLarger = op2.pt.y > op2.prev.pt.y;
            }

            if ((op.next == op.prev) || (op.pt == op.prev.pt)) {
                if (op2IsLarger == cwIsTowardLarger) {
                    cw[i] = op2;
                    ccw[j++] = null;
                } else {
                    ccw[j] = op2;
                    cw[i++] = null;
                }
            } else if ((op2.next == op2.prev) || (op2.pt == op2.prev.pt)) {
                if (opIsLarger == cwIsTowardLarger) {
                    cw[i] = op;
                    ccw[j++] = null;
                } else {
                    ccw[j] = op;
                    cw[i++] = null;
                }
            } else if (opIsLarger == op2IsLarger) {
                if (opIsLarger == cwIsTowardLarger) {
                    cw[i] = op;
                    uncoupleEdge(op2);
                    addToEdge(cw, op2);
                    ccw[j++] = null;
                } else {
                    cw[i++] = null;
                    ccw[j] = op2;
                    uncoupleEdge(op);
                    addToEdge(ccw, op);
                    j = 0;
                }
            } else {
                if (opIsLarger == cwIsTowardLarger)
                    cw[i] = op;
                else
                    ccw[j] = op;
                if (op2IsLarger == cwIsTowardLarger)
                    cw[i] = op2;
                else
                    ccw[j] = op2;
            }
        }
    }

    private static function getPath(op:Null<OutPt2>):Path64 {
        var result = new Path64();
        if (op == null || op.prev == op.next) return result;
        var op2 = op.next;
        while (op2 != null && op2 != op) {
            if (InternalClipper.isCollinear(op2.prev.pt, op2.pt, op2.next.pt)) {
                op = op2.prev;
                op2 = unlinkOp(op2);
            } else {
                op2 = op2.next;
            }
        }
        if (op2 == null) return new Path64();

        result.push(op.pt);
        op2 = op.next;
        while (op2 != op) {
            result.push(op2.pt);
            op2 = op2.next;
        }
        return result;
    }
}

// ============================================================================
// RectClipLines64 - Fast rectangular clipping for open paths (lines)
// ============================================================================

class RectClipLines64 extends RectClip64 {
    public function new(rect:Rect64) {
        super(rect);
    }

    public override function execute(paths:Paths64):Paths64 {
        var result = new Paths64();
        if (rect_.isEmpty()) return result;
        for (path in paths) {
            if (path.length < 2) continue;
            pathBounds_ = getBoundsStatic(path);
            if (!rect_.intersects(pathBounds_)) continue;
            executeInternalLines(path);

            for (op in results_) {
                var tmp = getPathLines(op);
                if (tmp.length > 0) result.push(tmp);
            }

            results_ = [];
            for (i in 0...8) edges_[i] = [];
        }
        return result;
    }

    private static function getBoundsStatic(path:Path64):Rect64 {
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

    private static function getPathLines(op:Null<OutPt2>):Path64 {
        var result = new Path64();
        if (op == null || op == op.next) return result;
        op = op.next; // starting at path beginning
        result.push(op.pt);
        var op2 = op.next;
        while (op2 != op) {
            result.push(op2.pt);
            op2 = op2.next;
        }
        return result;
    }

    private function executeInternalLines(path:Path64):Void {
        results_ = [];
        if (path.length < 2 || rect_.isEmpty()) return;

        var prev = Location.Inside;
        var highI = path.length - 1;
        var locResult = RectClip64.getLocation(rect_, path[0]);
        var loc = locResult.loc;
        var i = 1;

        if (locResult.isOnRect) {
            while (i <= highI) {
                var prevResult = RectClip64.getLocation(rect_, path[i]);
                if (!prevResult.isOnRect) {
                    prev = prevResult.loc;
                    break;
                }
                i++;
            }
            if (i > highI) {
                for (pt in path) add(pt);
                return;
            }
            if (prev == Location.Inside) loc = Location.Inside;
            i = 1;
        }
        if (loc == Location.Inside) add(path[0]);

        while (i <= highI) {
            prev = loc;
            var nextResult = getNextLocation(path, loc, i, highI);
            loc = nextResult.loc;
            i = nextResult.i;
            if (i > highI) break;
            var prevPt = path[i - 1];

            var crossingLoc = loc;
            var intResult = RectClip64.getIntersection(rectPath_, path[i], prevPt, crossingLoc);
            if (!intResult.success) {
                i++;
                continue;
            }

            crossingLoc = intResult.loc;
            var ip = intResult.ip;

            if (loc == Location.Inside) { // path must be entering rect
                add(ip, true);
            } else if (prev != Location.Inside) {
                // passing right through rect
                var tempLoc = prev;
                var ip2Result = RectClip64.getIntersection(rectPath_, prevPt, path[i], tempLoc);
                add(ip2Result.ip, true);
                add(ip);
            } else { // path must be exiting rect
                add(ip);
            }
        }
    }
}
