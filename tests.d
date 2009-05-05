/**Hypothesis testing beyond simple CDFs.  All functions work with input
 * ranges with elements implicitly convertible to real unless otherwise noted.
 *
 * Author:  David Simcha*/
 /*
 * You may use this software under your choice of either of the following
 * licenses.  YOU NEED ONLY OBEY THE TERMS OF EXACTLY ONE OF THE TWO LICENSES.
 * IF YOU CHOOSE TO USE THE PHOBOS LICENSE, YOU DO NOT NEED TO OBEY THE TERMS OF
 * THE BSD LICENSE.  IF YOU CHOOSE TO USE THE BSD LICENSE, YOU DO NOT NEED
 * TO OBEY THE TERMS OF THE PHOBOS LICENSE.  IF YOU ARE A LAWYER LOOKING FOR
 * LOOPHOLES AND RIDICULOUSLY NON-EXISTENT AMBIGUITIES IN THE PREVIOUS STATEMENT,
 * GET A LIFE.
 *
 * ---------------------Phobos License: ---------------------------------------
 *
 *  Copyright (C) 2008-2009 by David Simcha.
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 *
 * --------------------BSD License:  -----------------------------------------
 *
 * Copyright (c) 2008-2009, David Simcha
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 *     * Neither the name of the authors nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
module dstats.tests;

import dstats.base, dstats.distrib, dstats.alloc, dstats.summary, dstats.sort,
       std.algorithm, std.functional, std.range, std.c.stdlib;

version(unittest) {
    import std.stdio, std.random;

    Random gen;

    static this() {
        gen.seed(unpredictableSeed);
    }

    void main(){}
}

/**Alternative hypotheses.  Exact meaning varies with test used.*/
enum Alt {
    /// f(input1) != X
    TWOSIDE,
    /// f(input1) < X
    LESS,
    /// f(input1) > X
    GREATER
}

/**One-sample Student's T-test for difference between mean of data and
 * a fixed value.  Alternatives are Alt.LESS, meaning mean(data) < mean,
 * Alt.GREATER, meaning mean(data) > mean, and Alt.TWOSIDE, meaning mean(data)
 * != mean.
 *
 * Returns:  The p-value against the given alternative.*/
real studentsTTest(T)(T data, real mean, Alt alt = Alt.TWOSIDE)
if(realIterable!(T)) {
    OnlineMeanSD meanSd;
    uint len;
    foreach(elem; data) {
        len++;
        meanSd.put(elem);
    }

    real t = (meanSd.mean - mean) / (meanSd.stdev / sqrt(cast(real) len));
    if(alt == Alt.LESS)
        return studentsTCDF(t, data.length - 1);
    else if(alt == Alt.GREATER)
        return studentsTCDF(-t, data.length - 1);
    else
        return 2 * min(studentsTCDF(t, data.length - 1),
                       studentsTCDF(-t, data.length - 1));
}

unittest {
    assert(approxEqual(studentsTTest([1, 2, 3, 4, 5].dup, 2), .2302));
    assert(approxEqual(studentsTTest([1, 2, 3, 4, 5].dup, 2, Alt.LESS), .8849));
    assert(approxEqual(studentsTTest([1, 2, 3, 4, 5].dup, 2, Alt.GREATER), .1151));
    writeln("Passed 1-sample studentsTTest test.");
}

/**Two-sample T test for a difference in means of normally distributed data,
 * assumes variances of samples are equal.  Alteratives are Alt.LESS, meaning
 * mean(sample1) < mean(sample2), Alt.GREATER, meaning mean(sample1) >
 * mean(sample2), and Alt.TWOSIDE, meaning mean(sample1) != mean(sample2).
 * Returns:  The p-value against the given alternative.*/
real studentsTTest(T, U)(T sample1, U sample2, Alt alt = Alt.TWOSIDE)
if(realIterable!(T) && realIterable!(U)) {
    size_t n1, n2;
    OnlineMeanSD s1summ, s2summ;
    foreach(elem; sample1) {
        s1summ.put(elem);
        n1++;
    }
    foreach(elem; sample2) {
        s2summ.put(elem);
        n2++;
    }

    real sx1x2 = sqrt(((n1 - 1) * s1summ.var + (n2 - 1) * s2summ.var) /
                 (n1 + n2 - 2));
    real t = (s1summ.mean - s2summ.mean) /
             (sx1x2 * sqrt((1.0L / n1) + (1.0L / n2)));
    if(alt == Alt.LESS)
        return studentsTCDF(t, n1 + n2 - 2);
    else if(alt == Alt.GREATER)
        return studentsTCDF(-t, n1 + n2 - 2);
    else
        return 2 * min(studentsTCDF(t, n1 + n2 - 2),
                       studentsTCDF(-t, n1 + n2 - 2));
}

unittest {
    // Values from R.
    assert(approxEqual(studentsTTest([1,2,3,4,5].dup, [1,3,4,5,7,9].dup), 0.2346));
    assert(approxEqual(studentsTTest([1,2,3,4,5].dup, [1,3,4,5,7,9].dup, Alt.LESS),
           0.1173));
    assert(approxEqual(studentsTTest([1,2,3,4,5].dup, [1,3,4,5,7,9].dup, Alt.GREATER),
           0.8827));
    assert(approxEqual(studentsTTest([1,3,5,7,9,11].dup, [2,2,1,3,4].dup), 0.06985));
    assert(approxEqual(studentsTTest([1,3,5,7,9,11].dup, [2,2,1,3,4].dup, Alt.LESS),
           0.965));
    assert(approxEqual(studentsTTest([1,3,5,7,9,11].dup, [2,2,1,3,4].dup, Alt.GREATER),
           0.03492));
    writeln("Passed 2-sample studentsTTest test.");
}

/**Two-sample T-test for difference in means of normally distributed data.
 * Does NOT assume variances are equal.
 * Alteratives are Alt.LESS, meaning mean(sample1) < mean(sample2), Alt.GREATER,
 * meaning mean(sample1) > mean(sample2), and Alt.TWOSIDE, meaning mean(sample1)
 * != mean(sample2).
 * Returns:  The p-value against the given alternative.*/
real welchTTest(T, U)(T sample1, U sample2, Alt alt = Alt.TWOSIDE)
if(realIterable!(T) && realIterable!(U)) {
    size_t n1, n2;
    OnlineMeanSD s1summ, s2summ;
    foreach(elem; sample1) {
        s1summ.put(elem);
        n1++;
    }
    foreach(elem; sample2) {
        s2summ.put(elem);
        n2++;
    }

    auto v1 = s1summ.var, v2 = s2summ.var;
    real sx1x2 = sqrt(v1 / n1 + v2 / n2);
    real t = (s1summ.mean - s2summ.mean) / sx1x2;
    real numerator = v1 / n1 + v2 / n2;
    numerator *= numerator;
    real denom1 = v1 / n1;
    denom1 = denom1 * denom1 / (n1 - 1);
    real denom2 = v2 / n2;
    denom2 = denom2 * denom2 / (n2 - 1);
    real df = numerator / (denom1 + denom2);
    if(alt == Alt.LESS)
        return studentsTCDF(t, df);
    else if(alt == Alt.GREATER)
        return studentsTCDF(-t, df);
    else
        return 2 * min(studentsTCDF(t, df), studentsTCDF(-t, df));
}

unittest {
        // Values from R.
    assert(approxEqual(welchTTest([1,2,3,4,5].dup, [1,3,4,5,7,9].dup), 0.2159));
    assert(approxEqual(welchTTest([1,2,3,4,5].dup, [1,3,4,5,7,9].dup, Alt.LESS),
           0.1079));
    assert(approxEqual(welchTTest([1,2,3,4,5].dup, [1,3,4,5,7,9].dup, Alt.GREATER),
           0.892));
    assert(approxEqual(welchTTest([1,3,5,7,9,11].dup, [2,2,1,3,4].dup), 0.06616));
    assert(approxEqual(welchTTest([1,3,5,7,9,11].dup, [2,2,1,3,4].dup, Alt.LESS),
           0.967));
    assert(approxEqual(welchTTest([1,3,5,7,9,11].dup, [2,2,1,3,4].dup, Alt.GREATER),
           0.03308));
    writeln("Passed welchTTest test.");
}

/**Paired T test.  Tests the hypothesis that the mean difference between
 * corresponding elements of before and after is testMean.  Alternatives are
 * Alt.LESS, meaning the that the true mean difference (before[i] - after[i])
 * is less than testMean, Alt.GREATER, meaning the true mean difference is
 * greater than testMean, and Alt.TWOSIDE, meaning the true mean difference is not
 * equal to testMean.
 *
 * Returns:  The p-value against the given alternative.*/
real pairedTTest(T, U)(T before, U after, Alt alt = Alt.TWOSIDE, real testMean = 0)
if(realInput!(T) && realInput!(U)) {
    OnlineMeanSD msd;
    size_t len = 0;
    while(!before.empty && !after.empty) {
        real diff = cast(real) before.front - cast(real) after.front;
        before.popFront;
        after.popFront;
        msd.put(diff);
        len++;
    }
    real t = (msd.mean - testMean) / msd.stdev * sqrt(cast(real) len);

    if(alt == Alt.LESS) {
        return studentsTCDF(t, len - 1);
    } else if(alt == Alt.GREATER) {
        return studentsTCDF(-t, len - 1);
    } else if(t > 0) {
        return 2 * studentsTCDF(-t, len - 1);
    } else {
        return 2 * studentsTCDF(t, len - 1);
    }
}

unittest {
    // Values from R.
    assert(approxEqual(pairedTTest([3,2,3,4,5].dup, [2,3,5,5,6].dup, Alt.LESS), 0.0889));
    assert(approxEqual(pairedTTest([3,2,3,4,5].dup, [2,3,5,5,6].dup, Alt.GREATER), 0.9111));
    assert(approxEqual(pairedTTest([3,2,3,4,5].dup, [2,3,5,5,6].dup, Alt.TWOSIDE), 0.1778));
    assert(approxEqual(pairedTTest([3,2,3,4,5].dup, [2,3,5,5,6].dup, Alt.LESS, 1), 0.01066));
    assert(approxEqual(pairedTTest([3,2,3,4,5].dup, [2,3,5,5,6].dup, Alt.GREATER, 1), 0.9893));
    assert(approxEqual(pairedTTest([3,2,3,4,5].dup, [2,3,5,5,6].dup, Alt.TWOSIDE, 1), 0.02131));
    writeln("Passed pairedTTest unittest.");
}

/**Wilcoxon rank-sum test statistic.  This is a non-parametric test for a
 * difference in the mean ranks of two sets of numbers.  The tieSum parameter is
 * mostly for use internally, and if included will place a value in the
 * dereference that can be used in wilcoxonRankSumPval() to adjust for ties in
 * the input data.
 *
 * Input ranges for this function must define a length.
 *
 * Returns:  The Wilcoxon test statistic W.*/
real wilcoxonRankSum(T)(T sample1, T sample2, real* tieSum = null)
if(isInputRange!(T) && dstats.base.hasLength!(T)) {
    ulong n1 = sample1.length, n2 = sample2.length, N = n1 + n2;
    auto combined = newStack!(Unqual!(ElementType!(T)))(N);
    rangeCopy(combined[0..n1], sample1);
    rangeCopy(combined[n1..$], sample2);

    float[] ranks = newStack!(float)(N);
    rankSort(combined, ranks);
    real w = reduce!("a + b")(0.0L, ranks[0..n1]) - n1 * (n1 + 1) / 2UL;
    TempAlloc.free;  // Free ranks.

    if(tieSum !is null) {
        // combined is sorted by rankSort.  Can use it to figure out how many
        // ties we have w/o another allocation or sorting.
        enum oneOverTwelve = 1.0L / 12.0L;
        *tieSum = 0;
        ulong nties = 1;
        foreach(i; 1..N) {
            if(combined[i] == combined[i - 1]) {
                nties++;
            } else {
                if(nties == 1)
                    continue;
                *tieSum += ((nties * nties * nties) - nties) * oneOverTwelve;
                nties = 1;
            }
        }
        // Handle last run.
        if(nties > 1) {
            *tieSum += ((nties * nties * nties) - nties) * oneOverTwelve;
        }
    }
    TempAlloc.free;  // Free combined.
    return w;
}

unittest {
    assert(wilcoxonRankSum([1, 2, 3, 4, 5].dup, [2, 4, 6, 8, 10].dup) == 5);
    assert(wilcoxonRankSum([2, 4, 6, 8, 10].dup, [1, 2, 3, 4, 5].dup) == 20);
    assert(wilcoxonRankSum([3, 7, 21, 5, 9].dup, [2, 4, 6, 8, 10].dup) == 15);
    writeln("Passed wilcoxonRankSum test.");
}

/**Computes a P-value for a Wilcoxon rank sum test score against the given
 * alternative. Alt.LESS means that mean rank(sample1) < mean rank(sample2).
 * Alt.GREATER means mean rank(sample1) > mean rank(sample2).  Alt.TWOSIDE means
 * mean rank(sample1) != mean rank(sample2).
 *
 * exactThresh
 * is the threshold value of (n1 + n2) at which this function switches from
 * exact to approximate computation of the p-value.   Do not set
 * exactThresh to more than 200, as the exact calculation is both very slow and
 * not numerically stable past this point, and the asymptotic calculation is
 * very good for N this large.  To disable exact calculation entirely, set
 * exactThresh to 0.
 *
 * Note:  Exact p-value computation is never used when tieSum > 0, i.e. when
 * there were ties in the data, because it is not computationally feasible.
 * In these cases, exactThresh will be ignored.
 *
 * Returns:  The p-value against the given alternative.*/
real wilcoxonRankSumPval(T)(T w, ulong n1, ulong n2, Alt alt = Alt.TWOSIDE,
                           real tieSum = 0,  uint exactThresh = 50) {
    ulong N = n1 + n2;

    if(N < exactThresh && tieSum == 0) {
        return wilcoxRSPExact(cast(uint) w, n1, n2, alt);
    }

    real sd = sqrt(cast(real) (n1 * n2) / (N * (N - 1)) *
             ((N * N * N - N) / 12 - tieSum));
    real mean = (n1 * n2) / 2.0L;
    if(alt == Alt.TWOSIDE)
        return 2.0L * min(normalCDF(w + .5, mean, sd),
                          normalCDFR(w - .5, mean, sd), 0.5L);
    else if(alt == Alt.LESS)
        return normalCDF(w + .5, mean, sd);
    else if(alt == Alt.GREATER)
        return normalCDFR(w - .5, mean, sd);
}

unittest {
    /* Values from R.  I could only get good values for Alt.LESS directly.
     * Using W-values to test Alt.TWOSIDE, Alt.GREATER indirectly.*/
    assert(approxEqual(wilcoxonRankSumPval(1200, 50, 50, Alt.LESS), .3670));
    assert(approxEqual(wilcoxonRankSumPval(1500, 50, 50, Alt.LESS), .957903));
    assert(approxEqual(wilcoxonRankSumPval(8500, 100, 200, Alt.LESS), .01704));
    auto w = wilcoxonRankSum([2,4,6,8,12].dup, [1,3,5,7,11,9].dup);
    assert(approxEqual(wilcoxonRankSumPval(w, 5, 6), 0.9273));
    assert(approxEqual(wilcoxonRankSumPval(w, 5, 6, Alt.GREATER), 0.4636));
    assert(approxEqual(wilcoxonRankSumPval(w, 5, 6, Alt.LESS), 0.6079));
}

/**Computes Wilcoxon rank sum test P-value for
 * a set of observations against another set, using the given alternative.
 * Alt.LESS means that mean rank(sample1) < mean rank(sample2).  Alt.GREATER means
 * mean rank(sample1) > mean rank(sample2).  Alt.TWOSIDE means mean rank(sample1) !=
 * mean rank(sample2).
 *
 * tieSum is a parameter that is used  internally to adjust for
 * ties in the data.  It is computed by wilcoxonRankSum().
 * exactThresh is the threshold value of (n1 + n2) at which this function
 * switches from exact to approximate computation of the p-value.  Exact
 * computation is very slow for large datasets, and for anything but very small
 * datasets, the asymptotic approximation is good enough for all practical
 * purposes.  Do not set exactThresh to more than 200, as the exact
 * calculation is both very slow and not numerically stable past this point,
 * and the asymptotic calculation is very good for N this large.  To disable
 * exact calculation entirely, set exactThresh to 0.
 *
 * Note:  Exact p-value computation is never used when tieSum > 0, i.e. when
 * there were ties in the data, because it is not computationally feasible.
 * In these cases, exactThresh will be ignored.
 *
 * Input ranges for this function must define a length.
 *
 * Returns:  The p-value against the given alternative.*/
real wilcoxonRankSumPval(T)(T sample1, T sample2, Alt alt = Alt.TWOSIDE,
    uint exactThresh = 50) if(isInputRange!(T) && dstats.base.hasLength!(T)) {

    real tieSum;
    real W = wilcoxonRankSum(sample1, sample2, &tieSum);
    return wilcoxonRankSumPval(W, sample1.length, sample2.length, alt, tieSum,
                               exactThresh);
}

 unittest {
     // Values from R.  Simple stuff (no ties) first.  Testing approximate
     // calculation first.
     assert(approxEqual(wilcoxonRankSumPval([2,4,6,8,12].dup, [1,3,5,7,11,9].dup,
           Alt.TWOSIDE, 0), 0.9273));
     assert(approxEqual(wilcoxonRankSumPval([2,4,6,8,12].dup, [1,3,5,7,11,9].dup,
           Alt.LESS, 0), 0.6079));
     assert(approxEqual(wilcoxonRankSumPval([2,4,6,8,12].dup, [1,3,5,7,11,9].dup,
           Alt.GREATER, 0), 0.4636));
     assert(approxEqual(wilcoxonRankSumPval([1,2,6,10,12].dup, [3,5,7,8,13,15].dup,
            Alt.TWOSIDE, 0), 0.4113));
     assert(approxEqual(wilcoxonRankSumPval([1,2,6,10,12].dup, [3,5,7,8,13,15].dup,
            Alt.LESS, 0), 0.2057));
     assert(approxEqual(wilcoxonRankSumPval([1,2,6,10,12].dup, [3,5,7,8,13,15].dup,
            Alt.GREATER, 0), 0.8423));
     assert(approxEqual(wilcoxonRankSumPval([1,3,5,7,9].dup, [2,4,6,8,10].dup,
            Alt.TWOSIDE, 0), .6745));
     assert(approxEqual(wilcoxonRankSumPval([1,3,5,7,9].dup, [2,4,6,8,10].dup,
            Alt.LESS, 0), .3372));
     assert(approxEqual(wilcoxonRankSumPval([1,3,5,7,9].dup, [2,4,6,8,10].dup,
            Alt.GREATER, 0), .7346));

    // Now, lots of ties.
    assert(approxEqual(wilcoxonRankSumPval([1,2,3,4,5].dup, [2,3,4,5,6].dup,
           Alt.TWOSIDE, 0), 0.3976));
    assert(approxEqual(wilcoxonRankSumPval([1,2,3,4,5].dup, [2,3,4,5,6].dup,
           Alt.LESS, 0), 0.1988));
    assert(approxEqual(wilcoxonRankSumPval([1,2,3,4,5].dup, [2,3,4,5,6].dup,
           Alt.GREATER, 0), 0.8548));
    assert(approxEqual(wilcoxonRankSumPval([1,2,1,1,2].dup, [1,2,3,1,1].dup,
           Alt.TWOSIDE, 0), 0.9049));
    assert(approxEqual(wilcoxonRankSumPval([1,2,1,1,2].dup, [1,2,3,1,1].dup,
           Alt.LESS, 0), 0.4524));
    assert(approxEqual(wilcoxonRankSumPval([1,2,1,1,2].dup, [1,2,3,1,1].dup,
           Alt.GREATER, 0), 0.64));

    // Now, testing the exact calculation on the same data.
     assert(approxEqual(wilcoxonRankSumPval([2,4,6,8,12].dup, [1,3,5,7,11,9].dup,
       Alt.TWOSIDE), 0.9307));
     assert(approxEqual(wilcoxonRankSumPval([2,4,6,8,12].dup, [1,3,5,7,11,9].dup,
           Alt.LESS), 0.6039));
     assert(approxEqual(wilcoxonRankSumPval([2,4,6,8,12].dup, [1,3,5,7,11,9].dup,
           Alt.GREATER), 0.4654));
     assert(approxEqual(wilcoxonRankSumPval([1,2,6,10,12].dup, [3,5,7,8,13,15].dup,
            Alt.TWOSIDE), 0.4286));
     assert(approxEqual(wilcoxonRankSumPval([1,2,6,10,12].dup, [3,5,7,8,13,15].dup,
            Alt.LESS), 0.2143));
     assert(approxEqual(wilcoxonRankSumPval([1,2,6,10,12].dup, [3,5,7,8,13,15].dup,
            Alt.GREATER), 0.8355));
     assert(approxEqual(wilcoxonRankSumPval([1,3,5,7,9].dup, [2,4,6,8,10].dup,
            Alt.TWOSIDE), .6905));
     assert(approxEqual(wilcoxonRankSumPval([1,3,5,7,9].dup, [2,4,6,8,10].dup,
            Alt.LESS), .3452));
     assert(approxEqual(wilcoxonRankSumPval([1,3,5,7,9].dup, [2,4,6,8,10].dup,
            Alt.GREATER), .7262));
    writeln("Passed wilcoxonRankSumPval test.");
 }


/* Used internally by wilcoxonRankSumPval.  This function uses dynamic
 * programming to count the number of combinations of numbers [1..N] that sum
 * of length n1 that sum to <= W in O(N * W * n1) time.*/
real wilcoxRSPExact(uint W, uint n1, uint n2, Alt alt = Alt.TWOSIDE) {
    uint N = n1 + n2;
    uint expected2 = n1 * n2;
    switch(alt) {
        case Alt.LESS:
            if(W > (N * (N - n1)) / 2)  { // Value impossibly large
                return 1;
            } else if(W * 2 <= expected2) {
                break;
            } else {
                return 1 - wilcoxRSPExact(expected2 - W - 1, n1, n2, Alt.LESS);
            }
        case Alt.GREATER:
            if(W > (N * (N - n1)) / 2)  { // Value impossibly large
                return 0;
            } else if(W * 2 >= expected2) {
                return wilcoxRSPExact(expected2 - W, n1, n2, Alt.LESS);
            } else {
                return 1 - wilcoxRSPExact(W - 1, n1, n2, Alt.LESS);
            }
        case Alt.TWOSIDE:
            if(W * 2 <= expected2) {
                return wilcoxRSPExact(W, n1, n2, Alt.LESS) +
                       wilcoxRSPExact(expected2 - W, n1, n2, Alt.GREATER);
            } else {
                return wilcoxRSPExact(W, n1, n2, Alt.GREATER) +
                       wilcoxRSPExact(expected2 - W, n1, n2, Alt.LESS);
            }
        default:
            assert(0);
    }

    W += n1 * (n1 + 1) / 2UL;

    float* cache = (newStack!(float)((n1 + 1) * (W + 1))).ptr;
    float* cachePrev = (newStack!(float)((n1 + 1) * (W + 1))).ptr;
    cache[0..(n1 + 1) * (W + 1)] = 0;
    cachePrev[0..(n1 + 1) * (W + 1)] = 0;

    /* Using reals for the intermediate steps is too slow, but I didn't want to
     * lose too much precision.  Since my sums must be between 0 and 1, I am
     * using the entire bit space of a float to hold numbers between zero and
     * one.  This is precise to at least 1e-7.  This is good enough for a few
     * reasons:
     *
     * 1.  This is a p-value, and therefore will likely not be used in
     *     further calculations where rounding error would accumulate.
     * 2.  If this is too slow, the alternative is to use the asymptotic
     *     approximation.  This is can have relative errors of several orders
     *     of magnitude in the tails of the distribution, and is therefore
     *     clearly worse.
     * 3.  For very large N, where this function could give completely wrong
     *     answers, it would be so slow that any reasonable person would use the
     *     asymptotic approximation anyhow.*/

    real comb = exp(-logNcomb(N, n1));
    real floatMax = cast(real) float.max;
    cache[0] = cast(float) (comb * floatMax);
    cachePrev[0] = cast(float) (comb * floatMax);

    foreach(i; 1..N + 1) {
        swap(cache, cachePrev);
        foreach(k; 1..min(i + 1, n1 + 1)) {

            uint minW = k * (k + 1) / 2;
            float* curK = cache + k * (W + 1);
            float* prevK = cachePrev + k * (W + 1);
            float* prevKm1 = cachePrev + (k - 1) * (W + 1);

            foreach(w; minW..W + 1) {
                curK[w] = prevK[w] + ((i <= w) ? prevKm1[w - i] : 0);
            }
        }
    }

    real sum = 0;
    float* lastLine = cache + n1 * (W + 1);
    foreach(w; 1..W + 1) {
        sum += (cast(real) lastLine[w] / floatMax);
    }
    TempAlloc.free;
    TempAlloc.free;
    return sum;
}

unittest {
    // Values from R.
    assert(approxEqual(wilcoxRSPExact(14, 5, 6), 0.9307));
    assert(approxEqual(wilcoxRSPExact(14, 5, 6, Alt.LESS), 0.4654));
    assert(approxEqual(wilcoxRSPExact(14, 5, 6, Alt.GREATER), 0.6039));
    assert(approxEqual(wilcoxRSPExact(16, 6, 5), 0.9307));
    assert(approxEqual(wilcoxRSPExact(16, 6, 5, Alt.LESS), 0.6039));
    assert(approxEqual(wilcoxRSPExact(16, 6, 5, Alt.GREATER), 0.4654));

    // Mostly to make sure that underflow doesn't happen until
    // the N's are truly unreasonable:
    //assert(approxEqual(wilcoxRSPExact(6_000, 120, 120, Alt.LESS), 0.01276508));
}

/**Wilcoxon signed-rank statistic.  This is a non-parametric test for a
 * difference between paired sets of numbers.  Since this is a paired test,
 * before.length must equal after.length.  The tieSum parameter is
 * mostly for use internally, and if included will place a value in the
 * dereference that can be used in wilcoxonRankSumPval() to adjust for ties in
 * the input data.
 *
 * Input ranges for this function must define a length.
 *
 * Returns:  The Wilcoxon test statistic W.*/
real wilcoxonSignedRank(T, U)(T before, U after, real* tieSum = null)
if(realInput!(T) && realInput!(U) &&
   dstats.base.hasLength!(T) && dstats.base.hasLength!(U)) {
    mixin(newFrame);
    float[] diffRanks = newStack!(float)(before.length);
    byte[] signs = newStack!(byte)(before.length);
    real[] diffs = newStack!(real)(before.length);

    static byte sign(real input) {
        if(input < 0)
            return -1;
        if(input > 0)
            return 1;
        return 0;
    }

    size_t ii = 0;
    while(!before.empty && !after.empty) {
        real diff = cast(real) before.front - cast(real) after.front;
        signs[ii] = sign(diff);
        diffs[ii] = abs(diff);
        ii++;
        before.popFront;
        after.popFront;
    }
    rankSort(diffs, diffRanks);

    real W = 0;
    foreach(i, dr; diffRanks) {
        if(signs[i] == 1)
            W += dr;
    }

    if(tieSum !is null) {
        *tieSum = 0;

        // combined is sorted by rankSort.  Can use it to figure out how many
        // ties we have w/o another allocation or sorting.
        enum denom = 1.0L / 48.0L;
        ulong nties = 1;
        foreach(i; 1..diffs.length) {
            if(diffs[i] == diffs[i - 1] && diffs[i] != 0) {
                nties++;
            } else {
                if(nties == 1)
                    continue;
                *tieSum += ((nties * nties * nties) - nties) * denom;
                nties = 1;
            }
        }
        // Handle last run.
        if(nties > 1) {
            *tieSum += ((nties * nties * nties) - nties) * denom;
        }
    }
    return W;
}

unittest {
    assert(wilcoxonSignedRank([1,2,3,4,5].dup, [2,1,4,5,3].dup) == 7.5);
    assert(wilcoxonSignedRank([3,1,4,1,5].dup, [2,7,1,8,2].dup) == 6);
    assert(wilcoxonSignedRank([8,6,7,5,3].dup, [0,9,8,6,7].dup) == 5);
    writeln("Passed wilcoxonSignedRank unittest.");
}

/**Computes a P-value for a Wilcoxon signed rank test score against the given
 * alternative. Alt.LESS means that elements of before are typically less
 * than corresponding elements of after.  Alt.GREATER means elements of
 * before are typically greater than corresponding elements of after.
 * Alt.TWOSIDE means there is a significant difference in either direction.
 *
 * exactThresh is the threshold value of before.length at which this function
 * switches from exact to approximate computation of the p-value.   Do not set
 * exactThresh to more than 200, as the exact calculation is both very slow and
 * not numerically stable past this point, and the asymptotic calculation is
 * very good for N this large.  To disable exact calculation entirely, set
 * exactThresh to 0.
 *
 * Notes:  Exact p-value computation is never used when tieSum > 0, i.e. when
 * there were ties in the data, because it is not computationally feasible.
 * In these cases, exactThresh will be ignored.
 *
 * May give a different answer than calling wilcoxonSignedRank, and then
 * passing the W value into wilcoxonSignedRankPval in the presence of ties
 * or equal pairs.
 *
 * The input ranges for this function must define a length and must be
 * forward ranges.
 *
 * Returns:  The p-value against the given alternative.*/
real wilcoxonSignedRankPval(T)(T before, T after,
      Alt alt = Alt.TWOSIDE, uint exactThresh = 50)
if(realInput!(T) && dstats.base.hasLength!(T) && isForwardRange!(T))
in {
    assert(before.length == after.length);
} body {
    real tieSum;
    real W = wilcoxonSignedRank(before, after, &tieSum);
    ulong N = before.length;
    while(!before.empty && !after.empty) {
        if(before.front == after.front)
            N--;
        before.popFront;
        after.popFront;

    }
    return wilcoxonSignedRankPval(W, N, alt, tieSum, exactThresh);
}

unittest {
    // Values from R.
    alias approxEqual ae;
    // With ties, normal approx.
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,1,4,5,3].dup), 1));
    assert(ae(wilcoxonSignedRankPval([3,1,4,1,5].dup, [2,7,1,8,2].dup), 0.7865));
    assert(ae(wilcoxonSignedRankPval([8,6,7,5,3].dup, [0,9,8,6,7].dup), 0.5879));
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,1,4,5,3].dup, Alt.LESS), 0.5562));
    assert(ae(wilcoxonSignedRankPval([3,1,4,1,5].dup, [2,7,1,8,2].dup, Alt.LESS), 0.3932));
    assert(ae(wilcoxonSignedRankPval([8,6,7,5,3].dup, [0,9,8,6,7].dup, Alt.LESS), 0.2940));
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,1,4,5,3].dup, Alt.GREATER), 0.5562));
    assert(ae(wilcoxonSignedRankPval([3,1,4,1,5].dup, [2,7,1,8,2].dup, Alt.GREATER), 0.706));
    assert(ae(wilcoxonSignedRankPval([8,6,7,5,3].dup, [0,9,8,6,7].dup, Alt.GREATER), 0.7918));

    // Exact.
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,-4,-8,16,32].dup), 0.625));
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,-4,-8,16,32].dup, Alt.LESS), 0.3125));
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,-4,-8,16,32].dup, Alt.GREATER), 0.7812));
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,-4,-8,-16,32].dup), 0.8125));
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,-4,-8,-16,32].dup, Alt.LESS), 0.6875));
    assert(ae(wilcoxonSignedRankPval([1,2,3,4,5].dup, [2,-4,-8,-16,32].dup, Alt.GREATER), 0.4062));
    writeln("Passed wilcoxonSignedRankPval unittest.");
}

/**Computes Wilcoxon signed rank test P-value for
 * a set of observations against another set, using the given alternative.
 * Alt.LESS means that elements of before are typically less than corresponding
 * elements of after.  Alt.GREATER means elements of before are typically
 * greater than corresponding elements of after.  Alt.TWOSIDE means that
 * there is a significant difference in either direction.
 *
 * tieSum is a parameter that is used  internally to adjust for
 * ties in the data.  It is computed by wilcoxonSignedRank().
 * exactThresh is the threshold value of N at which this function
 * switches from exact to approximate computation of the p-value.  Exact
 * computation is very slow for large datasets, and for anything but very small
 * datasets, the asymptotic approximation is good enough for all practical
 * purposes.  Do not set exactThresh to more than 200, as the exact
 * calculation is both very slow and not numerically stable past this point,
 * and the asymptotic calculation is very good for N this large.  To disable
 * exact calculation entirely, set exactThresh to 0.
 *
 * Note:  Exact p-value computation is never used when tieSum > 0, i.e. when
 * there were ties in the data, because it is not computationally feasible.
 * In these cases, exactThresh will be ignored.
 *
 * Returns:  The p-value against the given alternative.*/
real wilcoxonSignedRankPval(T)(T W, ulong N, Alt alt = Alt.TWOSIDE,
     real tieSum = 0, uint exactThresh = 50)
in {
    assert(N > 0);
    assert(tieSum >= 0);
} body {
    if(tieSum == 0 && N <= exactThresh)
        return wilcoxSRPExact(cast(uint) W, N, alt);

    real expected = N * (N + 1) * 0.25L;
    real sd = sqrt(N * (N + 1) * (2 * N + 1) / 24.0L - tieSum);

    if(alt == Alt.LESS) {
        return normalCDF(W + 0.5, expected, sd);
    } else if(alt == Alt.GREATER) {
        return normalCDFR(W - 0.5, expected, sd);
    } else {
        return 2 * min(normalCDF(W + 0.5, expected, sd),
                       normalCDFR(W - 0.5, expected, sd), 0.5L);
    }
}
// Tested indirectly through other overload.

/* Yes, a little cut and paste coding was involved here from wilcoxRSPExact,
 * but this function and wilcoxRSPExact are just different enough that
 * it would be more trouble than it's worth to write one generalized
 * function.*/
real wilcoxSRPExact(uint W, uint N, Alt alt = Alt.TWOSIDE) {
    uint expected2 = N * (N + 1) / 2;
    switch(alt) {
        case Alt.LESS:
            if(W > (N * (N + 1) / 2))  { // Value impossibly large
                return 1;
            } else if(W * 2 <= expected2) {
                break;
            } else {
                return 1 - wilcoxSRPExact(expected2 - W - 1, N, Alt.LESS);
            }
        case Alt.GREATER:
            if(W > (N * (N + 1) / 2))  { // Value impossibly large
                return 0;
            } else if(W * 2 >= expected2) {
                return wilcoxSRPExact(expected2 - W, N, Alt.LESS);
            } else {
                return 1 - wilcoxSRPExact(W - 1, N, Alt.LESS);
            }
        case Alt.TWOSIDE:
            if(W * 2 <= expected2) {
                return wilcoxSRPExact(W, N, Alt.LESS) +
                       wilcoxSRPExact(expected2 - W, N, Alt.GREATER);
            } else {
                return wilcoxSRPExact(W, N, Alt.GREATER) +
                       wilcoxSRPExact(expected2 - W, N, Alt.LESS);
            }
        default:
            assert(0);
    }

    float* cache = (newStack!(float)((N + 1) * (W + 1))).ptr;
    float* cachePrev = (newStack!(float)((N + 1) * (W + 1))).ptr;
    cache[0..(N + 1) * (W + 1)] = 0;
    cachePrev[0..(N + 1) * (W + 1)] = 0;

    real comb = pow(2.0L, -(cast(real) N));
    real floatMax = cast(real) float.max;
    cache[0] = cast(float) (comb * floatMax);
    cachePrev[0] = cast(float) (comb * floatMax);

    foreach(i; 1..N + 1) {
        swap(cache, cachePrev);
        foreach(k; 1..i + 1) {

            uint minW = k * (k + 1) / 2;
            float* curK = cache + k * (W + 1);
            float* prevK = cachePrev + k * (W + 1);
            float* prevKm1 = cachePrev + (k - 1) * (W + 1);

            foreach(w; minW..W + 1) {
                curK[w] = prevK[w] + ((i <= w) ? prevKm1[w - i] : 0);
            }
        }
    }

    real sum  = 0;
    foreach(elem; cache[0..(N + 1) * (W + 1)]) {
        sum += cast(real) elem / (cast(real) float.max);
    }
    TempAlloc.free;
    TempAlloc.free;
    return sum;
}

unittest {
    // Values from R.
    assert(approxEqual(wilcoxSRPExact(25, 10, Alt.LESS), 0.4229));
    assert(approxEqual(wilcoxSRPExact(25, 10, Alt.GREATER), 0.6152));
    assert(approxEqual(wilcoxSRPExact(25, 10, Alt.TWOSIDE), 0.8457));
    assert(approxEqual(wilcoxSRPExact(31, 10, Alt.LESS), 0.6523));
    assert(approxEqual(wilcoxSRPExact(31, 10, Alt.GREATER), 0.3848));
    assert(approxEqual(wilcoxSRPExact(31, 10, Alt.TWOSIDE), 0.7695));
    writeln("Passed wilcoxSRPExact unittest.");
}

/**Sign test for differences between paired values.  This is a very robust
 * but very low power test.  Alternatives are Alt.LESS, meaning elements
 * of before are typically less than corresponding elements of after,
 * Alt.GREATER, meaning elements of before are typically greater than
 * elements of after, and Alt.TWOSIDE, meaning that there is a significant
 * difference in either direction.*/
real signTest(T)(T before, T after, Alt alt = Alt.TWOSIDE)
if(realInput!(T)) {
    uint greater, less;
    while(!before.empty && !after.empty) {
        if(before.front < after.front)
            less++;
        else if(after.front < before.front)
            greater++;
        // Ignore equals.
        before.popFront;
        after.popFront;
    }
    if(alt == Alt.LESS) {
        return binomialCDF(greater, less + greater, 0.5);
    } else if(alt == Alt.GREATER) {
        return binomialCDF(less, less + greater, 0.5);
    } else if(less > greater) {
        return 2 * binomialCDF(greater, less + greater, 0.5);
    } else if(greater > less) {
        return 2 * binomialCDF(less, less + greater, 0.5);
    } else return 1;
}

unittest {
    alias approxEqual ae;
    assert(ae(signTest([1,3,4,2,5].dup, [1,2,4,8,16].dup), 1));
    assert(ae(signTest([1,3,4,2,5].dup, [1,2,4,8,16].dup, Alt.LESS), 0.5));
    assert(ae(signTest([1,3,4,2,5].dup, [1,2,4,8,16].dup, Alt.GREATER), 0.875));
    assert(ae(signTest([5,3,4,6,8].dup, [1,2,3,4,5].dup, Alt.GREATER), 0.03125));
    assert(ae(signTest([5,3,4,6,8].dup, [1,2,3,4,5].dup, Alt.LESS), 1));
    assert(ae(signTest([5,3,4,6,8].dup, [1,2,3,4,5].dup), 0.0625));
}

/**Sign test for differences between a set of values and an a priori
 * median.  This is a very robust  but very low power test.
 * Alternatives are Alt.LESS, meaning elements
 * of data are typically less than median,
 * Alt.GREATER, meaning elements of data are typically greater than
 * median, and Alt.TWOSIDE, meaning that there is a significant
 * difference in either direction.*/
real signTest(T, U)(T data, U median, Alt alt = Alt.TWOSIDE)
if(realInput!(T) && isNumeric!(U)) {
    uint greater, less;
    foreach(elem; data) {
        if(elem < median)
            less++;
        else if(median < elem)
            greater++;
        // Ignore equals.
    }
    if(alt == Alt.LESS) {
        return binomialCDF(greater, less + greater, 0.5);
    } else if(alt == Alt.GREATER) {
        return binomialCDF(less, less + greater, 0.5);
    } else if(less > greater) {
        return 2 * binomialCDF(greater, less + greater, 0.5);
    } else if(greater > less) {
        return 2 * binomialCDF(less, less + greater, 0.5);
    } else return 1;
}

unittest {
    assert(approxEqual(signTest([1,2,6,7,9].dup, 2), 0.625));
    writeln("Passed signTest unittest.");
}

/**Performs a one-way chi-square goodness of fit test between a range of
 * observed and a range of expected values.  This is a useful statistical test
 * for testing whether a set of observations fits a discrete distribution.
 *
 * Returns:  The P-value for the alternative hypothesis that observed is not
 * a sample from expected against the null that observed is a sample from
 * expected.
 *
 * Notes:  The chi-square test relies on asymptotic statistical properties
 * and is therefore not considered valid when expected values are below 5.
 *
 * This is, for all practical purposes, an inherently non-directional test.
 * Therefore, the one-sided verses two-sided option is not provided.
 *
 * Examples:
 * ---
 * // Test to see whether a set of categorical observations differs
 * // statistically from a discrete uniform distribution.
 *
 * uint[] observed = [980, 1028, 1001, 964, 1102];
 * auto expected = repeat(cast(real) sum(observed) / observed.length);
 * auto pVal = chiSqrFit(observed, expected);
 * assert(approxEqual(pVal, 0.0207));
 * ---
 */
real chiSqrFit(T, U)(T observed, U expected)
if(realInput!(T) && realInput!(U)) {
    uint len = 0;
    real chiSq = 0;
    while(!observed.empty && !expected.empty) {
        real e = expected.front;
        real diff = cast(real) observed.front - e;
        chiSq += (diff * diff) / e;
        observed.popFront;
        expected.popFront;
        len++;
    }
    return chiSqrCDFR(chiSq, len - 1);
}

unittest {
    // Test to see whether a set of categorical observations differs
    // statistically from a discrete uniform distribution.
    uint[] observed = [980, 1028, 1001, 964, 1102];
    auto expected = repeat(cast(real) sum(observed) / observed.length);
    auto pVal = chiSqrFit(observed, expected);
    assert(approxEqual(pVal, 0.0207));
    writeln("Passed chiSqrFit test.");
}

// Used as a mixin in both the array and tuple overload of chiSqrContingeny().
private enum string chiSqrContingencyTempl =  q{
    real[] colSums = (cast(real*) alloca(real.sizeof * ranges.length))
                     [0..ranges.length];
    colSums[] = 0;
    size_t nCols = 0;
    size_t nRows = ranges.length;
    foreach(ri, range; ranges) {
        size_t curLen = 0;
        foreach(elem; range) {
            colSums[ri] += cast(real) elem;
            curLen++;
        }
        if(ri == 0) {
            nCols = curLen;
        } else {
            assert(curLen == nCols);
        }
    }

    bool noneEmpty() {
        foreach(range; ranges) {
            if(range.empty) {
                return false;
            }
        }
        return true;
    }

    void popAll() {
        foreach(i, range; ranges) {
            ranges[i].popFront;
        }
    }

    real sumRow() {
        real rowSum = 0;
        foreach(range; ranges) {
            rowSum += cast(real) range.front;
        }
        return rowSum;
    }

    real chiSq = 0;
    real NNeg1 = 1.0L / sum(colSums);

    while(noneEmpty) {
        auto rowSum = sumRow();

        foreach(ri, range; ranges) {
            real expected = NNeg1 * rowSum * colSums[ri];
            real diff = cast(real) range.front - expected;
            diff *= diff;
            chiSq += diff / expected;
        }
        popAll();
    }
    return chiSqrCDFR(chiSq, (nRows - 1) * (nCols - 1));
};

/**Performs a chi-square test on a contingency table of arbitrary dimensions.
 * Takes a set of finite forward ranges, one for each column in the contingency
 * table.  Returns a P-value for the alternative hypothesis that frequencies
 * in each row of the contingency table depend on the column against the
 * null that they don't.
 *
 * Notes:  The chi-square test relies on asymptotic statistical properties
 * and is therefore not considered valid when expected values are below 5.
 *
 * This is, for all practical purposes, an inherently non-directional test.
 * Therefore, the one-sided verses two-sided option is not provided.
 *
 * For 2x2 contingency tables, fisherExact is a more accurate test.
 *
 * Examples:
 * ---
 * // Test to see whether the relative frequency of outcome 0, 1, and 2
 * // depends on the treatment in some hypothetical experiment.
 * uint[] drug1 = [1000, 2000, 1500];
 * uint[] drug2 = [1500, 3000, 2300];
 * uint[] placebo = [500, 1100, 750];
 * assert(approxEqual(chiSqrContingency(drug1, drug2, placebo), 0.2397));
 * ---
 */
real chiSqrContingency(T...)(T ranges)
if(T.length > 1 && allSatisfy!(isForwardRange, T)) {
    mixin(chiSqrContingencyTempl);
}

/**Same as chiSqrContingency(T...), but represents contingency table as an
 * array of arrays instead of a tuple of ranges.*/
real chiSqrContingency(T)(const T[][] rangesIn) {
    T[][] ranges = (cast(T[]*) alloca((T[]).sizeof * rangesIn.length))
                   [0..rangesIn.length];
    ranges[] = rangesIn[];
    mixin(chiSqrContingencyTempl);
}

unittest {
    // Test array version.  Using VassarStat's chi-square calculator.
    uint[][] table1 = [[60, 80, 70],
                       [20, 50, 40],
                       [10, 15, 11]];
    uint[][] table2 = [[60, 20, 10],
                       [80, 50, 15],
                       [70, 40, 11]];
    assert(approxEqual(chiSqrContingency(table1), 0.3449));
    assert(approxEqual(chiSqrContingency(table2), 0.3449));

    // Test tuple version.
    auto p1 = chiSqrContingency(cast(uint[]) [31, 41, 59],
                                cast(uint[]) [26, 53, 58],
                                cast(uint[]) [97, 93, 93]);
    assert(approxEqual(p1, 0.0059));

    auto p2 = chiSqrContingency(cast(uint[]) [31, 26, 97],
                                cast(uint[]) [41, 53, 93],
                                cast(uint[]) [59, 58, 93]);
    assert(approxEqual(p2, 0.0059));

    uint[] drug1 = [1000, 2000, 1500];
    uint[] drug2 = [1500, 3000, 2300];
    uint[] placebo = [500, 1100, 750];
    assert(approxEqual(chiSqrContingency(drug1, drug2, placebo), 0.2397));

    writeln("Passed chiSqrContingency test.");
}



/**Performs a Kolmogorov-Smirnov (K-S) 2-sample test and returns
 * the D value.  The K-S test is a non-parametric test for a difference between
 * two empirical distributions or between an empirical distribution and a
 * reference distribution. This implementation uses a signed D value to indicate
 * the direction of the difference between distributions.
 * To get the D value used in standard notation,
 * simply take the absolute value of this D value.*/
real ksTest(T, U)(T F, U Fprime)
if(isInputRange!(T) && isInputRange!(U)) {
    auto TAState = TempAlloc.getState;
    scope(exit) {
        TempAlloc.free(TAState);
        TempAlloc.free(TAState);
    }
    return ksTestDestructive(tempdup(F), tempdup(Fprime));
}

/**Same as ksTest, but sorts input data in place instead of duplicating
 * data.  Therefore, less "safe" but doesn't allocate memory.  F,
 * Fprime must both be random access ranges w/ lengths.*/
real ksTestDestructive(T, U)(T F, U Fprime)
if(isRandomAccessRange!(U) && isRandomAccessRange!(T) &&
   dstats.base.hasLength!(T) && dstats.base.hasLength!(U)) {
    qsort(F);
    qsort(Fprime);
    real D = 0;
    size_t FprimePos = 0;
    foreach(i; 0..2) {  //Test both w/ Fprime x vals, F x vals.
        real diffMult = (i == 0) ? 1 : -1;
        foreach(FPos, Xi; F) {
            if(FPos < F.length - 1 && F[FPos + 1] == Xi)
                continue;  //Handle ties.
            while(FprimePos < Fprime.length && Fprime[FprimePos] <= Xi) {
                FprimePos++;
            }
            real diff = diffMult * (cast(real) (FPos + 1) / F.length -
                       cast(real) FprimePos / Fprime.length);
            if(abs(diff) > abs(D))
                D = diff;
        }
        swap(F, Fprime);
        FprimePos = 0;
    }
    return D;
}

unittest {
    // Values from R.
    assert(approxEqual(ksTestDestructive([1,2,3,4,5].dup, [1,2,3,4,5].dup), 0));
    assert(approxEqual(ksTestDestructive([1,2,3,4,5].dup, [1,2,2,3,5].dup), -.2));
    assert(approxEqual(ksTestDestructive([-1,0,2,8, 6].dup, [1,2,2,3,5].dup), .4));
    assert(approxEqual(ksTestDestructive([1,2,3,4,5].dup, [1,2,2,3,5,7,8].dup), .2857));
    assert(approxEqual(ksTestDestructive([1, 2, 3, 4, 4, 4, 5].dup,
           [1, 2, 3, 4, 5, 5, 5].dup), .2857));
    writeln("Passed 2-sample ksTestDestructive.");
}

/**One-sample KS test against a reference distribution, doesn't modify input
 * data.  Takes a function pointer or delegate for the CDF of refernce
 * distribution.
 *
 * Examples:
 * ---
 * auto stdNormal = parametrize!(normalCDF)(0.0L, 1.0L);
 * auto empirical = [1, 2, 3, 4, 5];
 * real D = ksTest(empirical, stdNormal);
 * ---
 */
real ksTest(T, Func)(T Femp, Func F)
if(realInput!(T) && (is(Func == function) || is(Func == delegate))) {
    scope(exit) TempAlloc.free;
    return ksTestDestructive(tempdup(Femp), F);
}

/**One-sample KS test, sorts in place.  Femp must be a random access range
 * with length.*/
real ksTestDestructive(T, Func)(T Femp, Func F)
if(isRandomAccessRange!(T) && dstats.base.hasLength!(T) &&
    (is(Func == function) || is(Func == delegate))) {
    qsort(Femp);
    real D = 0;

    foreach(FPos, Xi; Femp) {
        real diff = cast(real) FPos / Femp.length - F(Xi);
        if(abs(diff) > abs(D))
            D = diff;
    }

    return D;
}

unittest {
    // Testing against values from R.
    auto stdNormal = parametrize!(normalCDF)(0.0L, 1.0L);
    assert(approxEqual(ksTestDestructive([1,2,3,4,5].dup, stdNormal), -.8413));
    assert(approxEqual(ksTestDestructive([-1,0,2,8, 6].dup, stdNormal), -.5772));
    auto lotsOfTies = [5,1,2,2,2,2,2,2,3,4].dup;
    assert(approxEqual(ksTestDestructive(lotsOfTies, stdNormal), -0.8772));
    writeln("Passed 1-sample ksTestDestructive.");
}

/**Computes 2-sided P-val given D, N, Nprime.  N is the number of observations
 * in the first empirical distribution, Nprime is the number of observations
 * in the second empirical distribution.
 * Bugs:  Exact calculation not implemented.  Uses asymptotic approximation.*/
real ksPvalD(ulong N, ulong Nprime, real D)
in {
    assert(D >= -1);
    assert(D <= 1);
} body {
    return 1 - kolmDist(sqrt(cast(real) (N * Nprime) / (N + Nprime)) * abs(D));
}

/**One-sided P-val.
 * Bugs:  Exact calculation not implemented.  Uses asymptotic approximation.*/
real ksPvalD(ulong N, real D)
in {
    assert(D >= -1);
    assert(D <= 1);
} body {
    return 1 - kolmDist(abs(D) * sqrt(cast(real) N));
}

/**KS-test, returns 2-sided P-val instead of D.
 * Bugs:  Exact calculation not implemented.  Uses asymptotic approximation.*/
real ksPval(T, U)(T F, U Fprime)
if(realInput!(T) && realInput!(U)) {
    return ksPvalD(F.length, Fprime.length, ksTest(F, Fprime));
}

unittest {
    assert(approxEqual(ksPval([1, 2, 3, 4, 4, 4, 5].dup, [1, 2, 3, 4, 5, 5, 5].dup),
           .9375));
    writeln("Passed ksPval 2-sample test.");
}

/**One-sided K-S test, returns P-val instead of D.
 * Bugs:  Exact calculation not implemented.  Uses asymptotic approximation.*/
real ksPval(T, Func)(T Femp, Func F)
if(realInput!(T) && (is(Func == function) || is(Func == delegate))) {
    return ksPvalD(Femp.length, ksTest(Femp, F));
}

unittest {
    auto stdNormal = parametrize!(normalCDF)(0.0L, 1.0L);
    assert(approxEqual(ksPval([0,1,2,3,4].dup, stdNormal), .03271));

    auto uniform01 = parametrize!(uniformCDF)(0, 1);
    assert(approxEqual(ksPval([0.1, 0.3, 0.5, 0.9, 1].dup, uniform01), 0.7591));

    writeln("Passed ksPval 1-sample test.");
}

/**Convenience function.  Converts a dynamic array to a static one, then
 * calls the overload.*/
real fisherExact(T)(const T[][] contingencyTable, Alt alt = Alt.TWOSIDE)
if(isIntegral!(T))
in {
    assert(contingencyTable.length == 2);
    assert(contingencyTable[0].length == 2);
    assert(contingencyTable[1].length == 2);
} body {
    uint[2][2] newTable;
    newTable[0][0] = contingencyTable[0][0];
    newTable[0][1] = contingencyTable[0][1];
    newTable[1][1] = contingencyTable[1][1];
    newTable[1][0] = contingencyTable[1][0];
    return fisherExact(newTable, alt);
}


/**Fisher's Exact test for difference in odds between rows/columns
 * in a 2x2 contingency table.  Specifically, this function tests the odds
 * ratio, which is defined, for a contingency table c, as (c[0][0] * c[1][1])
 *  / (c[1][0] * c[0][1]).  Alternatives are Alt.LESS, meaning true odds ratio
 * < 1, Alt.GREATER, meaning true odds ratio > 1, and Alt.TWOSIDE, meaning
 * true odds ratio != 1.
 *
 * Accepts a 2x2 contingency table as an array of arrays of uints.
 * For now, only does 2x2 contingency tables.
 * Examples:
 * ---
 * real res = fisherExact([[2u, 7], [8, 2]], Alt.LESS);
 * assert(approxEqual(res, 0.01852));  // Odds ratio is very small in this case.
 * ---
 * */
real fisherExact(T)(const T[2][2] contingencyTable, Alt alt = Alt.TWOSIDE)
if(isIntegral!(T)) {

    static real fisherLower(const uint[2][2] contingencyTable) {
        alias contingencyTable c;
        return hypergeometricCDF(c[0][0], c[0][0] + c[0][1], c[1][0] + c[1][1],
                                 c[0][0] + c[1][0]);
    }

    static real fisherUpper(const uint[2][2] contingencyTable) {
        alias contingencyTable c;
        return hypergeometricCDFR(c[0][0], c[0][0] + c[0][1], c[1][0] + c[1][1],
                                 c[0][0] + c[1][0]);
    }


    if(alt == Alt.LESS)
        return fisherLower(contingencyTable);
    else if(alt == Alt.GREATER)
        return fisherUpper(contingencyTable);

    alias contingencyTable c;

    immutable uint n1 = c[0][0] + c[0][1],
                   n2 = c[1][0] + c[1][1],
                   n  = c[0][0] + c[1][0];

    immutable uint mode =
        cast(uint) ((cast(real) (n + 1) * (n1 + 1)) / (n1 + n2 + 2));
    immutable real pExact = hypergeometricPMF(c[0][0], n1, n2, n);
    immutable real pMode = hypergeometricPMF(mode, n1, n2, n);

    if(approxEqual(pExact, pMode, 1e-7)) {
        return 1;
    } else if(c[0][0] < mode) {
        immutable real pLower = hypergeometricCDF(c[0][0], n1, n2, n);

        // Special case to prevent binary search from getting stuck.
        if(hypergeometricPMF(n, n1, n2, n) > pExact) {
            return pLower;
        }

        // Binary search for where to begin upper half.
        uint min = mode, max = n, guess = uint.max;
        while(min != max) {
            guess = (max == min + 1 && guess == min) ? max :
                    (cast(ulong) max + cast(ulong) min) / 2UL;

            immutable real pGuess = hypergeometricPMF(guess, n1, n2, n);
            if(pGuess <= pExact &&
                hypergeometricPMF(guess - 1, n1, n2, n) > pExact) {
                break;
            } else if(pGuess < pExact) {
                max = guess;
            } else min = guess;
        }
        if(guess == uint.max && min == max)
            guess = min;

        return std.algorithm.min(pLower +
               hypergeometricCDFR(guess, n1, n2, n), 1.0L);
    } else {
        immutable real pUpper = hypergeometricCDFR(c[0][0], n1, n2, n);

        // Special case to prevent binary search from getting stuck.
        if(hypergeometricPMF(0, n1, n2, n) > pExact) {
            return pUpper;
        }

        // Binary search for where to begin lower half.
        uint min = 0, max = mode, guess = uint.max;
        while(min != max) {
            guess = (max == min + 1 && guess == min) ? max :
                    (cast(ulong) max + cast(ulong) min) / 2UL;
            real pGuess = hypergeometricPMF(guess, n1, n2, n);

            if(pGuess <= pExact &&
                hypergeometricPMF(guess + 1, n1, n2, n) > pExact) {
                break;
            } else if(pGuess <= pExact) {
                min = guess;
            } else max = guess;
        }

        if(guess == uint.max && min == max)
            guess = min;

        return std.algorithm.min(pUpper +
               hypergeometricCDF(guess, n1, n2, n), 1.0L);
    }
}

unittest {
    // Simple, naive impl. of two-sided to test against.
    static real naive(const uint[][] c) {
        immutable uint n1 = c[0][0] + c[0][1],
                   n2 = c[1][0] + c[1][1],
                   n  = c[0][0] + c[1][0];
        immutable uint mode =
            cast(uint) ((cast(real) (n + 1) * (n1 + 1)) / (n1 + n2 + 2));
        immutable real pExact = hypergeometricPMF(c[0][0], n1, n2, n);
        immutable real pMode = hypergeometricPMF(mode, n1, n2, n);
        if(approxEqual(pExact, pMode, 1e-7))
            return 1;
        real sum = 0;
        foreach(i; 0..n + 1) {
            real pCur = hypergeometricPMF(i, n1, n2, n);
            if(pCur <= pExact)
                sum += pCur;
        }
        return sum;
    }

    uint[][] c = new uint[][](2, 2);

    foreach(i; 0..1000) {
        c[0][0] = uniform(0U, 51U);
        c[0][1] = uniform(0U, 51U);
        c[1][0] = uniform(0U, 51U);
        c[1][1] = uniform(0U, 51U);
        real naiveAns = naive(c);
        real fastAns = fisherExact(c);
        assert(approxEqual(naiveAns, fastAns));
    }

    auto res = fisherExact([[19000u, 80000], [20000, 90000]]);
    assert(approxEqual(res, 3.319e-9));
    res = fisherExact([[18000u, 80000], [20000, 90000]]);
    assert(approxEqual(res, 0.2751));
    res = fisherExact([[14500u, 20000], [30000, 40000]]);
    assert(approxEqual(res, 0.01106));
    res = fisherExact([[100u, 2], [1000, 5]]);
    assert(approxEqual(res, 0.1301));
    res = fisherExact([[2u, 7], [8, 2]]);
    assert(approxEqual(res, 0.0230141));
    res = fisherExact([[5u, 1], [10, 10]]);
    assert(approxEqual(res, 0.1973244));
    res = fisherExact([[5u, 15], [20, 20]]);
    assert(approxEqual(res, 0.0958044));
    res = fisherExact([[5u, 16], [20, 25]]);
    assert(approxEqual(res, 0.1725862));
    res = fisherExact([[10u, 5], [10, 1]]);
    assert(approxEqual(res, 0.1973244));
    res = fisherExact([[2u, 7], [8, 2]], Alt.LESS);
    assert(approxEqual(res, 0.01852));
    res = fisherExact([[5u, 1], [10, 10]], Alt.LESS);
    assert(approxEqual(res, 0.9783));
    res = fisherExact([[5u, 15], [20, 20]], Alt.LESS);
    assert(approxEqual(res, 0.05626));
    res = fisherExact([[5u, 16], [20, 25]], Alt.LESS);
    assert(approxEqual(res, 0.08914));
    res = fisherExact([[2u, 7], [8, 2]], Alt.GREATER);
    assert(approxEqual(res, 0.999));
    res = fisherExact([[5u, 1], [10, 10]], Alt.GREATER);
    assert(approxEqual(res, 0.1652));
    res = fisherExact([[5u, 15], [20, 20]], Alt.GREATER);
    assert(approxEqual(res, 0.985));
    res = fisherExact([[5u, 16], [20, 25]], Alt.GREATER);
    assert(approxEqual(res, 0.9723));
    writeln("Passed fisherExact test.");
}

/**Wald-wolfowitz or runs test for randomness of the distribution of
 * elements for which positive() evaluates to true.  For example, given
 * a sequence of coin flips [H,H,H,H,H,T,T,T,T,T] and a positive() function of
 * "a == 'H'", this test would determine that the heads are non-randomly
 * distributed, since they are all at the beginning of obs.  This is done
 * by counting the number of runs of consecutive elements for which
 * positive() evaluates to true, and the number of consecutive runs for which
 * it evaluates to false.  In the example above, we have 2 runs.  These are the
 * block of 5 consecutive heads at the beginning and the 5 consecutive tails
 * at the end.
 *
 * Alternatives are Alt.LESS, meaning that less runs than expected have been
 * observed and data for which positive() is true tends to cluster,
 * Alt.GREATER, which means that more runs than expected have been observed
 * and data for which positive() is true tends to not cluster even moreso than
 * expected by chance, and Alt.TWOSIDE, meaning that elements for which
 * positive() is true cluster as much as expected by chance.
 *
 * Bugs:  No exact calculation of the P-value.  Asymptotic approximation only.
 */
real runsTest(alias positive = "a > 0", T)(T obs, Alt alt = Alt.TWOSIDE)
if(isIterable!(T)) {
    OnlineRunsTest!(positive, IterType!(T)) r;
    foreach(elem; obs) {
        r.put(elem);
    }
    return r.pVal(alt);
}

unittest {
    // Values from R lawstat package, for which "a < median(data)" is
    // hard-coded as the equivalent to positive().  The median of this data
    // is 0.5, so everything works.
    immutable int[] data = [1,0,0,0,1,1,0,0,1,0,1,0,1,0,1,1,1,0,0,1].idup;
    assert(approxEqual(runsTest(data), 0.3581));
    assert(approxEqual(runsTest(data, Alt.LESS), 0.821));
    assert(approxEqual(runsTest(data, Alt.GREATER), 0.1791));
    writeln("Passed runsTest test.");
}

/**Runs test as in runsTest(), except calculates online instead of from stored
 * array elements.*/
struct OnlineRunsTest(alias positive = "a > 0", T) {
private:
    uint nPos;
    uint nNeg;
    uint nRun;
    bool lastPos;

    alias unaryFun!(positive) pos;

public:

    ///
    void put(T elem) {
        bool curPos = pos(elem);
        if(nRun == 0) {
            nRun = 1;
            if(curPos) {
                nPos++;
            } else {
                nNeg++;
            }
        } else if(pos(elem)) {
            nPos++;
            if(!lastPos) {
                nRun++;
            }
        } else {
            nNeg++;
            if(lastPos) {
                nRun++;
            }
        }
        lastPos = curPos;
    }

    ///
    uint nRuns() {
        return nRun;
    }

    ///
    real pVal(Alt alt = Alt.TWOSIDE) {
        uint N = nPos + nNeg;
        real expected = 2.0L * nPos * nNeg / N + 1;
        real sd = sqrt((expected - 1) * (expected - 2) / (N - 1));
        if(alt == Alt.LESS) {
            return normalCDF(nRun, expected, sd);
        } else if(alt == Alt.GREATER) {
            return normalCDFR(nRun, expected, sd);
        } else {
            return 2 * min(normalCDF(nRun, expected, sd),
                           normalCDFR(nRun, expected, sd));
        }
    }
}

/**Calculates the significance (P-value) of the given Pearson correlation
 * coefficient against the given alternative, for an input vector of length N.
 * Alternatives are Alt.LESS, meaning the true cor is < 0, Alt.GREATER, meaning
 * the true cor is > 0, and Alt.TWOSIDE, meaning the true cor != 0.
 */
real pcorSig(real cor, ulong N, Alt alt = Alt.TWOSIDE) {
    real t = cor / sqrt((1 - cor * cor) / (N - 2));

    switch(alt) {
        case Alt.TWOSIDE:
            return 2 * min(studentsTCDF(t, N - 2), studentsTCDFR(t, N - 2));
        case Alt.LESS:
            return studentsTCDF(t, N - 2);
        case Alt.GREATER:
            return studentsTCDFR(t, N - 2);
        default:
            assert(0);
    }
}

unittest {
    // Values from R.
    assert(approxEqual(pcorSig(0.9, 5), .03739));
    assert(approxEqual(pcorSig(0.9, 5, Alt.GREATER), .01869));
    assert(approxEqual(pcorSig(0.9, 5, Alt.LESS), .9813));
    writeln("Passed pcorSig test.");
}

/**Calculates the significance (P-value) of the given Spearman rho correlation
 * coefficient against the given alternative, for an input vector of length N.
 * Alternatives are Alt.LESS, meaning the true rho is < 0, Alt.GREATER, meaning
 * the true rho is > 0, and Alt.TWOSIDE, meaning the true rho != 0.
 *
 * Bugs:  Exact computation not yet implemented.  Uses asymptotic approximation
 * only.  This is good enough for most practical purposes given reasonably
 * large N, but is not perfectly accurate.  Not valid for data with very large
 * amounts of ties.  */
real scorSig(real rho, ulong N, Alt alt = Alt.TWOSIDE) {
    return pcorSig(rho, N, alt);
}

unittest {
    // Values from R.  The epsilon here will be relatively large because
    // I'm comparing my approximate function to R's exact function.  R's
    // approximate function does not use a continuity correction, and is
    // therefore quite bad.
    assert(approxEqual(scorSig(0.3984962, 20), 0.08226, 0.0, .01));
    assert(approxEqual(scorSig(0.3984962, 20, Alt.LESS), 0.9592, 0.0, .01));
    assert(approxEqual(scorSig(0.3984962, 20, Alt.GREATER), 0.04113, 0.0, .01));
    writeln("Passed scorSig test.");
}

/**Calculates the significance (P-value) of the given Kendall tau correlation
 * coefficient against the given alternative, for an input vector of length N.
 * Alternatives are Alt.LESS, meaning the true tau is < 0, Alt.GREATER, meaning
 * the true tau is > 0, and Alt.TWOSIDE, meaning the true tau != 0.
 *
 * Bugs:  Exact computation not yet implemented.  Uses asymptotic approximation
 * only.  This is good enough for most practical purposes given reasonably
 * large N, but is not perfectly accurate.  Not valid for data with very large
 * amounts of ties.  */
real kcorSig(real tau, ulong N, Alt alt = Alt.TWOSIDE) {
    real cc = 2.0L / (N * (N - 1));  // Continuity correction.
    real sd = sqrt(cast(real) (4 * N + 10) / (9 * N * (N - 1)));

    switch(alt) {
        case Alt.TWOSIDE:
            return 2 * min(normalCDF(tau + cc, 0, sd),
                           normalCDFR(tau - cc, 0, sd));
        case Alt.LESS:
            return normalCDF(tau + cc, 0, sd);
        case Alt.GREATER:
            return normalCDFR(tau - cc, 0, sd);
        default:
            assert(0);
    }
}

unittest {
    // Values from R.  The epsilon here will be relatively large because
    // I'm comparing my approximate function to R's exact function.  R's
    // approximate function does not use a continuity correction, and is
    // therefore quite bad.
    assert(approxEqual(kcorSig(0.2105263, 20), 0.2086, 0.0, .01));
    assert(approxEqual(kcorSig(0.2105263, 20, Alt.LESS), 0.907, 0.0, .01));
    assert(approxEqual(kcorSig(0.2105263, 20, Alt.GREATER), 0.1043, 0.0, .01));
    writeln("Passed kcorSig test.");
}

/**Computes the false discovery rate statistic given a list of
 * p-values, according to Benjamini and Hochberg (1995).
 * This is the most basic, intuitive version of the false discovery rate
 * statistic, and assumes all hypotheses are independent.
 * Returns:   An array of Q-values with indices
 * corresponding to the indices of the p-values passed in.*/
float[] falseDiscoveryRate(T)(T pVals)
if(realInput!(T)) {
    // Not optimized at all because I can't imagine anyone writing code where
    // FDR calculations are the main bottleneck.
    auto p = tempdup(pVals);  scope(exit) TempAlloc.free;
    auto perm = newStack!(uint)(pVals.length);  scope(exit) TempAlloc.free;
    foreach(i, ref elem; perm)
        elem = i;
    qsort(p, perm);
    float[] qVals = new float[p.length];

    foreach(i; 0..p.length) {
        qVals[i] = min(1.0L,
                   p[i] * cast(real) p.length / (cast(real) i + 1));
    }

    float smallestSeen = float.max;
    foreach_reverse(ref q; qVals) {
        if(q < smallestSeen) {
            smallestSeen = q;
        } else {
            q = smallestSeen;
        }
    }

    qsort(perm, qVals);  //Makes order of qVals correspond to input.
    return qVals;
}

unittest {
    // Comparing results to R's qvalue package.
    auto pVals = [.90, .01, .03, .03, .70, .60, .01].dup;
    auto qVals = falseDiscoveryRate(pVals);
    assert(approxEqual(qVals[0], .9));
    assert(approxEqual(qVals[1], .035));
    assert(approxEqual(qVals[2], .052));
    assert(approxEqual(qVals[3], .052));
    assert(approxEqual(qVals[4], .816666666667));
    assert(approxEqual(qVals[5], .816666666667));
    assert(approxEqual(qVals[6], .035));
    writeln("Passed falseDiscoveryRate test.");
}

// Verify that there are no TempAlloc memory leaks anywhere in the code covered
// by the unittest.  This should always be the last unittest of the module.
unittest {
    auto TAState = TempAlloc.getState;
    assert(TAState.used == 0);
    assert(TAState.nblocks < 2);
}
