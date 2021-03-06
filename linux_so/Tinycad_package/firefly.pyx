#import random
from libc.math cimport sqrt, exp, log10
from cpython cimport bool
from array import array

import numpy as np
cimport numpy as np

from libc.stdlib cimport rand, RAND_MAX, srand
from libc.time cimport time

# make true it is random everytime
srand(time(NULL))

cdef double randV():
    return rand()*1.0 / RAND_MAX

cdef class Chromosome(object):

    cdef public int n
    cdef public double f
    cdef public np.ndarray v

    def __cinit__(self, n):
        self.n = n
        #self.v = <double *>malloc(n*cython.sizeof(double))
        self.v = np.zeros(n)
        # the light intensity
        self.f = 0

    cdef double distance(self, Chromosome obj):
        cdef double dist
        dist = 0
        for i in range(self.n):
            dist += (self.v[i] - obj.v[i])**2
        return sqrt(dist)

    cdef void assign(self, Chromosome obj):
        self.n = obj.n
        self.v[:] = obj.v
        self.f = obj.f


cdef class Firefly(object):

    cdef int D, n, maxGen, rp, gen
    cdef double alpha, alpha0, betaMin, beta0, gamma
    cdef object f
    #cdef double[:] lb, ub
    cdef np.ndarray lb, ub
    #cdef Chromosome[:] fireflys
    #cdef object fireflys
    cdef np.ndarray fireflys
    cdef Chromosome genbest, bestFirefly
    cdef int timeS, timeE
    cdef object fitnessTime, fitnessParameter

    def __init__(self, object f, int D, int n, double alpha, double betaMin, double beta0, double gamma, object lb, object ub, int maxGen, int report):
        # D, the dimension of question
        # and each firefly will random place position in this landscape
        self.D = D
        # n, the population size of fireflies
        self.n = n
        # alpha, the step size
        self.alpha = alpha
        # alpha0, use to calculate_new_alpha
        self.alpha0 = alpha
        # betamin, the minimal attration, must not less than this
        self.betaMin = betaMin
        # beta0, the attration of two firefly in 0 distance
        self.beta0 = beta0
        # gamma
        self.gamma = gamma
        # low bound
        self.lb = np.array(lb[:])
        # up bound
        self.ub = np.array(ub[:])
        # all fireflies, depend on population n
        self.fireflys = np.ndarray((self.n),dtype=np.object)
        for i in range(self.n):
            self.fireflys[i] = Chromosome(self.D)
        # object function
        self.f = f
        # maxima generation
        self.maxGen = maxGen
        # report, how many generation report status once
        self.rp = report
        # generation of current
        self.gen = 0
        # best firefly of geneation
        self.genbest = Chromosome(self.D)
        # best firefly so far
        self.bestFirefly = Chromosome(self.D)

        # setup benchmark
        self.timeS = time(NULL)
        self.timeE = 0
        self.fitnessTime = ''
        self.fitnessParameter = ''

    cdef void init(self):
        cdef int i, j
        for i in range(self.n):
            # init the Chromosome
            for j in range(self.D):
                self.fireflys[i].v[j]=randV()*(self.ub[j]-self.lb[j])+self.lb[j];

    cdef void movefireflies(self):
        cdef int i, j, k
        cdef bool is_move
        for i in range(self.n):
            is_move = False
            for j in range(self.n):
                is_move |= self.movefly(self.fireflys[i], self.fireflys[j])
            if not is_move:
                for k in range(self.D):
                    scale = self.ub[k] - self.lb[k]
                    self.fireflys[i].v[k] += self.alpha * (randV() - 0.5) * scale
                    self.fireflys[i].v[k] = self.check(k, self.fireflys[i].v[k])

    cdef void evaluate(self):
        cdef Chromosome firefly
        for firefly in self.fireflys:
            firefly.f = self.f(firefly.v)

    cdef bool movefly(self, Chromosome me, Chromosome she):
        cdef double r, beta
        cdef int i
        if me.f > she.f:
            r = me.distance(she)
            beta = (self.beta0-self.betaMin)*exp(-self.gamma*(r**2))+self.betaMin
            for i in range(me.n):
                scale = self.ub[i] - self.lb[i]
                me.v[i] += beta * (she.v[i] - me.v[i]) + self.alpha*(randV()-0.5) * scale
                me.v[i] = self.check(i, me.v[i])
            return True
        return False

    cdef double check(self, int i, double v):
        if v > self.ub[i]:
            return self.ub[i]
        elif v < self.lb[i]:
            return self.lb[i]
        else:
            return v

    cdef Chromosome findFirefly(self):
        return min(self.fireflys, key=lambda chrom:chrom.f)

    cdef void report(self):
        self.timeE = time(NULL)
        self.fitnessTime += '%d,%.3f,%d;'%(self.gen, self.bestFirefly.f, self.timeE - self.timeS)
        #cdef int i
        #cdef double v
        #if self.gen == 0:
        #    print("Firefly results - init pop")
        #elif self.gen == self.maxGen:
        #    print("Final Firefly results at %d generations"%(self.gen,))
        #else:
        #    print("Final Firefly results after %d generations"%(self.gen,))

        #print("Function : %.6f" % (self.bestFirefly.f))
        #for i, v in enumerate(self.bestFirefly.v, start=1):
        #    print("Var %d : %.4f"%(i, v))

    cdef void calculate_new_alpha(self):
        self.alpha = self.alpha0 * log10(self.genbest.f + 1)

    cdef void getParamValue(self):
        self.fitnessParameter = ','.join(['%.4f'%(v) for v in self.bestFirefly.v])

    cpdef run(self):
        self.init()
        self.evaluate()
        self.bestFirefly.assign(self.fireflys[0])
        self.report()

        for self.gen in range(1, self.maxGen + 1):
            self.movefireflies()
            self.evaluate()
            # adjust alpha, depend on fitness value
            # if fitness value is larger, then alpha should larger
            # if fitness value is small, then alpha should smaller

            self.genbest.assign(self.findFirefly())
            if self.bestFirefly.f > self.genbest.f:
                self.bestFirefly.assign(self.genbest)
            # self.bestFirefly.assign(gen_best)
            self.calculate_new_alpha()
            if self.rp != 0:
                if self.gen % self.rp == 0:
                    self.report()
        self.report()
        self.getParamValue()
        return self.fitnessTime, self.fitnessParameter
#cpdef build_firefly(int D, int n, double alpha, double betaMin, double beta0, double gamma, lb, ub, f, int maxGen, int report):
#    fa = Firefly(D, n , alpha, betaMin, beta0, gamma, lb, ub, f, maxGen, report)
#    fa.run()
