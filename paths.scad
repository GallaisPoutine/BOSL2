//////////////////////////////////////////////////////////////////////
// LibFile: paths.scad
//   Support for polygons and paths.
// Includes:
//   include <BOSL2/std.scad>
//////////////////////////////////////////////////////////////////////


// Section: Utility Functions


// Function: is_path()
// Usage:
//   is_path(list, [dim], [fast])
// Description:
//   Returns true if `list` is a path.  A path is a list of two or more numeric vectors (AKA points).
//   All vectors must of the same size, and may only contain numbers that are not inf or nan.
//   By default the vectors in a path must be 2d or 3d.  Set the `dim` parameter to specify a list
//   of allowed dimensions, or set it to `undef` to allow any dimension.  
// Example:
//   bool1 = is_path([[3,4],[5,6]]);    // Returns true
//   bool2 = is_path([[3,4]]);          // Returns false
//   bool3 = is_path([[3,4],[4,5]],2);  // Returns true
//   bool4 = is_path([[3,4,3],[5,4,5]],2);  // Returns false
//   bool5 = is_path([[3,4,3],[5,4,5]],2);  // Returns false
//   bool6 = is_path([[3,4,5],undef,[4,5,6]]);  // Returns false
//   bool7 = is_path([[3,5],[undef,undef],[4,5]]);  // Returns false
//   bool8 = is_path([[3,4],[5,6],[5,3]]);     // Returns true
//   bool9 = is_path([3,4,5,6,7,8]);           // Returns false
//   bool10 = is_path([[3,4],[5,6]], dim=[2,3]);// Returns true
//   bool11 = is_path([[3,4],[5,6]], dim=[1,3]);// Returns false
//   bool12 = is_path([[3,4],"hello"], fast=true); // Returns true
//   bool13 = is_path([[3,4],[3,4,5]]);            // Returns false
//   bool14 = is_path([[1,2,3,4],[2,3,4,5]]);      // Returns false
//   bool15 = is_path([[1,2,3,4],[2,3,4,5]],undef);// Returns true
// Arguments:
//   list = list to check
//   dim = list of allowed dimensions of the vectors in the path.  Default: [2,3]
//   fast = set to true for fast check that only looks at first entry.  Default: false
function is_path(list, dim=[2,3], fast=false) =
    fast
    ?   is_list(list) && is_vector(list[0]) 
    :   is_matrix(list) 
        && len(list)>1 
        && len(list[0])>0
        && (is_undef(dim) || in_list(len(list[0]), force_list(dim)));


// Function: is_closed_path()
// Usage:
//   is_closed_path(path, [eps]);
// Description:
//   Returns true if the first and last points in the given path are coincident.
function is_closed_path(path, eps=EPSILON) = approx(path[0], path[len(path)-1], eps=eps);


// Function: close_path()
// Usage:
//   close_path(path);
// Description:
//   If a path's last point does not coincide with its first point, closes the path so it does.
function close_path(path, eps=EPSILON) =
    is_closed_path(path,eps=eps)? path : concat(path,[path[0]]);


// Function: cleanup_path()
// Usage:
//   cleanup_path(path);
// Description:
//   If a path's last point coincides with its first point, deletes the last point in the path.
function cleanup_path(path, eps=EPSILON) =
    is_closed_path(path,eps=eps)? [for (i=[0:1:len(path)-2]) path[i]] : path;


/// Internal Function: _path_select()
/// Usage:
///   _path_select(path,s1,u1,s2,u2,[closed]):
/// Description:
///   Returns a portion of a path, from between the `u1` part of segment `s1`, to the `u2` part of
///   segment `s2`.  Both `u1` and `u2` are values between 0.0 and 1.0, inclusive, where 0 is the start
///   of the segment, and 1 is the end.  Both `s1` and `s2` are integers, where 0 is the first segment.
/// Arguments:
///   path = The path to get a section of.
///   s1 = The number of the starting segment.
///   u1 = The proportion along the starting segment, between 0.0 and 1.0, inclusive.
///   s2 = The number of the ending segment.
///   u2 = The proportion along the ending segment, between 0.0 and 1.0, inclusive.
///   closed = If true, treat path as a closed polygon.
function _path_select(path, s1, u1, s2, u2, closed=false) =
    let(
        lp = len(path),
        l = lp-(closed?0:1),
        u1 = s1<0? 0 : s1>l? 1 : u1,
        u2 = s2<0? 0 : s2>l? 1 : u2,
        s1 = constrain(s1,0,l),
        s2 = constrain(s2,0,l),
        pathout = concat(
            (s1<l && u1<1)? [lerp(path[s1],path[(s1+1)%lp],u1)] : [],
            [for (i=[s1+1:1:s2]) path[i]],
            (s2<l && u2>0)? [lerp(path[s2],path[(s2+1)%lp],u2)] : []
        )
    ) pathout;


// Function: path_merge_collinear()
// Description:
//   Takes a path and removes unnecessary sequential collinear points.
// Usage:
//   path_merge_collinear(path, [eps])
// Arguments:
//   path = A list of path points of any dimension.
//   closed = treat as closed polygon.  Default: false
//   eps = Largest positional variance allowed.  Default: `EPSILON` (1-e9)
function path_merge_collinear(path, closed=false, eps=EPSILON) =
    assert( is_path(path), "Invalid path." )
    assert( is_undef(eps) || (is_finite(eps) && (eps>=0) ), "Invalid tolerance." )    
    len(path)<=2 ? path :
    let(
        indices = [
            0,
            for (i=[1:1:len(path)-(closed?1:2)]) 
                if (!is_collinear(path[i-1], path[i], select(path,i+1), eps=eps)) i, 
            if (!closed) len(path)-1 
        ]
    ) [for (i=indices) path[i]];



// Section: Path length calculation


// Function: path_length()
// Usage:
//   path_length(path,[closed])
// Description:
//   Returns the length of the path.
// Arguments:
//   path = The list of points of the path to measure.
//   closed = true if the path is closed.  Default: false
// Example:
//   path = [[0,0], [5,35], [60,-25], [80,0]];
//   echo(path_length(path));
function path_length(path,closed=false) =
    len(path)<2? 0 :
    sum([for (i = [0:1:len(path)-2]) norm(path[i+1]-path[i])])+(closed?norm(path[len(path)-1]-path[0]):0);


// Function: path_segment_lengths()
// Usage:
//   path_segment_lengths(path,[closed])
// Description:
//   Returns list of the length of each segment in a path
// Arguments:
//   path = path to measure
//   closed = true if the path is closed.  Default: false
function path_segment_lengths(path, closed=false) =
    [
        for (i=[0:1:len(path)-2]) norm(path[i+1]-path[i]),
        if (closed) norm(path[0]-last(path))
    ]; 


// Function: path_length_fractions()
// Usage:
//   fracs = path_length_fractions(path, [closed]);
// Description:
//    Returns the distance fraction of each point in the path along the path, so the first
//    point is zero and the final point is 1.  If the path is closed the length of the output
//    will have one extra point because of the final connecting segment that connects the last
//    point of the path to the first point.
// Arguments:
//    path = path to operate on
//    closed = set to true if path is closed.  Default: false
function path_length_fractions(path, closed=false) =
    assert(is_path(path))
    assert(is_bool(closed))
    let(
        lengths = [
            0,
            for (i=[0:1:len(path)-(closed?1:2)])
                norm(select(path,i+1)-path[i])
        ],
        partial_len = cumsum(lengths),
        total_len = last(partial_len)
    ) partial_len / total_len;



/// Internal Function: _path_self_intersections()
/// Usage:
///   isects = _path_self_intersections(path, [closed], [eps]);
/// Description:
///   Locates all self intersection points of the given path.  Returns a list of intersections, where
///   each intersection is a list like [POINT, SEGNUM1, PROPORTION1, SEGNUM2, PROPORTION2] where
///   POINT is the coordinates of the intersection point, SEGNUMs are the integer indices of the
///   intersecting segments along the path, and the PROPORTIONS are the 0.0 to 1.0 proportions
///   of how far along those segments they intersect at.  A proportion of 0.0 indicates the start
///   of the segment, and a proportion of 1.0 indicates the end of the segment.
///   .
///   Note that this function does not return self-intersecting segments, only the points
///   where non-parallel segments intersect.  
/// Arguments:
///   path = The path to find self intersections of.
///   closed = If true, treat path like a closed polygon.  Default: true
///   eps = The epsilon error value to determine whether two points coincide.  Default: `EPSILON` (1e-9)
/// Example(2D):
///   path = [
///       [-100,100], [0,-50], [100,100], [100,-100], [0,50], [-100,-100]
///   ];
///   isects = _path_self_intersections(path, closed=true);
///   // isects == [[[-33.3333, 0], 0, 0.666667, 4, 0.333333], [[33.3333, 0], 1, 0.333333, 3, 0.666667]]
///   stroke(path, closed=true, width=1);
///   for (isect=isects) translate(isect[0]) color("blue") sphere(d=10);
function _path_self_intersections(path, closed=true, eps=EPSILON) =
    let(
        path = closed ? close_path(path,eps=eps) : path,
        plen = len(path)
    )
    [ for (i = [0:1:plen-3]) let(
          a1 = path[i],
          a2 = path[i+1], 
          seg_normal = unit([-(a2-a1).y, (a2-a1).x],[0,0]),
          vals = path*seg_normal,
          ref  = a1*seg_normal,
            // The value of vals[j]-ref is positive if vertex j is one one side of the
            // line [a1,a2] and negative on the other side. Only a segment with opposite
            // signs at its two vertices can have an intersection with segment
            // [a1,a2]. The variable signals is zero when abs(vals[j]-ref) is less than
            // eps and the sign of vals[j]-ref otherwise.  
          signals = [for(j=[i+2:1:plen-(i==0 && closed? 2: 1)]) vals[j]-ref >  eps ? 1
                                                              : vals[j]-ref < -eps ? -1
                                                              : 0] 
        )
        if(max(signals)>=0 && min(signals)<=0 ) // some remaining edge intersects line [a1,a2]
        for(j=[i+2:1:plen-(i==0 && closed? 3: 2)])
            if( signals[j-i-2]*signals[j-i-1]<=0 ) let( // segm [b1,b2] intersects line [a1,a2]
                b1 = path[j],
                b2 = path[j+1],
                isect = _general_line_intersection([a1,a2],[b1,b2],eps=eps) 
            )
            if (isect 
//                && isect[1]> (i==0 && !closed? -eps: 0)  // Apparently too strict
                && isect[1]>=-eps
                && isect[1]<= 1+eps
//                && isect[2]> 0
                && isect[2]>= -eps 
                && isect[2]<= 1+eps)
                [isect[0], i, isect[1], j, isect[2]]
    ];



// Section: Resampling: changing the number of points in a path


// Input `data` is a list that sums to an integer. 
// Returns rounded version of input data so that every 
// entry is rounded to an integer and the sum is the same as
// that of the input.  Works by rounding an entry in the list
// and passing the rounding error forward to the next entry.
// This will generally distribute the error in a uniform manner. 
function _sum_preserving_round(data, index=0) =
    index == len(data)-1 ? list_set(data, len(data)-1, round(data[len(data)-1])) :
    let(
        newval = round(data[index]),
        error = newval - data[index]
    ) _sum_preserving_round(
        list_set(data, [index,index+1], [newval, data[index+1]-error]),
        index+1
    );


// Function: subdivide_path()
// Usage:
//   newpath = subdivide_path(path, [N|refine], method, [closed], [exact]);
// Description:
//   Takes a path as input (closed or open) and subdivides the path to produce a more
//   finely sampled path.  The new points can be distributed proportional to length
//   (`method="length"`) or they can be divided up evenly among all the path segments
//   (`method="segment"`).  If the extra points don't fit evenly on the path then the
//   algorithm attempts to distribute them uniformly.  The `exact` option requires that
//   the final length is exactly as requested.  If you set it to `false` then the
//   algorithm will favor uniformity and the output path may have a different number of
//   points due to rounding error.
//   .
//   With the `"segment"` method you can also specify a vector of lengths.  This vector, 
//   `N` specfies the desired point count on each segment: with vector input, `subdivide_path`
//   attempts to place `N[i]-1` points on segment `i`.  The reason for the -1 is to avoid
//   double counting the endpoints, which are shared by pairs of segments, so that for
//   a closed polygon the total number of points will be sum(N).  Note that with an open
//   path there is an extra point at the end, so the number of points will be sum(N)+1. 
// Arguments:
//   path = path to subdivide
//   N = scalar total number of points desired or with `method="segment"` can be a vector requesting `N[i]-1` points on segment i.
//   refine = number of points to add each segment.
//   closed = set to false if the path is open.  Default: True
//   exact = if true return exactly the requested number of points, possibly sacrificing uniformity.  If false, return uniform point sample that may not match the number of points requested.  Default: True
//   method = One of `"length"` or `"segment"`.  If `"length"`, adds vertices evenly along the total path length.  If `"segment"`, adds points evenly among the segments.  Default: `"length"`
// Example(2D):
//   mypath = subdivide_path(square([2,2],center=true), 12);
//   move_copies(mypath)circle(r=.1,$fn=32);
// Example(2D):
//   mypath = subdivide_path(square([8,2],center=true), 12);
//   move_copies(mypath)circle(r=.2,$fn=32);
// Example(2D):
//   mypath = subdivide_path(square([8,2],center=true), 12, method="segment");
//   move_copies(mypath)circle(r=.2,$fn=32);
// Example(2D):
//   mypath = subdivide_path(square([2,2],center=true), 17, closed=false);
//   move_copies(mypath)circle(r=.1,$fn=32);
// Example(2D): Specifying different numbers of points on each segment
//   mypath = subdivide_path(hexagon(side=2), [2,3,4,5,6,7], method="segment");
//   move_copies(mypath)circle(r=.1,$fn=32);
// Example(2D): Requested point total is 14 but 15 points output due to extra end point
//   mypath = subdivide_path(pentagon(side=2), [3,4,3,4], method="segment", closed=false);
//   move_copies(mypath)circle(r=.1,$fn=32);
// Example(2D): Since 17 is not divisible by 5, a completely uniform distribution is not possible. 
//   mypath = subdivide_path(pentagon(side=2), 17);
//   move_copies(mypath)circle(r=.1,$fn=32);
// Example(2D): With `exact=false` a uniform distribution, but only 15 points
//   mypath = subdivide_path(pentagon(side=2), 17, exact=false);
//   move_copies(mypath)circle(r=.1,$fn=32);
// Example(2D): With `exact=false` you can also get extra points, here 20 instead of requested 18
//   mypath = subdivide_path(pentagon(side=2), 18, exact=false);
//   move_copies(mypath)circle(r=.1,$fn=32);
// Example(FlatSpin,VPD=15,VPT=[0,0,1.5]): Three-dimensional paths also work
//   mypath = subdivide_path([[0,0,0],[2,0,1],[2,3,2]], 12);
//   move_copies(mypath)sphere(r=.1,$fn=32);
function subdivide_path(path, N, refine, closed=true, exact=true, method="length") =
    assert(is_path(path))
    assert(method=="length" || method=="segment")
    assert(num_defined([N,refine]),"Must give exactly one of N and refine")
    let(
        N = !is_undef(N)? N :
            !is_undef(refine)? len(path) * refine :
            undef
    )
    assert((is_num(N) && N>0) || is_vector(N),"Parameter N to subdivide_path must be postive number or vector")
    let(
        count = len(path) - (closed?0:1), 
        add_guess = method=="segment"? (
                is_list(N)? (
                    assert(len(N)==count,"Vector parameter N to subdivide_path has the wrong length")
                    add_scalar(N,-1)
                ) : repeat((N-len(path)) / count, count)
            ) : // method=="length"
            assert(is_num(N),"Parameter N to subdivide path must be a number when method=\"length\"")
            let(
                path_lens = concat(
                    [ for (i = [0:1:len(path)-2]) norm(path[i+1]-path[i]) ],
                    closed? [norm(path[len(path)-1]-path[0])] : []
                ),
                add_density = (N - len(path)) / sum(path_lens)
            )
            path_lens * add_density,
        add = exact? _sum_preserving_round(add_guess) :
            [for (val=add_guess) round(val)]
    ) concat(
        [
            for (i=[0:1:count]) each [
                for(j=[0:1:add[i]])
                lerp(path[i],select(path,i+1), j/(add[i]+1))
            ]
        ],
        closed? [] : [last(path)]
    );



// Function: subdivide_long_segments()
// Topics: Paths, Path Subdivision
// See Also: subdivide_path(), subdivide_and_slice(), jittered_poly()
// Usage:
//   spath = subdivide_long_segments(path, maxlen, [closed=]);
// Description:
//   Evenly subdivides long `path` segments until they are all shorter than `maxlen`.
// Arguments:
//   path = The path to subdivide.
//   maxlen = The maximum allowed path segment length.
//   ---
//   closed = If true, treat path like a closed polygon.  Default: true
// Example(2D):
//   path = pentagon(d=100);
//   spath = subdivide_long_segments(path, 10, closed=true);
//   stroke(path,width=2,closed=true);
//   color("red") move_copies(path) circle(d=9,$fn=12);
//   color("blue") move_copies(spath) circle(d=5,$fn=12);
function subdivide_long_segments(path, maxlen, closed=false) =
    assert(is_path(path))
    assert(is_finite(maxlen))
    assert(is_bool(closed))
    [
        for (p=pair(path,closed)) let(
            steps = ceil(norm(p[1]-p[0])/maxlen)
        ) each lerpn(p[0], p[1], steps, false),
        if (!closed) last(path)
    ];



// Function: resample_path()
// Usage:
//   newpath = resample_path(path, N|spacing, [closed]);
// Description:
//   Compute a uniform resampling of the input path.  If you specify `N` then the output path will have N
//   points spaced uniformly (by linear interpolation along the input path segments).  The only points of the
//   input path that are guaranteed to appear in the output path are the starting and ending points.
//   If you specify `spacing` then the length you give will be rounded to the nearest spacing that gives
//   a uniform sampling of the path and the resulting uniformly sampled path is returned.
//   Note that because this function operates on a discrete input path the quality of the output depends on
//   the sampling of the input.  If you want very accurate output, use a lot of points for the input.
// Arguments:
//   path = path to resample
//   N = Number of points in output
//   spacing = Approximate spacing desired
//   closed = set to true if path is closed.  Default: false
function resample_path(path, N, spacing, closed=false) =
   assert(is_path(path))
   assert(num_defined([N,spacing])==1,"Must define exactly one of N and spacing")
   assert(is_bool(closed))
   let(
       length = path_length(path,closed),
       // In the open path case decrease N by 1 so that we don't try to get
       // path_cut to return the endpoint (which might fail due to rounding)
       // Add last point later
       N = is_def(N) ? N-(closed?0:1) : round(length/spacing),
       distlist = lerpn(0,length,N,false), 
       cuts = _path_cut_points(path, distlist, closed=closed)
   )
   [ each subindex(cuts,0),
     if (!closed) last(path)     // Then add last point here
   ];





// Section: Path Geometry

// Function: is_path_simple()
// Usage:
//   bool = is_path_simple(path, [closed], [eps]);
// Description:
//   Returns true if the path is simple, meaning that it has no self-intersections.
//   Repeated points are not considered self-intersections: a path with such points can
//   still be simple.  
//   If closed is set to true then treat the path as a polygon.
// Arguments:
//   path = path to check
//   closed = set to true to treat path as a polygon.  Default: false
//   eps = Epsilon error value used for determine if points coincide.  Default: `EPSILON` (1e-9)
function is_path_simple(path, closed=false, eps=EPSILON) =
    [for(i=[0:1:len(path)-(closed?2:3)])
         let(v1=path[i+1]-path[i],
             v2=select(path,i+2)-path[i+1],
             normv1 = norm(v1),
             normv2 = norm(v2)
             )
         if (approx(v1*v2/normv1/normv2,-1)) 1]  == [] 
    &&
    _path_self_intersections(path,closed=closed,eps=eps) == [];


// Function: path_closest_point()
// Usage:
//   path_closest_point(path, pt);
// Description:
//   Finds the closest path segment, and point on that segment to the given point.
//   Returns `[SEGNUM, POINT]`
// Arguments:
//   path = The path to find the closest point on.
//   pt = the point to find the closest point to.
// Example(2D):
//   path = circle(d=100,$fn=6);
//   pt = [20,10];
//   closest = path_closest_point(path, pt);
//   stroke(path, closed=true);
//   color("blue") translate(pt) circle(d=3, $fn=12);
//   color("red") translate(closest[1]) circle(d=3, $fn=12);
function path_closest_point(path, pt) =
    let(
        pts = [for (seg=idx(path)) line_closest_point(select(path,seg,seg+1),pt,SEGMENT)],
        dists = [for (p=pts) norm(p-pt)],
        min_seg = min_index(dists)
    ) [min_seg, pts[min_seg]];


// Function: path_tangents()
// Usage:
//   tangs = path_tangents(path, [closed], [uniform]);
// Description:
//   Compute the tangent vector to the input path.  The derivative approximation is described in deriv().
//   The returns vectors will be normalized to length 1.  If any derivatives are zero then
//   the function fails with an error.  If you set `uniform` to false then the sampling is
//   assumed to be non-uniform and the derivative is computed with adjustments to produce corrected
//   values.
// Arguments:
//   path = path to find the tagent vectors for
//   closed = set to true of the path is closed.  Default: false
//   uniform = set to false to correct for non-uniform sampling.  Default: true
// Example(2D): A shape with non-uniform sampling gives distorted derivatives that may be undesirable.  Note that derivatives tilt towards the long edges of the rectangle.  
//   rect = square([10,3]);
//   tangents = path_tangents(rect,closed=true);
//   stroke(rect,closed=true, width=0.25);
//   color("purple")
//       for(i=[0:len(tangents)-1])
//           stroke([rect[i]-tangents[i], rect[i]+tangents[i]],width=.25, endcap2="arrow2");
// Example(2D): Setting uniform to false corrects the distorted derivatives for this example:
//   rect = square([10,3]);
//   tangents = path_tangents(rect,closed=true,uniform=false);
//   stroke(rect,closed=true, width=0.25);
//   color("purple")
//       for(i=[0:len(tangents)-1])
//           stroke([rect[i]-tangents[i], rect[i]+tangents[i]],width=.25, endcap2="arrow2");
function path_tangents(path, closed=false, uniform=true) =
    assert(is_path(path))
    !uniform ? [for(t=deriv(path,closed=closed, h=path_segment_lengths(path,closed))) unit(t)]
             : [for(t=deriv(path,closed=closed)) unit(t)];


// Function: path_normals()
// Usage:
//   norms = path_normals(path, [tangents], [closed]);
// Description:
//   Compute the normal vector to the input path.  This vector is perpendicular to the
//   path tangent and lies in the plane of the curve.  For 3d paths we define the plane of the curve
//   at path point i to be the plane defined by point i and its two neighbors.  At the endpoints of open paths
//   we use the three end points.  For 3d paths the computed normal is the one lying in this plane that points
//   towards the center of curvature at that path point.  For 2d paths, which lie in the xy plane, the normal
//   is the path pointing to the right of the direction the path is traveling.  If points are collinear then
//   a 3d path has no center of curvature, and hence the 
//   normal is not uniquely defined.  In this case the function issues an error.
//   For 2d paths the plane is always defined so the normal fails to exist only
//   when the derivative is zero (in the case of repeated points).
function path_normals(path, tangents, closed=false) =
    assert(is_path(path,[2,3]))
    assert(is_bool(closed))
    let(
         tangents = default(tangents, path_tangents(path,closed)),
         dim=len(path[0])
    )
    assert(is_path(tangents) && len(tangents[0])==dim,"Dimensions of path and tangents must match")
    [
     for(i=idx(path))
         let(
             pts = i==0 ? (closed? select(path,-1,1) : select(path,0,2))
                 : i==len(path)-1 ? (closed? select(path,i-1,i+1) : select(path,i-2,i))
                 : select(path,i-1,i+1)
        )
        dim == 2 ? [tangents[i].y,-tangents[i].x]
                 : let( v=cross(cross(pts[1]-pts[0], pts[2]-pts[0]),tangents[i]))
                   assert(norm(v)>EPSILON, "3D path contains collinear points")
                   unit(v)
    ];


// Function: path_curvature()
// Usage:
//   curvs = path_curvature(path, [closed]);
// Description:
//   Numerically estimate the curvature of the path (in any dimension). 
function path_curvature(path, closed=false) =
    let( 
        d1 = deriv(path, closed=closed),
        d2 = deriv2(path, closed=closed)
    ) [
        for(i=idx(path))
        sqrt(
            sqr(norm(d1[i])*norm(d2[i])) -
            sqr(d1[i]*d2[i])
        ) / pow(norm(d1[i]),3)
    ];


// Function: path_torsion()
// Usage:
//   tortions = path_torsion(path, [closed]);
// Description:
//   Numerically estimate the torsion of a 3d path.  
function path_torsion(path, closed=false) =
    let(
        d1 = deriv(path,closed=closed),
        d2 = deriv2(path,closed=closed),
        d3 = deriv3(path,closed=closed)
    ) [
        for (i=idx(path)) let(
            crossterm = cross(d1[i],d2[i])
        ) crossterm * d3[i] / sqr(norm(crossterm))
    ];


// Section: Modifying paths

// Function: path_chamfer_and_rounding()
// Usage:
//   path2 = path_chamfer_and_rounding(path, [closed], [chamfer], [rounding]);
// Description:
//   Rounds or chamfers corners in the given path.
// Arguments:
//   path = The path to chamfer and/or round.
//   closed = If true, treat path like a closed polygon.  Default: true
//   chamfer = The length of the chamfer faces at the corners.  If given as a list of numbers, gives individual chamfers for each corner, from first to last.  Default: 0 (no chamfer)
//   rounding = The rounding radius for the corners.  If given as a list of numbers, gives individual radii for each corner, from first to last.  Default: 0 (no rounding)
// Example(2D): Chamfering a Path
//   path = star(5, step=2, d=100);
//   path2 = path_chamfer_and_rounding(path, closed=true, chamfer=5);
//   stroke(path2, closed=true);
// Example(2D): Per-Corner Chamfering
//   path = star(5, step=2, d=100);
//   chamfs = [for (i=[0:1:4]) each 3*[i,i]];
//   path2 = path_chamfer_and_rounding(path, closed=true, chamfer=chamfs);
//   stroke(path2, closed=true);
// Example(2D): Rounding a Path
//   path = star(5, step=2, d=100);
//   path2 = path_chamfer_and_rounding(path, closed=true, rounding=5);
//   stroke(path2, closed=true);
// Example(2D): Per-Corner Chamfering
//   path = star(5, step=2, d=100);
//   rs = [for (i=[0:1:4]) each 2*[i,i]];
//   path2 = path_chamfer_and_rounding(path, closed=true, rounding=rs);
//   stroke(path2, closed=true);
// Example(2D): Mixing Chamfers and Roundings
//   path = star(5, step=2, d=100);
//   chamfs = [for (i=[0:4]) each [5,0]];
//   rs = [for (i=[0:4]) each [0,10]];
//   path2 = path_chamfer_and_rounding(path, closed=true, chamfer=chamfs, rounding=rs);
//   stroke(path2, closed=true);
function path_chamfer_and_rounding(path, closed=true, chamfer, rounding) =
  let (
    path = deduplicate(path,closed=true),
    lp = len(path),
    chamfer = is_undef(chamfer)? repeat(0,lp) :
      is_vector(chamfer)? list_pad(chamfer,lp,0) :
      is_num(chamfer)? repeat(chamfer,lp) :
      assert(false, "Bad chamfer value."),
    rounding = is_undef(rounding)? repeat(0,lp) :
      is_vector(rounding)? list_pad(rounding,lp,0) :
      is_num(rounding)? repeat(rounding,lp) :
      assert(false, "Bad rounding value."),
    corner_paths = [
      for (i=(closed? [0:1:lp-1] : [1:1:lp-2])) let(
        p1 = select(path,i-1),
        p2 = select(path,i),
        p3 = select(path,i+1)
      )
      chamfer[i]  > 0? _corner_chamfer_path(p1, p2, p3, side=chamfer[i]) :
      rounding[i] > 0? _corner_roundover_path(p1, p2, p3, r=rounding[i]) :
      [p2]
    ],
    out = [
      if (!closed) path[0],
      for (i=(closed? [0:1:lp-1] : [1:1:lp-2])) let(
        p1 = select(path,i-1),
        p2 = select(path,i),
        crn1 = select(corner_paths,i-1),
        crn2 = corner_paths[i],
        l1 = norm(last(crn1)-p1),
        l2 = norm(crn2[0]-p2),
        needed = l1 + l2,
        seglen = norm(p2-p1),
        check = assert(seglen >= needed, str("Path segment ",i," is too short to fulfill rounding/chamfering for the adjacent corners."))
      ) each crn2,
      if (!closed) last(path)
    ]
  ) deduplicate(out);


function _corner_chamfer_path(p1, p2, p3, dist1, dist2, side, angle) = 
  let(
    v1 = unit(p1 - p2),
    v2 = unit(p3 - p2),
    n = vector_axis(v1,v2),
    ang = vector_angle(v1,v2),
    path = (is_num(dist1) && is_undef(dist2) && is_undef(side))? (
      // dist1 & optional angle
      assert(dist1 > 0)
      let(angle = default(angle,(180-ang)/2))
      assert(is_num(angle))
      assert(angle > 0 && angle < 180)
      let(
        pta = p2 + dist1*v1,
        a3 = 180 - angle - ang
      ) assert(a3>0, "Angle too extreme.")
      let(
        side = sin(angle) * dist1/sin(a3),
        ptb = p2 + side*v2
      ) [pta, ptb]
    ) : (is_undef(dist1) && is_num(dist2) && is_undef(side))? (
      // dist2 & optional angle
      assert(dist2 > 0)
      let(angle = default(angle,(180-ang)/2))
      assert(is_num(angle))
      assert(angle > 0 && angle < 180)
      let(
        ptb = p2 + dist2*v2,
        a3 = 180 - angle - ang
      ) assert(a3>0, "Angle too extreme.")
      let(
        side = sin(angle) * dist2/sin(a3),
        pta = p2 + side*v1
      ) [pta, ptb]
    ) : (is_undef(dist1) && is_undef(dist2) && is_num(side))? (
      // side & optional angle
      assert(side > 0)
      let(angle = default(angle,(180-ang)/2))
      assert(is_num(angle))
      assert(angle > 0 && angle < 180)
      let(
        a3 = 180 - angle - ang
      ) assert(a3>0, "Angle too extreme.")
      let(
        dist1 = sin(a3) * side/sin(ang),
        dist2 = sin(angle) * side/sin(ang),
        pta = p2 + dist1*v1,
        ptb = p2 + dist2*v2
      ) [pta, ptb]
    ) : (is_num(dist1) && is_num(dist2) && is_undef(side) && is_undef(side))? (
      // dist1 & dist2
      assert(dist1 > 0)
      assert(dist2 > 0)
      let(
        pta = p2 + dist1*v1,
        ptb = p2 + dist2*v2
      ) [pta, ptb]
    ) : (
      assert(false,"Bad arguments.")
    )
  ) path;


function _corner_roundover_path(p1, p2, p3, r, d) = 
  let(
    r = get_radius(r=r,d=d,dflt=undef),
    res = circle_2tangents(p1, p2, p3, r=r, tangents=true),
    cp = res[0],
    n = res[1],
    tp1 = res[2],
    ang = res[4]+res[5],
    steps = floor(segs(r)*ang/360+0.5),
    step = ang / steps,
    path = [for (i=[0:1:steps]) move(cp, p=rot(a=-i*step, v=n, p=tp1-cp))]
  ) path;




// Section: Breaking paths up into subpaths


/// Internal Function: _path_cut_points()
///
/// Usage:
///   cuts = _path_cut_points(path, dists, [closed=], [direction=]);
///
/// Description:
///   Cuts a path at a list of distances from the first point in the path.  Returns a list of the cut
///   points and indices of the next point in the path after that point.  So for example, a return
///   value entry of [[2,3], 5] means that the cut point was [2,3] and the next point on the path after
///   this point is path[5].  If the path is too short then _path_cut_points returns undef.  If you set
///   `direction` to true then `_path_cut_points` will also return the tangent vector to the path and a normal
///   vector to the path.  It tries to find a normal vector that is coplanar to the path near the cut
///   point.  If this fails it will return a normal vector parallel to the xy plane.  The output with
///   direction vectors will be `[point, next_index, tangent, normal]`.
///   .
///   If you give the very last point of the path as a cut point then the returned index will be
///   one larger than the last index (so it will not be a valid index).  If you use the closed
///   option then the returned index will be equal to the path length for cuts along the closing
///   path segment, and if you give a point equal to the path length you will get an
///   index of len(path)+1 for the index.  
///
/// Arguments:
///   path = path to cut
///   dists = distances where the path should be cut (a list) or a scalar single distance
///   ---
///   closed = set to true if the curve is closed.  Default: false
///   direction = set to true to return direction vectors.  Default: false
///
/// Example(NORENDER):
///   square=[[0,0],[1,0],[1,1],[0,1]];
///   _path_cut_points(square, [.5,1.5,2.5]);   // Returns [[[0.5, 0], 1], [[1, 0.5], 2], [[0.5, 1], 3]]
///   _path_cut_points(square, [0,1,2,3]);      // Returns [[[0, 0], 1], [[1, 0], 2], [[1, 1], 3], [[0, 1], 4]]
///   _path_cut_points(square, [0,0.8,1.6,2.4,3.2], closed=true);  // Returns [[[0, 0], 1], [[0.8, 0], 1], [[1, 0.6], 2], [[0.6, 1], 3], [[0, 0.8], 4]]
///   _path_cut_points(square, [0,0.8,1.6,2.4,3.2]);               // Returns [[[0, 0], 1], [[0.8, 0], 1], [[1, 0.6], 2], [[0.6, 1], 3], undef]
function _path_cut_points(path, dists, closed=false, direction=false) =
    let(long_enough = len(path) >= (closed ? 3 : 2))
    assert(long_enough,len(path)<2 ? "Two points needed to define a path" : "Closed path must include three points")
    is_num(dists) ? _path_cut_points(path, [dists],closed, direction)[0] :
    assert(is_vector(dists))
    assert(list_increasing(dists), "Cut distances must be an increasing list")
    let(cuts = _path_cut_points_recurse(path,dists,closed))
    !direction
       ? cuts
       : let(
             dir = _path_cuts_dir(path, cuts, closed),
             normals = _path_cuts_normals(path, cuts, dir, closed)
         )
         hstack(cuts, array_group(dir,1), array_group(normals,1));

// Main recursive path cut function
function _path_cut_points_recurse(path, dists, closed=false, pind=0, dtotal=0, dind=0, result=[]) =
    dind == len(dists) ? result :
    let(
        lastpt = len(result)==0? [] : last(result)[0],       // location of last cut point
        dpartial = len(result)==0? 0 : norm(lastpt-select(path,pind)),  // remaining length in segment
        nextpoint = dists[dind] < dpartial+dtotal  // Do we have enough length left on the current segment?
           ? [lerp(lastpt,select(path,pind),(dists[dind]-dtotal)/dpartial),pind] 
           : _path_cut_single(path, dists[dind]-dtotal-dpartial, closed, pind)
    ) 
    _path_cut_points_recurse(path, dists, closed, nextpoint[1], dists[dind],dind+1, concat(result, [nextpoint]));


// Search for a single cut point in the path
function _path_cut_single(path, dist, closed=false, ind=0, eps=1e-7) =
    // If we get to the very end of the path (ind is last point or wraparound for closed case) then
    // check if we are within epsilon of the final path point.  If not we're out of path, so we fail
    ind==len(path)-(closed?0:1) ?
       assert(dist<eps,"Path is too short for specified cut distance")
       [select(path,ind),ind+1]
    :let(d = norm(path[ind]-select(path,ind+1))) d > dist ?
        [lerp(path[ind],select(path,ind+1),dist/d), ind+1] :
        _path_cut_single(path, dist-d,closed, ind+1, eps);

// Find normal directions to the path, coplanar to local part of the path
// Or return a vector parallel to the x-y plane if the above fails
function _path_cuts_normals(path, cuts, dirs, closed=false) =
    [for(i=[0:len(cuts)-1])
        len(path[0])==2? [-dirs[i].y, dirs[i].x]
          : 
            let(
                plane = len(path)<3 ? undef :
                let(start = max(min(cuts[i][1],len(path)-1),2)) _path_plane(path, start, start-2)
            )
            plane==undef?
                ( dirs[i].x==0 && dirs[i].y==0 ? [1,0,0]  // If it's z direction return x vector
                                               : unit([-dirs[i].y, dirs[i].x,0])) // otherwise perpendicular to projection
                : unit(cross(dirs[i],cross(plane[0],plane[1])))
    ];

// Scan from the specified point (ind) to find a noncoplanar triple to use
// to define the plane of the path.
function _path_plane(path, ind, i,closed) =
    i<(closed?-1:0) ? undef :
    !is_collinear(path[ind],path[ind-1], select(path,i))?
        [select(path,i)-path[ind-1],path[ind]-path[ind-1]] :
        _path_plane(path, ind, i-1);

// Find the direction of the path at the cut points
function _path_cuts_dir(path, cuts, closed=false, eps=1e-2) =
    [for(ind=[0:len(cuts)-1])
        let(
            zeros = path[0]*0,
            nextind = cuts[ind][1],
            nextpath = unit(select(path, nextind+1)-select(path, nextind),zeros),
            thispath = unit(select(path, nextind) - select(path,nextind-1),zeros),
            lastpath = unit(select(path,nextind-1) - select(path, nextind-2),zeros),
            nextdir =
                nextind==len(path) && !closed? lastpath :
                (nextind<=len(path)-2 || closed) && approx(cuts[ind][0], path[nextind],eps)
                   ? unit(nextpath+thispath)
              : (nextind>1 || closed) && approx(cuts[ind][0],select(path,nextind-1),eps)
                   ? unit(thispath+lastpath)
              :  thispath
        ) nextdir
    ];


// Function: path_cut()
// Topics: Paths
// See Also: split_path_at_self_crossings()
// Usage:
//    path_list = path_cut(path, cutdist, [closed=]);
// Description:
//    Given a list of distances in `cutdist`, cut the path into
//    subpaths at those lengths, returning a list of paths.
//    If the input path is closed then the final path will include the
//    original starting point.  The list of cut distances must be
//    in ascending order and should not include the endpoints: 0 
//    or len(path).  If you repeat a distance you will get an
//    empty list in that position in the output.  If you give an
//    empty cutdist array you will get the input path as output
//    (without the final vertex doubled in the case of a closed path).
// Arguments:
//   path = The original path to split.
//   cutdist = Distance or list of distances where path is cut
//   closed = If true, treat the path as a closed polygon.
// Example(2D,NoAxes):
//   path = circle(d=100);
//   segs = path_cut(path, [50, 200], closed=true);
//   rainbow(segs) stroke($item, endcaps="butt", width=3);
function path_cut(path,cutdist,closed) =
  is_num(cutdist) ? path_cut(path,[cutdist],closed) :
  assert(is_vector(cutdist))
  assert(last(cutdist)<path_length(path,closed=closed),"Cut distances must be smaller than the path length")
  assert(cutdist[0]>0, "Cut distances must be strictly positive")
  let(
      cutlist = _path_cut_points(path,cutdist,closed=closed)
  )
  _path_cut_getpaths(path, cutlist, closed);


function _path_cut_getpaths(path, cutlist, closed) =
  let(
      cuts = len(cutlist)
  )
  [
      [ each list_head(path,cutlist[0][1]-1),
        if (!approx(cutlist[0][0], path[cutlist[0][1]-1])) cutlist[0][0]
      ],
      for(i=[0:1:cuts-2])
          cutlist[i][0]==cutlist[i+1][0] && cutlist[i][1]==cutlist[i+1][1] ? []
          :
          [ if (!approx(cutlist[i][0], select(path,cutlist[i][1]))) cutlist[i][0],
            each slice(path, cutlist[i][1], cutlist[i+1][1]-1),
            if (!approx(cutlist[i+1][0], select(path,cutlist[i+1][1]-1))) cutlist[i+1][0],
          ],
      [
        if (!approx(cutlist[cuts-1][0], select(path,cutlist[cuts-1][1]))) cutlist[cuts-1][0],
        each select(path,cutlist[cuts-1][1],closed ? 0 : -1)
      ]
  ];


// internal function
// converts pathcut output form to a [segment, u]
// form list that works withi path_select
function _cut_to_seg_u_form(pathcut, path, closed) =
  let(lastind = len(path) - (closed?0:1))
  [for(entry=pathcut)
    entry[1] > lastind ? [lastind,0] :
    let(
        a = path[entry[1]-1],
        b = path[entry[1]],
        c = entry[0],
        i = max_index(v_abs(b-a)),
        factor = (c[i]-a[i])/(b[i]-a[i])
    )
    [entry[1]-1,factor]
  ];



// Function: split_path_at_self_crossings()
// Usage:
//   paths = split_path_at_self_crossings(path, [closed], [eps]);
// Description:
//   Splits a path into sub-paths wherever the original path crosses itself.
//   Splits may occur mid-segment, so new vertices will be created at the intersection points.
// Arguments:
//   path = The path to split up.
//   closed = If true, treat path as a closed polygon.  Default: true
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
// Example(2D,NoAxes):
//   path = [ [-100,100], [0,-50], [100,100], [100,-100], [0,50], [-100,-100] ];
//   paths = split_path_at_self_crossings(path);
//   rainbow(paths) stroke($item, closed=false, width=3);
function split_path_at_self_crossings(path, closed=true, eps=EPSILON) =
    let(
        path = cleanup_path(path, eps=eps),
        isects = deduplicate(
            eps=eps,
            concat(
                [[0, 0]],
                sort([
                    for (
                        a = _path_self_intersections(path, closed=closed, eps=eps),
                        ss = [ [a[1],a[2]], [a[3],a[4]] ]
                    ) if (ss[0] != undef) ss
                ]),
                [[len(path)-(closed?1:2), 1]]
            )
        )
    ) [
        for (p = pair(isects))
            let(
                s1 = p[0][0],
                u1 = p[0][1],
                s2 = p[1][0],
                u2 = p[1][1],
                section = _path_select(path, s1, u1, s2, u2, closed=closed),
                outpath = deduplicate(eps=eps, section)
            )
            if (len(outpath)>1) outpath
    ];


function _tag_self_crossing_subpaths(path, nonzero, closed=true, eps=EPSILON) =
    let(
        subpaths = split_path_at_self_crossings(
            path, closed=true, eps=eps
        )
    ) [
        for (subpath = subpaths) let(
            seg = select(subpath,0,1),
            mp = mean(seg),
            n = line_normal(seg) / 2048,
            p1 = mp + n,
            p2 = mp - n,
            p1in = point_in_polygon(p1, path, nonzero=nonzero) >= 0,
            p2in = point_in_polygon(p2, path, nonzero=nonzero) >= 0,
            tag = (p1in && p2in)? "I" : "O"
        ) [tag, subpath]
    ];


// Function: polygon_parts()
// Usage:
//   splitpaths = polygon_parts(path, [nonzero], [eps]);
// Description:
//   Given a possibly self-intersecting polygon, constructs a representation of the original polygon as a list of
//   non-intersecting simple polygons.  If nonzero is set to true then it uses the nonzero method for defining polygon membership, which
//   means it will produce the outer perimeter. 
// Arguments:
//   path = The path to split up.
//   nonzero = If true use the nonzero method for checking if a point is in a polygon.  Otherwise use the even-odd method.  Default: false
//   eps = The epsilon error value to determine whether two points coincide.  Default: `EPSILON` (1e-9)
// Example(2D,NoAxes):  This cross-crossing polygon breaks up into its 3 components (regardless of the value of nonzero).
//   path = [
//       [-100,100], [0,-50], [100,100],
//       [100,-100], [0,50], [-100,-100]
//   ];
//   splitpaths = polygon_parts(path);
//   rainbow(splitpaths) stroke($item, closed=true, width=3);
// Example(2D,NoAxes): With nonzero=false you get even-odd mode which matches OpenSCAD, so the pentagram breaks apart into its five points.
//   pentagram = turtle(["move",100,"left",144], repeat=4);
//   left(100)polygon(pentagram);
//   rainbow(polygon_parts(pentagram,nonzero=false))
//     stroke($item,closed=true,width=2.5);
// Example(2D,NoAxes): With nonzero=true you get only the outer perimeter.  You can use this to create the polygon using the nonzero method, which is not supported by OpenSCAD.
//   pentagram = turtle(["move",100,"left",144], repeat=4);
//   outside = polygon_parts(pentagram,nonzero=true);
//   left(100)region(outside);
//   rainbow(outside)
//     stroke($item,closed=true,width=2.5);
// Example(2D,NoAxes): 
//   N=12;
//   ang=360/N;
//   sr=10;
//   path = turtle(["angle", 90+ang/2,
//                  "move", sr, "left",
//                  "move", 2*sr*sin(ang/2), "left",
//                  "repeat", 4,
//                     ["move", 2*sr, "left",
//                      "move", 2*sr*sin(ang/2), "left"],
//                  "move", sr]);
//   stroke(path, width=.3);
//   right(20)rainbow(polygon_parts(path)) polygon($item);
// Example(2D,NoAxes): overlapping path segments disappear
//   path = [[0,0], [10,0], [10,10], [0,10],[0,20], [20,10],[10,10], [0,10],[0,0]];
//   stroke(path,width=0.3);
//   right(22)stroke(polygon_parts(path)[0], width=0.3, closed=true);
// Example(2D,NoAxes): Path segments disappear outside as well
//   path = turtle(["repeat", 3, ["move", 17, "left", "move", 10, "left", "move", 7, "left", "move", 10, "left"]]);
//   back(2)stroke(path,width=.5);
//   fwd(12)rainbow(polygon_parts(path)) stroke($item, closed=true, width=0.5);
// Example(2D,NoAxes):  This shape has six components
//   path = turtle(["repeat", 3, ["move", 15, "left", "move", 7, "left", "move", 10, "left", "move", 17, "left"]]);
//   polygon(path);
//   right(22)rainbow(polygon_parts(path)) polygon($item);
// Example(2D,NoAxes): When the loops of the shape overlap then nonzero gives a different result than the even-odd method.
//   path = turtle(["repeat", 3, ["move", 15, "left", "move", 7, "left", "move", 10, "left", "move", 10, "left"]]);
//   polygon(path);
//   right(27)rainbow(polygon_parts(path)) polygon($item);
//   move([16,-14])rainbow(polygon_parts(path,nonzero=true)) polygon($item);
function polygon_parts(path, nonzero=false, eps=EPSILON) =
    let(
        path = cleanup_path(path, eps=eps),
        tagged = _tag_self_crossing_subpaths(path, nonzero=nonzero, closed=true, eps=eps),
        kept = [for (sub = tagged) if(sub[0] == "O") sub[1]],
        outregion = _assemble_path_fragments(kept, eps=eps)
    ) outregion;


function _extreme_angle_fragment(seg, fragments, rightmost=true, eps=EPSILON) =
    !fragments? [undef, []] :
    let(
        delta = seg[1] - seg[0],
        segang = atan2(delta.y,delta.x),
        frags = [
            for (i = idx(fragments)) let(
                fragment = fragments[i],
                fwdmatch = approx(seg[1], fragment[0], eps=eps),
                bakmatch =  approx(seg[1], last(fragment), eps=eps)
            ) [
                fwdmatch,
                bakmatch,
                bakmatch? reverse(fragment) : fragment
            ]
        ],
        angs = [
            for (frag = frags)
                (frag[0] || frag[1])? let(
                    delta2 = frag[2][1] - frag[2][0],
                    segang2 = atan2(delta2.y, delta2.x)
                ) modang(segang2 - segang) : (
                    rightmost? 999 : -999
                )
        ],
        fi = rightmost? min_index(angs) : max_index(angs)
    ) abs(angs[fi]) > 360? [undef, fragments] : let(
        remainder = [for (i=idx(fragments)) if (i!=fi) fragments[i]],
        frag = frags[fi],
        foundfrag = frag[2]
    ) [foundfrag, remainder];


/// Internal Function: _assemble_a_path_from_fragments()
/// Usage:
///   _assemble_a_path_from_fragments(subpaths);
/// Description:
///   Given a list of paths, assembles them together into one complete closed polygon path, and
///   remainder fragments.  Returns [PATH, FRAGMENTS] where FRAGMENTS is the list of remaining
///   unused path fragments.
/// Arguments:
///   fragments = List of paths to be assembled into complete polygons.
///   rightmost = If true, assemble paths using rightmost turns. Leftmost if false.
///   startfrag = The fragment to start with.  Default: 0
///   eps = The epsilon error value to determine whether two points coincide.  Default: `EPSILON` (1e-9)
function _assemble_a_path_from_fragments(fragments, rightmost=true, startfrag=0, eps=EPSILON) =
    len(fragments)==0? _finished :
    let(
        path = fragments[startfrag],
        newfrags = [for (i=idx(fragments)) if (i!=startfrag) fragments[i]]
    ) is_closed_path(path, eps=eps)? (
        // starting fragment is already closed
        [path, newfrags]
    ) : let(
        // Find rightmost/leftmost continuation fragment
        seg = select(path,-2,-1),
        extrema = _extreme_angle_fragment(seg=seg, fragments=newfrags, rightmost=rightmost, eps=eps),
        foundfrag = extrema[0],
        remainder = extrema[1]
    ) is_undef(foundfrag)? (
        // No remaining fragments connect!  INCOMPLETE PATH!
        // Treat it as complete.
        [path, remainder]
    ) : is_closed_path(foundfrag, eps=eps)? (
        // Found fragment is already closed
        [foundfrag, concat([path], remainder)]
    ) : let(
        fragend = last(foundfrag),
        hits = [for (i = idx(path,e=-2)) if(approx(path[i],fragend,eps=eps)) i]
    ) hits? (
        let(
            // Found fragment intersects with initial path
            hitidx = last(hits),
            newpath = list_head(path,hitidx),
            newfrags = concat(len(newpath)>1? [newpath] : [], remainder),
            outpath = concat(slice(path,hitidx,-2), foundfrag)
        )
        [outpath, newfrags]
    ) : let(
        // Path still incomplete.  Continue building it.
        newpath = concat(path, list_tail(foundfrag)),
        newfrags = concat([newpath], remainder)
    )
    _assemble_a_path_from_fragments(
        fragments=newfrags,
        rightmost=rightmost,
        eps=eps
    );


/// Internal Function: _assemble_path_fragments()
/// Usage:
///   _assemble_path_fragments(subpaths);
/// Description:
///   Given a list of paths, assembles them together into complete closed polygon paths if it can.
///   Polygons with area < eps will be discarded and not returned.  
/// Arguments:
///   fragments = List of paths to be assembled into complete polygons.
///   eps = The epsilon error value to determine whether two points coincide.  Default: `EPSILON` (1e-9)
function _assemble_path_fragments(fragments, eps=EPSILON, _finished=[]) =
    len(fragments)==0? _finished :
    let(
        minxidx = min_index([
            for (frag=fragments) min(subindex(frag,0))
        ]),
        result_l = _assemble_a_path_from_fragments(
            fragments=fragments,
            startfrag=minxidx,
            rightmost=false,
            eps=eps
        ),
        result_r = _assemble_a_path_from_fragments(
            fragments=fragments,
            startfrag=minxidx,
            rightmost=true,
            eps=eps
        ),
        l_area = abs(polygon_area(result_l[0])),
        r_area = abs(polygon_area(result_r[0])),
        result = l_area < r_area? result_l : result_r,
        newpath = cleanup_path(result[0]),
        remainder = result[1],
        finished = min(l_area,r_area)<eps ? _finished : concat(_finished, [newpath])
    ) _assemble_path_fragments(
        fragments=remainder,
        eps=eps,
        _finished=finished
    );



// vim: expandtab tabstop=4 shiftwidth=4 softtabstop=4 nowrap
