package clipper2;

import haxe.Int64;
import clipper2.internal.ClipperCore;

/**
 * Result of triangulation operation.
 */
enum abstract TriangulateResult(Int) {
    var Success = 0;
    var Fail = 1;
    var NoPolygons = 2;
    var PathsIntersect = 3;
}

// Internal enums for triangulation
private enum abstract EdgeKind(Int) {
    var Loose = 0;
    var Ascend = 1;
    var Descend = 2;
}

private enum abstract IntersectKind(Int) {
    var None = 0;
    var Collinear = 1;
    var Intersect = 2;
}

private enum abstract EdgeContainsResult(Int) {
    var Neither = 0;
    var Left = 1;
    var Right = 2;
}

/**
 * Internal vertex class for triangulation.
 */
private class Vertex2 {
    public var pt:Point64;
    public var edges:Array<Edge>;
    public var innerLM:Bool;

    public function new(p64:Point64) {
        pt = p64;
        edges = [];
        innerLM = false;
    }
}

/**
 * Internal edge class for triangulation.
 */
private class Edge {
    public var vL:Null<Vertex2>;
    public var vR:Null<Vertex2>;
    public var vB:Null<Vertex2>;
    public var vT:Null<Vertex2>;
    public var kind:EdgeKind;
    public var triA:Null<Triangle>;
    public var triB:Null<Triangle>;
    public var isActive:Bool;
    public var nextE:Null<Edge>;
    public var prevE:Null<Edge>;

    public function new() {
        vL = null;
        vR = null;
        vB = null;
        vT = null;
        kind = EdgeKind.Loose;
        triA = null;
        triB = null;
        isActive = false;
        nextE = null;
        prevE = null;
    }
}

/**
 * Internal triangle class for triangulation.
 */
private class Triangle {
    public var edges:Array<Edge>;

    public function new(e1:Edge, e2:Edge, e3:Edge) {
        edges = [e1, e2, e3];
    }
}

/**
 * Constrained Delaunay Triangulation engine.
 */
class Delaunay {
    private var allVertices:Array<Vertex2>;
    private var allEdges:Array<Edge>;
    private var allTriangles:Array<Triangle>;
    private var pendingDelaunayStack:Array<Edge>;
    private var horzEdgeStack:Array<Edge>;
    private var locMinStack:Array<Vertex2>;
    private var useDelaunay:Bool;
    private var firstActive:Null<Edge>;
    private var lowermostVertex:Null<Vertex2>;

    public function new(delaunay:Bool = true) {
        useDelaunay = delaunay;
        allVertices = [];
        allEdges = [];
        allTriangles = [];
        pendingDelaunayStack = [];
        horzEdgeStack = [];
        locMinStack = [];
        firstActive = null;
        lowermostVertex = null;
    }

    private function addPath(path:Path64):Void {
        var len = path.length;
        if (len == 0) return;

        var i0 = 0;
        var iPrev:Int, iNext:Int;

        var findResult = findLocMinIdx(path, len, i0);
        if (!findResult.found) return;
        i0 = findResult.idx;

        iPrev = prev(i0, len);
        while (path[iPrev] == path[i0])
            iPrev = prev(iPrev, len);

        iNext = next(i0, len);

        var i = i0;
        while (InternalClipper.crossProductSign(path[iPrev], path[i], path[iNext]) == 0) {
            var findRes = findLocMinIdx(path, len, i);
            i = findRes.idx;
            if (i == i0) return; // entirely collinear path
            iPrev = prev(i, len);
            while (path[iPrev] == path[i])
                iPrev = prev(iPrev, len);
            iNext = next(i, len);
        }

        var vertCnt = allVertices.length;
        var v0 = new Vertex2(path[i]);
        allVertices.push(v0);

        if (leftTurning(path[iPrev], path[i], path[iNext]))
            v0.innerLM = true;

        var vPrev = v0;
        i = iNext;

        while (true) {
            // vPrev is a locMin here
            locMinStack.push(vPrev);
            // update lowermostVertex
            if (lowermostVertex == null ||
                vPrev.pt.y > lowermostVertex.pt.y ||
                (vPrev.pt.y == lowermostVertex.pt.y &&
                 vPrev.pt.x < lowermostVertex.pt.x))
                lowermostVertex = vPrev;

            iNext = next(i, len);
            if (InternalClipper.crossProductSign(vPrev.pt, path[i], path[iNext]) == 0) {
                i = iNext;
                continue;
            }

            // ascend up next bound to LocMax
            while (path[i].y <= vPrev.pt.y) {
                var v = new Vertex2(path[i]);
                allVertices.push(v);
                createEdge(vPrev, v, EdgeKind.Ascend);
                vPrev = v;
                i = iNext;
                iNext = next(i, len);

                while (InternalClipper.crossProductSign(vPrev.pt, path[i], path[iNext]) == 0) {
                    i = iNext;
                    iNext = next(i, len);
                }
            }

            // Now at a locMax, so descend to next locMin
            var vPrevPrev = vPrev;
            while (i != i0 && path[i].y >= vPrev.pt.y) {
                var v = new Vertex2(path[i]);
                allVertices.push(v);
                createEdge(v, vPrev, EdgeKind.Descend);
                vPrevPrev = vPrev;
                vPrev = v;
                i = iNext;
                iNext = next(i, len);

                while (InternalClipper.crossProductSign(vPrev.pt, path[i], path[iNext]) == 0) {
                    i = iNext;
                    iNext = next(i, len);
                }
            }

            // now at the next locMin
            if (i == i0) break;
            if (leftTurning(vPrevPrev.pt, vPrev.pt, path[i]))
                vPrev.innerLM = true;
        }

        createEdge(v0, vPrev, EdgeKind.Descend);

        // finally, ignore this path if is not a polygon or too small
        var newLen = allVertices.length - vertCnt;
        var idx = vertCnt;
        if (newLen < 3 || (newLen == 3 &&
            ((distSqr(allVertices[idx].pt, allVertices[idx + 1].pt) <= 1) ||
             (distSqr(allVertices[idx + 1].pt, allVertices[idx + 2].pt) <= 1) ||
             (distSqr(allVertices[idx + 2].pt, allVertices[idx].pt) <= 1)))) {
            var j = vertCnt;
            while (j < allVertices.length) {
                allVertices[j].edges = []; // flag to ignore
                j++;
            }
        }
    }

    private function addPaths(paths:Paths64):Bool {
        var totalVertexCount = 0;
        for (path in paths)
            totalVertexCount += path.length;
        if (totalVertexCount == 0) return false;

        for (path in paths)
            addPath(path);

        return allVertices.length > 2;
    }

    private function cleanUp():Void {
        allVertices = [];
        allEdges = [];
        allTriangles = [];
        pendingDelaunayStack = [];
        horzEdgeStack = [];
        locMinStack = [];
        firstActive = null;
        lowermostVertex = null;
    }

    private function fixupEdgeIntersects():Bool {
        var i1 = 0;
        while (i1 < allEdges.length) {
            var e1 = allEdges[i1];
            var i2 = i1 + 1;
            while (i2 < allEdges.length) {
                var e2 = allEdges[i2];
                if (e2.vL.pt.x >= e1.vR.pt.x)
                    break;

                if (e2.vT.pt.y < e1.vB.pt.y && e2.vB.pt.y > e1.vT.pt.y &&
                    segsIntersect(e2.vL.pt, e2.vR.pt, e1.vL.pt, e1.vR.pt) == IntersectKind.Intersect) {
                    if (!removeIntersection(e2, e1))
                        return false;
                }
                i2++;
            }
            i1++;
        }
        return true;
    }

    private function mergeDupOrCollinearVertices():Void {
        if (allVertices.length < 2) return;

        var v1Index = 0;
        var v2Index = 1;
        while (v2Index < allVertices.length) {
            var v1 = allVertices[v1Index];
            var v2 = allVertices[v2Index];

            if (v1.pt != v2.pt) {
                v1Index = v2Index;
                v2Index++;
                continue;
            }

            // merge v1 & v2
            if (!v1.innerLM || !v2.innerLM)
                v1.innerLM = false;

            for (e in v2.edges) {
                if (e.vB == v2) e.vB = v1; else e.vT = v1;
                if (e.vL == v2) e.vL = v1; else e.vR = v1;
            }

            for (e in v2.edges)
                v1.edges.push(e);
            v2.edges = [];

            // excluding horizontals, if v1.edges contains two edges
            // that are collinear and share the same bottom coords
            // but have different lengths, split the longer edge
            var iE = 0;
            while (iE < v1.edges.length) {
                var e1 = v1.edges[iE];
                if (isHorizontal(e1) || e1.vB != v1) {
                    iE++;
                    continue;
                }

                var iE2 = iE + 1;
                while (iE2 < v1.edges.length) {
                    var e2 = v1.edges[iE2];
                    if (e2.vB != v1 || e1.vT.pt.y == e2.vT.pt.y ||
                        InternalClipper.crossProductSign(e1.vT.pt, v1.pt, e2.vT.pt) != 0) {
                        iE2++;
                        continue;
                    }

                    // parallel edges from v1 up
                    if (e1.vT.pt.y < e2.vT.pt.y) splitEdge(e1, e2);
                    else splitEdge(e2, e1);
                    break; // only two can be collinear
                }
                iE++;
            }
            v2Index++;
        }
    }

    private function splitEdge(longE:Edge, shortE:Edge):Void {
        var oldT = longE.vT;
        var newT = shortE.vT;

        removeEdgeFromVertex(oldT, longE);

        longE.vT = newT;
        if (longE.vL == oldT) longE.vL = newT; else longE.vR = newT;

        newT.edges.push(longE);

        createEdge(newT, oldT, longE.kind);
    }

    private function removeIntersection(e1:Edge, e2:Edge):Bool {
        var v = e1.vL;
        var tmpE = e2;

        var d = shortestDistFromSegment(e1.vL.pt, e2.vL.pt, e2.vR.pt);
        var d2 = shortestDistFromSegment(e1.vR.pt, e2.vL.pt, e2.vR.pt);
        if (d2 < d) { d = d2; v = e1.vR; }

        d2 = shortestDistFromSegment(e2.vL.pt, e1.vL.pt, e1.vR.pt);
        if (d2 < d) { d = d2; tmpE = e1; v = e2.vL; }

        d2 = shortestDistFromSegment(e2.vR.pt, e1.vL.pt, e1.vR.pt);
        if (d2 < d) { d = d2; tmpE = e1; v = e2.vR; }

        if (d > 1.0)
            return false; // not a simple rounding intersection

        var v2 = tmpE.vT;
        removeEdgeFromVertex(v2, tmpE);

        if (tmpE.vL == v2) tmpE.vL = v; else tmpE.vR = v;
        tmpE.vT = v;
        v.edges.push(tmpE);
        v.innerLM = false;

        if (tmpE.vB.innerLM && getLocMinAngle(tmpE.vB) <= 0)
            tmpE.vB.innerLM = false;

        createEdge(v, v2, tmpE.kind);
        return true;
    }

    private function createEdge(v1:Vertex2, v2:Vertex2, k:EdgeKind):Edge {
        var res = new Edge();
        allEdges.push(res);

        if (v1.pt.y == v2.pt.y) {
            res.vB = v1;
            res.vT = v2;
        } else if (v1.pt.y < v2.pt.y) {
            res.vB = v2;
            res.vT = v1;
        } else {
            res.vB = v1;
            res.vT = v2;
        }

        if (v1.pt.x <= v2.pt.x) {
            res.vL = v1;
            res.vR = v2;
        } else {
            res.vL = v2;
            res.vR = v1;
        }

        res.kind = k;
        v1.edges.push(res);
        v2.edges.push(res);

        if (k == EdgeKind.Loose) {
            pendingDelaunayStack.push(res);
            addEdgeToActives(res);
        }

        return res;
    }

    private function createTriangle(e1:Edge, e2:Edge, e3:Edge):Triangle {
        var tri = new Triangle(e1, e2, e3);
        allTriangles.push(tri);

        for (i in 0...3) {
            var e = tri.edges[i];
            if (e.triA != null) {
                e.triB = tri;
                removeEdgeFromActives(e);
            } else {
                e.triA = tri;
                if (!isLooseEdge(e))
                    removeEdgeFromActives(e);
            }
        }
        return tri;
    }

    private function forceLegal(edge:Edge):Void {
        if (edge.triA == null || edge.triB == null) return;

        var vertA:Null<Vertex2> = null;
        var vertB:Null<Vertex2> = null;

        var edgesA:Array<Null<Edge>> = [null, null, null];
        var edgesB:Array<Null<Edge>> = [null, null, null];

        for (i in 0...3) {
            if (edge.triA.edges[i] == edge) continue;
            var e = edge.triA.edges[i];
            switch (edgeContains(e, edge.vL)) {
                case EdgeContainsResult.Left:
                    edgesA[1] = e;
                    vertA = e.vR;
                case EdgeContainsResult.Right:
                    edgesA[1] = e;
                    vertA = e.vL;
                default:
                    edgesB[1] = e;
            }
        }

        for (i in 0...3) {
            if (edge.triB.edges[i] == edge) continue;
            var e = edge.triB.edges[i];
            switch (edgeContains(e, edge.vL)) {
                case EdgeContainsResult.Left:
                    edgesA[2] = e;
                    vertB = e.vR;
                case EdgeContainsResult.Right:
                    edgesA[2] = e;
                    vertB = e.vL;
                default:
                    edgesB[2] = e;
            }
        }

        if (vertA == null || vertB == null) return;

        if (InternalClipper.crossProductSign(vertA.pt, edge.vL.pt, edge.vR.pt) == 0)
            return;

        var ictResult = inCircleTest(vertA.pt, edge.vL.pt, edge.vR.pt, vertB.pt);
        if (ictResult == 0 ||
            (rightTurning(vertA.pt, edge.vL.pt, edge.vR.pt) == (ictResult < 0)))
            return;

        edge.vL = vertA;
        edge.vR = vertB;

        edge.triA.edges[0] = edge;
        for (i in 1...3) {
            var eAi = edgesA[i];
            edge.triA.edges[i] = eAi;
            if (isLooseEdge(eAi))
                pendingDelaunayStack.push(eAi);

            if (eAi.triA == edge.triA || eAi.triB == edge.triA) continue;

            if (eAi.triA == edge.triB)
                eAi.triA = edge.triA;
            else if (eAi.triB == edge.triB)
                eAi.triB = edge.triA;
        }

        edge.triB.edges[0] = edge;
        for (i in 1...3) {
            var eBi = edgesB[i];
            edge.triB.edges[i] = eBi;
            if (isLooseEdge(eBi))
                pendingDelaunayStack.push(eBi);

            if (eBi.triA == edge.triB || eBi.triB == edge.triB) continue;

            if (eBi.triA == edge.triA)
                eBi.triA = edge.triB;
            else if (eBi.triB == edge.triA)
                eBi.triB = edge.triB;
        }
    }

    private function createInnerLocMinLooseEdge(vAbove:Vertex2):Null<Edge> {
        if (firstActive == null) return null;

        var xAbove = vAbove.pt.x;
        var yAbove = vAbove.pt.y;

        var e = firstActive;
        var eBelow:Null<Edge> = null;
        var bestD:Float = -1.0;

        while (e != null) {
            if (e.vL.pt.x <= xAbove && e.vR.pt.x >= xAbove &&
                e.vB.pt.y >= yAbove && e.vB != vAbove && e.vT != vAbove &&
                !leftTurning(e.vL.pt, vAbove.pt, e.vR.pt)) {
                var d = shortestDistFromSegment(vAbove.pt, e.vL.pt, e.vR.pt);
                if (eBelow == null || d < bestD) {
                    eBelow = e;
                    bestD = d;
                }
            }
            e = e.nextE;
        }

        if (eBelow == null) return null;

        var vBest = (eBelow.vT.pt.y <= yAbove) ? eBelow.vB : eBelow.vT;
        var xBest = vBest.pt.x;
        var yBest = vBest.pt.y;

        e = firstActive;
        if (xBest < xAbove) {
            while (e != null) {
                if (e.vR.pt.x > xBest && e.vL.pt.x < xAbove &&
                    e.vB.pt.y > yAbove && e.vT.pt.y < yBest &&
                    segsIntersect(e.vB.pt, e.vT.pt, vBest.pt, vAbove.pt) == IntersectKind.Intersect) {
                    vBest = (e.vT.pt.y > yAbove) ? e.vT : e.vB;
                    xBest = vBest.pt.x;
                    yBest = vBest.pt.y;
                }
                e = e.nextE;
            }
        } else {
            while (e != null) {
                if (e.vR.pt.x < xBest && e.vL.pt.x > xAbove &&
                    e.vB.pt.y > yAbove && e.vT.pt.y < yBest &&
                    segsIntersect(e.vB.pt, e.vT.pt, vBest.pt, vAbove.pt) == IntersectKind.Intersect) {
                    vBest = (e.vT.pt.y > yAbove) ? e.vT : e.vB;
                    xBest = vBest.pt.x;
                    yBest = vBest.pt.y;
                }
                e = e.nextE;
            }
        }

        return createEdge(vBest, vAbove, EdgeKind.Loose);
    }

    private function horizontalBetween(v1:Vertex2, v2:Vertex2):Null<Edge> {
        var y = v1.pt.y;
        var l:Int64, r:Int64;

        if (v1.pt.x > v2.pt.x) {
            l = v2.pt.x;
            r = v1.pt.x;
        } else {
            l = v1.pt.x;
            r = v2.pt.x;
        }

        var res = firstActive;
        while (res != null) {
            if (res.vL.pt.y == y && res.vR.pt.y == y &&
                res.vL.pt.x >= l && res.vR.pt.x <= r &&
                (res.vL.pt.x != l || res.vL.pt.x != r))
                break;

            res = res.nextE;
        }
        return res;
    }

    private function doTriangulateLeft(edge:Edge, pivot:Vertex2, minY:Int64):Void {
        var vAlt:Null<Vertex2> = null;
        var eAlt:Null<Edge> = null;

        var v = (edge.vB == pivot) ? edge.vT : edge.vB;

        for (e in pivot.edges) {
            if (e == edge || !e.isActive) continue;

            var vX = (e.vT == pivot) ? e.vB : e.vT;
            if (vX == v) continue;

            var cps = InternalClipper.crossProductSign(v.pt, pivot.pt, vX.pt);
            if (cps == 0) {
                if ((v.pt.x > pivot.pt.x) == (pivot.pt.x > vX.pt.x)) continue;
            } else if (cps > 0 || (vAlt != null && !leftTurning(vX.pt, pivot.pt, vAlt.pt)))
                continue;

            vAlt = vX;
            eAlt = e;
        }

        if (vAlt == null || vAlt.pt.y < minY || eAlt == null) return;

        if (vAlt.pt.y < pivot.pt.y) {
            if (isLeftEdge(eAlt)) return;
        } else if (vAlt.pt.y > pivot.pt.y) {
            if (isRightEdge(eAlt)) return;
        }

        var eX = findLinkingEdge(vAlt, v, (vAlt.pt.y < v.pt.y));
        if (eX == null) {
            if (vAlt.pt.y == v.pt.y && v.pt.y == minY &&
                horizontalBetween(vAlt, v) != null)
                return;

            eX = createEdge(vAlt, v, EdgeKind.Loose);
        }

        createTriangle(edge, eAlt, eX);

        if (!edgeCompleted(eX))
            doTriangulateLeft(eX, vAlt, minY);
    }

    private function doTriangulateRight(edge:Edge, pivot:Vertex2, minY:Int64):Void {
        var vAlt:Null<Vertex2> = null;
        var eAlt:Null<Edge> = null;

        var v = (edge.vB == pivot) ? edge.vT : edge.vB;

        for (e in pivot.edges) {
            if (e == edge || !e.isActive) continue;

            var vX = (e.vT == pivot) ? e.vB : e.vT;
            if (vX == v) continue;

            var cps = InternalClipper.crossProductSign(v.pt, pivot.pt, vX.pt);
            if (cps == 0) {
                if ((v.pt.x > pivot.pt.x) == (pivot.pt.x > vX.pt.x)) continue;
            } else if (cps < 0 || (vAlt != null && !rightTurning(vX.pt, pivot.pt, vAlt.pt)))
                continue;

            vAlt = vX;
            eAlt = e;
        }

        if (vAlt == null || vAlt.pt.y < minY || eAlt == null) return;

        if (vAlt.pt.y < pivot.pt.y) {
            if (isRightEdge(eAlt)) return;
        } else if (vAlt.pt.y > pivot.pt.y) {
            if (isLeftEdge(eAlt)) return;
        }

        var eX = findLinkingEdge(vAlt, v, (vAlt.pt.y > v.pt.y));
        if (eX == null) {
            if (vAlt.pt.y == v.pt.y && v.pt.y == minY &&
                horizontalBetween(vAlt, v) != null)
                return;

            eX = createEdge(vAlt, v, EdgeKind.Loose);
        }

        createTriangle(edge, eX, eAlt);

        if (!edgeCompleted(eX))
            doTriangulateRight(eX, vAlt, minY);
    }

    private function addEdgeToActives(edge:Edge):Void {
        if (edge.isActive) return;

        edge.prevE = null;
        edge.nextE = firstActive;
        edge.isActive = true;

        if (firstActive != null)
            firstActive.prevE = edge;

        firstActive = edge;
    }

    private function removeEdgeFromActives(edge:Edge):Void {
        removeEdgeFromVertex(edge.vB, edge);
        removeEdgeFromVertex(edge.vT, edge);

        var prev = edge.prevE;
        var nextEdge = edge.nextE;

        if (nextEdge != null) nextEdge.prevE = prev;
        if (prev != null) prev.nextE = nextEdge;

        edge.isActive = false;
        if (firstActive == edge) firstActive = nextEdge;
    }

    /**
     * Execute triangulation on the given paths.
     * @param paths Input paths to triangulate
     * @return Object containing result status and solution paths
     */
    public function execute(paths:Paths64):{result:TriangulateResult, solution:Paths64} {
        var sol = new Paths64();

        if (!addPaths(paths)) {
            return {result: TriangulateResult.NoPolygons, solution: sol};
        }

        // if necessary fix path orientation
        if (lowermostVertex.innerLM) {
            // the orientation of added paths must be wrong
            while (locMinStack.length > 0) {
                var lm = locMinStack.pop();
                lm.innerLM = !lm.innerLM;
            }
            for (e in allEdges) {
                if (e.kind == EdgeKind.Ascend)
                    e.kind = EdgeKind.Descend;
                else
                    e.kind = EdgeKind.Ascend;
            }
        } else {
            while (locMinStack.length > 0)
                locMinStack.pop();
        }

        // Sort edges by vL.pt.X
        allEdges.sort(function(a:Edge, b:Edge):Int {
            if (a.vL.pt.x < b.vL.pt.x) return -1;
            if (a.vL.pt.x > b.vL.pt.x) return 1;
            return 0;
        });

        if (!fixupEdgeIntersects()) {
            cleanUp();
            return {result: TriangulateResult.PathsIntersect, solution: sol};
        }

        // Sort vertices by Y descending, then X ascending
        allVertices.sort(function(a:Vertex2, b:Vertex2):Int {
            if (a.pt.y == b.pt.y) {
                if (a.pt.x < b.pt.x) return -1;
                if (a.pt.x > b.pt.x) return 1;
                return 0;
            }
            if (b.pt.y < a.pt.y) return -1;
            if (b.pt.y > a.pt.y) return 1;
            return 0;
        });

        mergeDupOrCollinearVertices();

        var currY = allVertices[0].pt.y;

        for (v in allVertices) {
            if (v.edges.length == 0) continue;

            if (v.pt.y != currY) {
                while (locMinStack.length > 0) {
                    var lm = locMinStack.pop();
                    var e = createInnerLocMinLooseEdge(lm);
                    if (e == null) {
                        cleanUp();
                        return {result: TriangulateResult.Fail, solution: sol};
                    }

                    if (isHorizontal(e)) {
                        if (e.vL == e.vB)
                            doTriangulateLeft(e, e.vB, currY);
                        else
                            doTriangulateRight(e, e.vB, currY);
                    } else {
                        doTriangulateLeft(e, e.vB, currY);
                        if (!edgeCompleted(e))
                            doTriangulateRight(e, e.vB, currY);
                    }

                    addEdgeToActives(lm.edges[0]);
                    addEdgeToActives(lm.edges[1]);
                }

                while (horzEdgeStack.length > 0) {
                    var e = horzEdgeStack.pop();
                    if (edgeCompleted(e)) continue;

                    if (e.vB == e.vL) {
                        if (isLeftEdge(e))
                            doTriangulateLeft(e, e.vB, currY);
                    } else {
                        if (isRightEdge(e))
                            doTriangulateRight(e, e.vB, currY);
                    }
                }

                currY = v.pt.y;
            }

            var i = v.edges.length - 1;
            while (i >= 0) {
                if (i >= v.edges.length) {
                    i--;
                    continue;
                }

                var e = v.edges[i];
                if (edgeCompleted(e) || isLooseEdge(e)) {
                    i--;
                    continue;
                }

                if (v == e.vB) {
                    if (isHorizontal(e))
                        horzEdgeStack.push(e);

                    if (!v.innerLM)
                        addEdgeToActives(e);
                } else {
                    if (isHorizontal(e))
                        horzEdgeStack.push(e);
                    else if (isLeftEdge(e))
                        doTriangulateLeft(e, e.vB, v.pt.y);
                    else
                        doTriangulateRight(e, e.vB, v.pt.y);
                }
                i--;
            }

            if (v.innerLM)
                locMinStack.push(v);
        }

        while (horzEdgeStack.length > 0) {
            var e = horzEdgeStack.pop();
            if (!edgeCompleted(e) && e.vB == e.vL)
                doTriangulateLeft(e, e.vB, currY);
        }

        if (useDelaunay) {
            while (pendingDelaunayStack.length > 0) {
                var e = pendingDelaunayStack.pop();
                forceLegal(e);
            }
        }

        for (tri in allTriangles) {
            var p = pathFromTriangle(tri);
            var cps = InternalClipper.crossProductSign(p[0], p[1], p[2]);
            if (cps == 0) continue;
            if (cps < 0) {
                var reversed = new Path64();
                var j = p.length - 1;
                while (j >= 0) {
                    reversed.push(p[j]);
                    j--;
                }
                p = reversed;
            }
            sol.push(p);
        }

        cleanUp();
        return {result: TriangulateResult.Success, solution: sol};
    }

    // Static / helper functions

    private static function isLooseEdge(e:Edge):Bool {
        return e.kind == EdgeKind.Loose;
    }

    private static function isLeftEdge(e:Edge):Bool {
        return e.kind == EdgeKind.Ascend;
    }

    private static function isRightEdge(e:Edge):Bool {
        return e.kind == EdgeKind.Descend;
    }

    private static function isHorizontal(e:Edge):Bool {
        return e.vB.pt.y == e.vT.pt.y;
    }

    private static function leftTurning(p1:Point64, p2:Point64, p3:Point64):Bool {
        return InternalClipper.crossProductSign(p1, p2, p3) < 0;
    }

    private static function rightTurning(p1:Point64, p2:Point64, p3:Point64):Bool {
        return InternalClipper.crossProductSign(p1, p2, p3) > 0;
    }

    private static function edgeCompleted(edge:Edge):Bool {
        if (edge.triA == null) return false;
        if (edge.triB != null) return true;
        return edge.kind != EdgeKind.Loose;
    }

    private static function edgeContains(edge:Edge, v:Vertex2):EdgeContainsResult {
        if (edge.vL == v) return EdgeContainsResult.Left;
        if (edge.vR == v) return EdgeContainsResult.Right;
        return EdgeContainsResult.Neither;
    }

    private static function getAngle(a:Point64, b:Point64, c:Point64):Float {
        var abx = InternalClipper.toFloat(b.x - a.x);
        var aby = InternalClipper.toFloat(b.y - a.y);
        var bcx = InternalClipper.toFloat(b.x - c.x);
        var bcy = InternalClipper.toFloat(b.y - c.y);
        var dp = abx * bcx + aby * bcy;
        var cp = abx * bcy - aby * bcx;
        return Math.atan2(cp, dp);
    }

    private static function getLocMinAngle(v:Vertex2):Float {
        var asc:Int, des:Int;
        if (v.edges[0].kind == EdgeKind.Ascend) {
            asc = 0;
            des = 1;
        } else {
            des = 0;
            asc = 1;
        }
        return getAngle(v.edges[des].vT.pt, v.pt, v.edges[asc].vT.pt);
    }

    private static function removeEdgeFromVertex(vert:Vertex2, edge:Edge):Void {
        var idx = vert.edges.indexOf(edge);
        if (idx >= 0)
            vert.edges.splice(idx, 1);
    }

    private static function findLocMinIdx(path:Path64, len:Int, idx:Int):{found:Bool, idx:Int} {
        if (len < 3) return {found: false, idx: idx};
        var i0 = idx;
        var n = (idx + 1) % len;

        while (path[n].y <= path[idx].y) {
            idx = n;
            n = (n + 1) % len;
            if (idx == i0) return {found: false, idx: idx};
        }

        while (path[n].y >= path[idx].y) {
            idx = n;
            n = (n + 1) % len;
        }

        return {found: true, idx: idx};
    }

    private static function prev(idx:Int, len:Int):Int {
        if (idx == 0) return len - 1;
        return idx - 1;
    }

    private static function next(idx:Int, len:Int):Int {
        return (idx + 1) % len;
    }

    private static function findLinkingEdge(vert1:Vertex2, vert2:Vertex2, preferAscending:Bool):Null<Edge> {
        var res:Null<Edge> = null;
        for (e in vert1.edges) {
            if (e.vL == vert2 || e.vR == vert2) {
                if (e.kind == EdgeKind.Loose ||
                    ((e.kind == EdgeKind.Ascend) == preferAscending))
                    return e;
                res = e;
            }
        }
        return res;
    }

    private static function pathFromTriangle(tri:Triangle):Path64 {
        var res:Path64 = [tri.edges[0].vL.pt, tri.edges[0].vR.pt];
        var e = tri.edges[1];
        if (e.vL.pt == res[0] || e.vL.pt == res[1])
            res.push(e.vR.pt);
        else
            res.push(e.vL.pt);
        return res;
    }

    private static function inCircleTest(ptA:Point64, ptB:Point64, ptC:Point64, ptD:Point64):Float {
        var m00 = InternalClipper.toFloat(ptA.x - ptD.x);
        var m01 = InternalClipper.toFloat(ptA.y - ptD.y);
        var m02 = sqr(m00) + sqr(m01);

        var m10 = InternalClipper.toFloat(ptB.x - ptD.x);
        var m11 = InternalClipper.toFloat(ptB.y - ptD.y);
        var m12 = sqr(m10) + sqr(m11);

        var m20 = InternalClipper.toFloat(ptC.x - ptD.x);
        var m21 = InternalClipper.toFloat(ptC.y - ptD.y);
        var m22 = sqr(m20) + sqr(m21);

        return m00 * (m11 * m22 - m21 * m12) -
               m10 * (m01 * m22 - m21 * m02) +
               m20 * (m01 * m12 - m11 * m02);
    }

    private static function shortestDistFromSegment(pt:Point64, segPt1:Point64, segPt2:Point64):Float {
        var dx = InternalClipper.toFloat(segPt2.x - segPt1.x);
        var dy = InternalClipper.toFloat(segPt2.y - segPt1.y);

        var ax = InternalClipper.toFloat(pt.x - segPt1.x);
        var ay = InternalClipper.toFloat(pt.y - segPt1.y);

        var qNum = ax * dx + ay * dy;
        var denom = sqr(dx) + sqr(dy);

        if (qNum < 0)
            return distanceSqr(pt, segPt1);
        if (qNum > denom)
            return distanceSqr(pt, segPt2);

        return sqr(ax * dy - dx * ay) / denom;
    }

    private static function segsIntersect(s1a:Point64, s1b:Point64, s2a:Point64, s2b:Point64):IntersectKind {
        var dy1 = InternalClipper.toFloat(s1b.y - s1a.y);
        var dx1 = InternalClipper.toFloat(s1b.x - s1a.x);
        var dy2 = InternalClipper.toFloat(s2b.y - s2a.y);
        var dx2 = InternalClipper.toFloat(s2b.x - s2a.x);

        var cp = dy1 * dx2 - dy2 * dx1;
        if (cp == 0) return IntersectKind.Collinear;

        var t = (InternalClipper.toFloat(s1a.x - s2a.x) * dy2 -
                 InternalClipper.toFloat(s1a.y - s2a.y) * dx2);

        if (t == 0) return IntersectKind.None;
        if (t > 0) {
            if (cp < 0 || t >= cp) return IntersectKind.None;
        } else {
            if (cp > 0 || t <= cp) return IntersectKind.None;
        }

        t = (InternalClipper.toFloat(s1a.x - s2a.x) * dy1 -
             InternalClipper.toFloat(s1a.y - s2a.y) * dx1);

        if (t == 0) return IntersectKind.None;
        if (t > 0) {
            if (cp > 0 && t < cp) return IntersectKind.Intersect;
        } else {
            if (cp < 0 && t > cp) return IntersectKind.Intersect;
        }

        return IntersectKind.None;
    }

    private static function distSqr(pt1:Point64, pt2:Point64):Float {
        return sqr(InternalClipper.toFloat(pt1.x - pt2.x)) + sqr(InternalClipper.toFloat(pt1.y - pt2.y));
    }

    private static function sqr(v:Float):Float {
        return v * v;
    }

    private static function distanceSqr(a:Point64, b:Point64):Float {
        var dx = InternalClipper.toFloat(a.x - b.x);
        var dy = InternalClipper.toFloat(a.y - b.y);
        return dx * dx + dy * dy;
    }
}

/**
 * High-level triangulation function.
 */
class ClipperTriangulation {
    /**
     * Triangulates a set of paths using Constrained Delaunay Triangulation.
     * @param paths Input paths (polygons) to triangulate
     * @param useDelaunay Whether to use Delaunay optimization (default true)
     * @return Object containing result status and solution triangles
     */
    public static function triangulate(paths:Paths64, useDelaunay:Bool = true):{result:TriangulateResult, solution:Paths64} {
        var delaunay = new Delaunay(useDelaunay);
        return delaunay.execute(paths);
    }
}
