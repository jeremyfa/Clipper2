package clipper;

import clipper.ClipperCore;
import clipper.ClipperEngine;

/**
 * Object pooling manager for Clipper2.
 *
 * Use `trackObjects()` before clipper operations and `recycleObjects()` after
 * to reuse allocated objects and reduce GC pressure.
 *
 * Example:
 * ```haxe
 * ClipperPool.trackObjects();
 * var result = Clipper.inflatePaths(paths, 10, JoinType.Miter, EndType.Polygon);
 * // Copy needed data from result
 * ClipperPool.recycleObjects();
 * ```
 */
class ClipperPool {
    // Pool storage (arrays acting as stacks)
    static var point64Pool:Array<Point64Impl> = [];
    static var pointDPool:Array<PointDImpl> = [];
    static var outPtPool:Array<OutPt> = [];
    static var activePool:Array<Active> = [];
    static var vertexPool:Array<Vertex> = [];
    static var localMinimaPool:Array<LocalMinima> = [];
    static var intersectNodePool:Array<IntersectNode> = [];
    static var horzSegmentPool:Array<HorzSegment> = [];
    static var horzJoinPool:Array<HorzJoin> = [];
    static var outRecPool:Array<OutRec> = [];

    // Tracking state
    static var trackingEnabled:Bool = false;
    static var trackedPoint64:Array<Point64Impl> = [];
    static var trackedPointD:Array<PointDImpl> = [];
    static var trackedOutPt:Array<OutPt> = [];
    static var trackedActive:Array<Active> = [];
    static var trackedVertex:Array<Vertex> = [];
    static var trackedLocalMinima:Array<LocalMinima> = [];
    static var trackedIntersectNode:Array<IntersectNode> = [];
    static var trackedHorzSegment:Array<HorzSegment> = [];
    static var trackedHorzJoin:Array<HorzJoin> = [];
    static var trackedOutRec:Array<OutRec> = [];

    /**
     * Start tracking all created objects for later recycling.
     * Call this before performing clipper operations.
     */
    public static function trackObjects():Void {
        if (trackingEnabled) {
            trace("Warning: trackObjects() called while already tracking");
        }
        trackingEnabled = true;
        // Clear tracking arrays in case of leftover state
        trackedPoint64.resize(0);
        trackedPointD.resize(0);
        trackedOutPt.resize(0);
        trackedActive.resize(0);
        trackedVertex.resize(0);
        trackedLocalMinima.resize(0);
        trackedIntersectNode.resize(0);
        trackedHorzSegment.resize(0);
        trackedHorzJoin.resize(0);
        trackedOutRec.resize(0);
    }

    /**
     * Recycle all tracked objects back to their pools.
     * Call this after you've copied the needed data from clipper results.
     * Objects become invalid after this call.
     */
    public static function recycleObjects():Void {
        // Move tracked objects to pools (using index-based iteration to avoid allocations on C++)
        for (i in 0...trackedPoint64.length) {
            point64Pool.push(trackedPoint64[i]);
        }
        for (i in 0...trackedPointD.length) {
            pointDPool.push(trackedPointD[i]);
        }
        for (i in 0...trackedOutPt.length) {
            outPtPool.push(trackedOutPt[i]);
        }
        for (i in 0...trackedActive.length) {
            activePool.push(trackedActive[i]);
        }
        for (i in 0...trackedVertex.length) {
            vertexPool.push(trackedVertex[i]);
        }
        for (i in 0...trackedLocalMinima.length) {
            localMinimaPool.push(trackedLocalMinima[i]);
        }
        for (i in 0...trackedIntersectNode.length) {
            intersectNodePool.push(trackedIntersectNode[i]);
        }
        for (i in 0...trackedHorzSegment.length) {
            horzSegmentPool.push(trackedHorzSegment[i]);
        }
        for (i in 0...trackedHorzJoin.length) {
            horzJoinPool.push(trackedHorzJoin[i]);
        }
        for (i in 0...trackedOutRec.length) {
            outRecPool.push(trackedOutRec[i]);
        }

        // Clear tracking arrays
        trackedPoint64.resize(0);
        trackedPointD.resize(0);
        trackedOutPt.resize(0);
        trackedActive.resize(0);
        trackedVertex.resize(0);
        trackedLocalMinima.resize(0);
        trackedIntersectNode.resize(0);
        trackedHorzSegment.resize(0);
        trackedHorzJoin.resize(0);
        trackedOutRec.resize(0);

        trackingEnabled = false;
    }

    /**
     * Clear all pools and tracking state.
     * Useful for testing or when you want to release pooled memory.
     */
    public static function clearPools():Void {
        point64Pool.resize(0);
        pointDPool.resize(0);
        outPtPool.resize(0);
        activePool.resize(0);
        vertexPool.resize(0);
        localMinimaPool.resize(0);
        intersectNodePool.resize(0);
        horzSegmentPool.resize(0);
        horzJoinPool.resize(0);
        outRecPool.resize(0);

        trackedPoint64.resize(0);
        trackedPointD.resize(0);
        trackedOutPt.resize(0);
        trackedActive.resize(0);
        trackedVertex.resize(0);
        trackedLocalMinima.resize(0);
        trackedIntersectNode.resize(0);
        trackedHorzSegment.resize(0);
        trackedHorzJoin.resize(0);
        trackedOutRec.resize(0);

        trackingEnabled = false;
    }

    // =========================================================================
    // Pool size getters (for testing)
    // =========================================================================

    public static inline function getPoint64PoolSize():Int {
        return point64Pool.length;
    }

    public static inline function getPointDPoolSize():Int {
        return pointDPool.length;
    }

    public static inline function getOutPtPoolSize():Int {
        return outPtPool.length;
    }

    public static inline function getActivePoolSize():Int {
        return activePool.length;
    }

    public static inline function getVertexPoolSize():Int {
        return vertexPool.length;
    }

    public static inline function getLocalMinimaPoolSize():Int {
        return localMinimaPool.length;
    }

    public static inline function getIntersectNodePoolSize():Int {
        return intersectNodePool.length;
    }

    public static inline function getHorzSegmentPoolSize():Int {
        return horzSegmentPool.length;
    }

    public static inline function getHorzJoinPoolSize():Int {
        return horzJoinPool.length;
    }

    public static inline function getOutRecPoolSize():Int {
        return outRecPool.length;
    }

    public static inline function isTracking():Bool {
        return trackingEnabled;
    }

    // =========================================================================
    // Internal acquire methods (get from pool or return null)
    // =========================================================================

    public static inline function acquirePoint64Impl():Null<Point64Impl> {
        return point64Pool.length > 0 ? point64Pool.pop() : null;
    }

    public static inline function acquirePointDImpl():Null<PointDImpl> {
        return pointDPool.length > 0 ? pointDPool.pop() : null;
    }

    public static inline function acquireOutPt():Null<OutPt> {
        return outPtPool.length > 0 ? outPtPool.pop() : null;
    }

    public static inline function acquireActive():Null<Active> {
        return activePool.length > 0 ? activePool.pop() : null;
    }

    public static inline function acquireVertex():Null<Vertex> {
        return vertexPool.length > 0 ? vertexPool.pop() : null;
    }

    public static inline function acquireLocalMinima():Null<LocalMinima> {
        return localMinimaPool.length > 0 ? localMinimaPool.pop() : null;
    }

    public static inline function acquireIntersectNode():Null<IntersectNode> {
        return intersectNodePool.length > 0 ? intersectNodePool.pop() : null;
    }

    public static inline function acquireHorzSegment():Null<HorzSegment> {
        return horzSegmentPool.length > 0 ? horzSegmentPool.pop() : null;
    }

    public static inline function acquireHorzJoin():Null<HorzJoin> {
        return horzJoinPool.length > 0 ? horzJoinPool.pop() : null;
    }

    public static inline function acquireOutRec():Null<OutRec> {
        return outRecPool.length > 0 ? outRecPool.pop() : null;
    }

    // =========================================================================
    // Internal track methods (add to tracking if enabled)
    // =========================================================================

    public static inline function trackPoint64(impl:Point64Impl):Void {
        if (trackingEnabled) {
            trackedPoint64.push(impl);
        }
    }

    public static inline function trackPointD(impl:PointDImpl):Void {
        if (trackingEnabled) {
            trackedPointD.push(impl);
        }
    }

    public static inline function trackOutPt(op:OutPt):Void {
        if (trackingEnabled) {
            trackedOutPt.push(op);
        }
    }

    public static inline function trackActive(a:Active):Void {
        if (trackingEnabled) {
            trackedActive.push(a);
        }
    }

    public static inline function trackVertex(v:Vertex):Void {
        if (trackingEnabled) {
            trackedVertex.push(v);
        }
    }

    public static inline function trackLocalMinima(lm:LocalMinima):Void {
        if (trackingEnabled) {
            trackedLocalMinima.push(lm);
        }
    }

    public static inline function trackIntersectNode(node:IntersectNode):Void {
        if (trackingEnabled) {
            trackedIntersectNode.push(node);
        }
    }

    public static inline function trackHorzSegment(hs:HorzSegment):Void {
        if (trackingEnabled) {
            trackedHorzSegment.push(hs);
        }
    }

    public static inline function trackHorzJoin(hj:HorzJoin):Void {
        if (trackingEnabled) {
            trackedHorzJoin.push(hj);
        }
    }

    public static inline function trackOutRec(or:OutRec):Void {
        if (trackingEnabled) {
            trackedOutRec.push(or);
        }
    }
}
